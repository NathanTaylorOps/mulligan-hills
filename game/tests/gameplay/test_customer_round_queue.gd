extends GdUnitTestSuite


func _hole() -> Dictionary:
	return {"slot_id": 0, "tee": [0, 0], "green": [0, 120, 5],
		"features": [{"t": "fairway", "rect": [-14, 0, 14, 120]}]}


func test_queue_never_changes_customer_payment_values() -> void:
	var q: MHCustomerRoundQueue = MHCustomerRoundQueue.new()
	var paid: Dictionary = {"serial": 7, "paid_fee": 4200, "ancillary": 900, "admitted_day": 1, "admitted_hour": 3, "hole_slot": 0,
		"round": {"events": [], "strokes": 4, "flags": 0}, "satisfaction": 77}
	q.admit([paid], _hole(), {"B": 700, "F": 700, "I": 700, "elev": 200}, {"save_secret": 55, "rating_epoch": 0})
	assert_int(q.waiting.size()).is_equal(1)
	var queued: Dictionary = q.waiting[0]
	assert_int(int(queued["paid_fee"])).is_equal(4200)
	assert_int(int(queued["ancillary"])).is_equal(900)


func test_customer_starts_finishes_and_frees_tee() -> void:
	var q: MHCustomerRoundQueue = MHCustomerRoundQueue.new()
	var events: Array = [
		{"kind": "shot", "shot": 1, "x0": 0, "y0": 0, "x1": 0, "y1": 7000},
		{"kind": "shot", "shot": 2, "x0": 0, "y0": 7000, "x1": 0, "y1": 12000},
	]
	var rows: Array = [
		{"serial": 0, "paid_fee": 4000, "ancillary": 500, "round": {"events": events, "strokes": 3, "flags": 0}, "satisfaction": 88},
		{"serial": 1, "paid_fee": 4000, "ancillary": 500, "round": {"events": events, "strokes": 4, "flags": 0}, "satisfaction": 72},
	]
	q.admit(rows, {}, {}, {})
	var started: Dictionary = q.advance(0.0)
	assert_str(str(started["kind"])).is_equal("started")
	assert_bool(q.active.is_empty()).is_false()
	assert_int(int(q.active["satisfaction"])).is_equal(88)
	var round: Dictionary = q.active["round"]
	var finish_at: float = MHCustomerRoundQueue.TEE_INTERVAL_S + MHAIRoundTimeline.total_duration(round["events"] as Array) + 1.0
	var finished: Dictionary = q.advance(finish_at)
	assert_str(str(finished["kind"])).is_equal("finished")
	assert_bool(q.active.is_empty()).is_true()
	assert_int(q.completed.size()).is_equal(1)
	assert_int(int((q.completed[0] as Dictionary)["satisfaction"])).is_equal(88)
	var second: Dictionary = q.advance(finish_at + 0.01)
	assert_str(str(second["kind"])).is_equal("started")
	assert_int(int((second["customer"] as Dictionary)["serial"])).is_equal(1)

func test_satisfaction_reacts_to_penalties_and_pickup() -> void:
	var clean: int = MHCustomerRoundQueue.satisfaction({"strokes": 3, "flags": 0})
	var penalty: int = MHCustomerRoundQueue.satisfaction({"strokes": 3, "flags": 32})
	var pickup: int = MHCustomerRoundQueue.satisfaction({"strokes": 7, "flags": 4})
	assert_bool(clean > penalty).is_true()
	assert_bool(penalty > pickup).is_true()
	assert_str(MHCustomerRoundQueue.reaction(clean, 0)).contains("play that again")


func test_preferences_reward_different_hole_qualities() -> void:
	var round: Dictionary = {"strokes": 3, "flags": 16}
	var strategic: Dictionary = {"B": 500, "F": 700, "I": 900, "elev": 100}
	var scenic: Dictionary = {"B": 900, "F": 700, "I": 500, "elev": 100}
	assert_bool(MHGolferPreference.bonus(MHGolferPreference.STRATEGIST, strategic, round) >
		MHGolferPreference.bonus(MHGolferPreference.STRATEGIST, scenic, round)).is_true()
	assert_bool(MHGolferPreference.bonus(MHGolferPreference.CASUAL, scenic, round) >
		MHGolferPreference.bonus(MHGolferPreference.CASUAL, strategic, round)).is_true()


