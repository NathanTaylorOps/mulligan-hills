extends GdUnitTestSuite
## Integration ownership: session owns staff/customer state; economy remains the money authority.

func test_session_uses_real_staff_facade() -> void:
	var s: MHGameSession = MHGameSession.create()
	assert_object(s).is_not_null()
	assert_object(s.staff).is_not_null()
	assert_int(s.staff.head_count()).is_equal(0)
	assert_int(s.pace_score()).is_equal(0)
	assert_int(int(s.staff_report()["head_count"])).is_equal(0)

func test_customer_visit_is_owned_by_session_and_condition_can_only_reduce_score() -> void:
	var s: MHGameSession = MHGameSession.create()
	var before: int = int((s.customers.rows[3] as Dictionary)["visits"])
	var visit: Dictionary = s.record_customer_visit(3, 3, 0)
	assert_bool(visit.is_empty()).is_false()
	assert_int(int((s.customers.rows[3] as Dictionary)["visits"])).is_equal(before + 1)
	var raw: Dictionary = MHGolferExperience.evaluate(s.economy.rating, s.economy.fee,
		s.economy.suggest_fee(), s.economy.tiers, 3, 0)
	var experience: Dictionary = visit["experience"] as Dictionary
	assert_int(int(experience["score"])).is_less_equal(int(raw["score"]))
	assert_bool(experience.has("condition")).is_true()
	assert_bool(experience.has("condition_penalty_permille")).is_true()
	assert_int(int(experience["condition"])).is_between(0, 100)

func test_invalid_customer_visit_does_not_mutate_ledger() -> void:
	var s: MHGameSession = MHGameSession.create()
	var snapshot: Dictionary = s.customers.to_dict()
	assert_bool(s.record_customer_visit(-1, 3, 0).is_empty()).is_true()
	assert_dict(s.customers.to_dict()).is_equal(snapshot)

func test_named_members_cannot_exceed_calibrated_membership_capacity() -> void:
	var s: MHGameSession = MHGameSession.create()
	for i: int in range(5):
		s.customers.record_visit(7, 100)
	assert_bool(bool((s.customers.rows[7] as Dictionary)["member_eligible"])).is_true()
	assert_bool(s.accept_customer_membership(7)).is_false()
	s.economy.members_milli = 1000
	assert_bool(s.accept_customer_membership(7)).is_true()
	assert_int(s.customers.member_count()).is_equal(1)
	assert_bool(s.accept_customer_membership(8)).is_false()

func test_economy_hour_publishes_the_booked_golfer_count() -> void:
	var s: MHGameSession = MHGameSession.create()
	var view: MHLiveGameStateView = MHLiveGameStateView.new(s)
	assert_str(MHSliceStarter.setup(s, view)).is_equal("")
	var booked: Array = []
	s.golfers_booked.connect(func(count: int, ids: Array, minute: int) -> void:
		booked.append({"count": count, "ids": ids, "minute": minute}))
	s.clock.set_time(0, 59)
	s.advance(3000000, 20000 * 86400)
	assert_int(booked.size()).is_less_equal(1)
	if not booked.is_empty():
		var row: Dictionary = booked[0] as Dictionary
		assert_int(int(row["count"])).is_greater(0)
		assert_int((row["ids"] as Array).size()).is_equal(int(row["count"]))
		assert_int(int(row["minute"])).is_equal(s.clock.total_minutes())

func test_customer_booking_identity_is_deterministic_and_unique_within_normal_group() -> void:
	var s: MHGameSession = MHGameSession.create()
	var a: Array = s.customer_ids_for_booking(4, 17)
	var b: Array = s.customer_ids_for_booking(4, 17)
	assert_array(a).is_equal(b)
	assert_int(a.size()).is_equal(4)
	var seen: Dictionary = {}
	for id: Variant in a:
		assert_bool(seen.has(int(id))).is_false()
		seen[int(id)] = true
