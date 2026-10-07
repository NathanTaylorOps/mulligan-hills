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
	assert_int(int((visit["experience"] as Dictionary)["score"])).is_less_equal(int(raw["score"]))

func test_invalid_customer_visit_does_not_mutate_ledger() -> void:
	var s: MHGameSession = MHGameSession.create()
	var snapshot: Dictionary = s.customers.to_dict()
	assert_bool(s.record_customer_visit(-1, 3, 0).is_empty()).is_true()
	assert_dict(s.customers.to_dict()).is_equal(snapshot)