func test_preference_bonus_is_bounded() -> void:
	var extreme: Dictionary = {"B": 1000, "F": 1000, "I": 1000, "elev": 1000}
	for kind: int in range(MHGolferPreference.COUNT):
		var b: int = MHGolferPreference.bonus(kind, extreme, {"flags": 16})
		assert_bool(b >= -12 and b <= 12).is_true()


func test_roster_identity_is_stable_and_good_visit_builds_loyalty_memory() -> void:
	var roster: MHGolferRoster = MHGolferRoster.new()
	var g: Dictionary = roster.identity_for_admission(12345, 0, 1)
	assert_bool(str(g["name"]).is_empty()).is_false()
	var updated: Dictionary = roster.record_visit(int(g["id"]), 1, 92, "Great hole. I'd play that again.")
	assert_int(int(updated["visits"])).is_equal(1)
	assert_bool(int(updated["loyalty"]) > 50).is_true()
	assert_str(str(updated["favorite_memory"])).contains("Great hole")
	var saved: Dictionary = roster.to_dict()
	var restored: MHGolferRoster = MHGolferRoster.new()
	assert_bool(restored.from_dict(saved)).is_true()
	assert_dict(restored.to_dict()).is_equal(saved)


func test_roster_creates_deterministic_returning_golfers() -> void:
	var a: MHGolferRoster = MHGolferRoster.new()
	var first: Dictionary = a.identity_for_admission(777, 0, 1)
	a.record_visit(int(first["id"]), 1, 100, "Loved it")
	# Serial 4 is a deterministic return opportunity.
	var returning: Dictionary = a.identity_for_admission(777, 4, 2)
	assert_int(int(returning["id"])).is_equal(int(first["id"]))
	assert_int(int(returning["visits"])).is_equal(1)
	assert_bool(int(returning["loyalty"]) > 50).is_true()


func test_golfer_has_persistent_look_social_taste_and_structured_memories() -> void:
	var roster: MHGolferRoster = MHGolferRoster.new()
	var g: Dictionary = roster.identity_for_admission(2468, 0, 1)
	assert_bool(int(g["look_seed"]) != 0).is_true()
	assert_bool(str(g["favorite_facility"]) in MHGolferRoster.FACILITIES).is_true()
	assert_bool(str(g["relationship_role"]) in ["friend", "partner", "family"]).is_true()
	var updated: Dictionary = roster.record_visit(int(g["id"]), 1, 88, "Loved the elevation", 2, 16)
	var memories: Array = updated["memories"]
	assert_int(memories.size()).is_equal(1)
	assert_int(int((memories[0] as Dictionary)["hole_slot"])).is_equal(2)
	assert_int(int(updated["favorite_hole_slot"])).is_equal(2)
	var restored: MHGolferRoster = MHGolferRoster.new()
	assert_bool(restored.from_dict(roster.to_dict())).is_true()
	assert_int(int((restored.golfers[int(g["id"])] as Dictionary)["look_seed"])).is_equal(int(g["look_seed"]))


func test_strong_repeat_visits_create_membership_application_not_auto_membership() -> void:
	var roster: MHGolferRoster = MHGolferRoster.new()
	var g: Dictionary = roster.identity_for_admission(1357, 0, 1)
	var id: int = int(g["id"])
	var updated: Dictionary = {}
	for day: int in range(1, 9):
		updated = roster.record_visit(id, day, 90, "Great round", 0, 0)
	assert_bool(bool(updated["member"])).is_false()
	assert_str(str(updated["membership_status"])).is_equal("applied")
	assert_bool(int(updated["membership_interest"]) >= 50).is_true()

func test_memory_log_is_bounded() -> void:
	var roster: MHGolferRoster = MHGolferRoster.new()
	var g: Dictionary = roster.identity_for_admission(9, 0, 1)
	for day: int in range(20):
		roster.record_visit(int(g["id"]), day, 60 + day % 20, "Round %d" % day, day % 3, 0)
	var saved: Dictionary = roster.golfers[int(g["id"])]
	assert_int((saved["memories"] as Array).size()).is_equal(MHGolferRoster.MEMORY_LIMIT)
	assert_int(int(((saved["memories"] as Array)[0] as Dictionary)["day"])).is_equal(20 - MHGolferRoster.MEMORY_LIMIT)


func test_social_group_has_shared_group_id_but_distinct_people() -> void:
	var roster: MHGolferRoster = MHGolferRoster.new()
	var group: Array = roster.group_for_admission(333, 1, 2, 4)
	assert_int(group.size()).is_equal(4)
	var anchor_group: int = int((group[0] as Dictionary)["group_id"])
	var ids: Dictionary = {}
	for v: Variant in group:
		var g: Dictionary = v
		assert_int(int(g["group_id"])).is_equal(anchor_group)
		ids[int(g["id"])] = true
	assert_int(ids.size()).is_equal(4)


func test_facility_visit_is_timed_and_expires() -> void:
	var q: MHCustomerRoundQueue = MHCustomerRoundQueue.new()
	var customer: Dictionary = {"serial": 3, "identity": {"id": 1, "group_id": 7}}
	var visit: Dictionary = q.queue_facility_visit(customer, "restaurant", 10.0)
	assert_str(str(visit["facility"])).is_equal("restaurant")
	assert_int(q.active_facility_visits(11.0).size()).is_equal(1)
	assert_int(q.active_facility_visits(float(visit["end_s"]) + 0.1).size()).is_equal(0)


func test_pedestrian_route_ends_at_exact_building_destination() -> void:
	var start: Vector3 = Vector3(1.0, 0.0, 2.0)
	var destination: Vector3 = Vector3(40.0, 0.0, 70.0)
	var route: Array = MHClubPedestrian.route(start, destination, 9)
	assert_int(route.size()).is_equal(3)
	assert_bool((route.back() as Vector3).is_equal_approx(destination)).is_true()
	var pos: Vector3 = start
	var segment: int = 0
	var done: bool = false
	for _i: int in range(10000):
		var state: Dictionary = MHClubPedestrian.advance(route, segment, pos, 0.1)
		pos = state["position"] as Vector3
		segment = int(state["segment"])
		done = bool(state["done"])
		if done:
			break
	assert_bool(done).is_true()
	assert_bool(pos.is_equal_approx(destination)).is_true()


func test_building_positions_require_purchased_and_player_placed_building() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.set_tier(0, 1) # clubhouse purchased, but not placed yet
	assert_bool(MHClubPedestrian.building_positions(s).has("clubhouse")).is_false()
	var placed: Dictionary = {"ok": true, "center_mm": [30000, 42000], "size_m": [18, 14], "ground_mm": 1250,
		"rotation_quarters": 0}
	assert_bool(s.set_building_placement("clubhouse", placed)).is_true()
	var positions: Dictionary = MHClubPedestrian.building_positions(s)
	assert_bool(positions.has("clubhouse")).is_true()
	assert_bool((positions["clubhouse"] as Vector3).is_equal_approx(Vector3(30.0, 1.25, 42.0))).is_true()

func test_public_returning_golfer_can_vary_party_from_stable_associates() -> void:
	var roster: MHGolferRoster = MHGolferRoster.new()
	var first: Array = roster.group_for_admission(991, 1, 1, 4)
	var anchor: Dictionary = first[0]
	roster.record_visit(int(anchor["id"]), 1, 80, "good", 0, 0)
	for serial: int in range(2, 10):
		roster.group_for_admission(991, serial * 3, 1, 4)
	var stored: Dictionary = roster.golfers[int(anchor["id"])]
	assert_int((stored.get("associates", []) as Array).size()).is_less_equal(8)
	var a: Array = roster.public_party(int(anchor["id"]), 3, 0)
	var b: Array = roster.public_party(int(anchor["id"]), 3, 1)
	assert_int(a.size()).is_greater_equal(1)
	assert_int(b.size()).is_greater_equal(1)


func test_customer_queue_preserves_authoritative_outcome_without_resimulating() -> void:
	var q: MHCustomerRoundQueue = MHCustomerRoundQueue.new()
	var outcome: Dictionary = {"serial": 9, "satisfaction": 77, "reaction": "Already resolved",
		"round": {"events": [], "strokes": 4, "flags": 0}, "identity": {"id": 2}}
	q.admit([outcome], {}, {}, {})
	assert_int(q.waiting.size()).is_equal(1)
	assert_int(int((q.waiting[0] as Dictionary)["satisfaction"])).is_equal(77)
	assert_str(str((q.waiting[0] as Dictionary)["reaction"])).is_equal("Already resolved")


func test_roster_restore_rejects_colliding_next_id_and_invalid_associates() -> void:
	var roster: MHGolferRoster = MHGolferRoster.new()
	var group: Array = roster.group_for_admission(444, 1, 1, 3)
	var saved: Dictionary = roster.to_dict()
	var max_id: int = -1
	for v: Variant in saved["golfers"]:
		max_id = maxi(max_id, int((v as Dictionary)["id"]))
	var colliding: Dictionary = saved.duplicate(true)
	colliding["next_id"] = max_id
	assert_bool(MHGolferRoster.new().from_dict(colliding)).is_false()

	var self_link: Dictionary = saved.duplicate(true)
	var first: Dictionary = (self_link["golfers"] as Array)[0]
	first["associates"] = [int(first["id"])]
	assert_bool(MHGolferRoster.new().from_dict(self_link)).is_false()

	var dangling: Dictionary = saved.duplicate(true)
	((dangling["golfers"] as Array)[0] as Dictionary)["associates"] = [9999]
	assert_bool(MHGolferRoster.new().from_dict(dangling)).is_false()


func test_playback_virtualization_never_drops_authoritative_customers() -> void:
	var q: MHCustomerRoundQueue = MHCustomerRoundQueue.new()
	var rows: Array = []
	for i: int in range(40):
		rows.append({"serial": i, "round": {"events": [], "strokes": 4, "flags": 0}, "satisfaction": 70})
	q.admit(rows, {}, {}, {})
	assert_int(q.waiting.size()).is_equal(40)
	assert_int(q.visible_waiting().size()).is_equal(MHCustomerRoundQueue.MAX_VISIBLE_WAITING)
	assert_int(q.offscreen_waiting_count()).is_equal(16)


func test_satisfaction_is_relative_to_hole_par() -> void:
	assert_int(MHCustomerRoundQueue.satisfaction({"strokes": 4, "flags": 0}, 4)).is_equal(
		MHCustomerRoundQueue.satisfaction({"strokes": 3, "flags": 0}, 3))
	assert_bool(MHCustomerRoundQueue.satisfaction({"strokes": 6, "flags": 0}, 5) >
		MHCustomerRoundQueue.satisfaction({"strokes": 6, "flags": 0}, 3)).is_true()


func test_visiting_party_id_is_transient_and_does_not_mutate_saved_social_identity() -> void:
	var roster: MHGolferRoster = MHGolferRoster.new()
	var first: Array = roster.group_for_admission(5150, 11, 1, 4)
	assert_int(first.size()).is_equal(4)
	var anchor_id: int = int((first[0] as Dictionary)["id"])
	var first_party_id: int = int((first[0] as Dictionary)["group_id"])
	assert_int(first_party_id).is_equal(11)
	# Persistent golfer records keep relationship identity separate from the current visit.
	assert_int(int((roster.golfers[anchor_id] as Dictionary)["group_id"])).is_equal(-1)
	for member_v: Variant in first:
		var member: Dictionary = member_v
		assert_int(int(member["group_id"])).is_equal(first_party_id)
		assert_int(int((roster.golfers[int(member["id"])] as Dictionary)["group_id"])).is_equal(-1)

	roster.record_visit(anchor_id, 1, 90, "good", 0, 0)
	var returning: Array = roster.group_for_admission(5150, 44, 2, 3)
	if int((returning[0] as Dictionary)["id"]) == anchor_id:
		assert_int(int((returning[0] as Dictionary)["group_id"])).is_equal(44)
		assert_int(int((roster.golfers[anchor_id] as Dictionary)["group_id"])).is_equal(-1)
