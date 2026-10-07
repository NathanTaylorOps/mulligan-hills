extends GdUnitTestSuite

func test_experience_rewards_quality_value_and_pace() -> void:
	var tiers := PackedInt32Array([2,2,2,1,1,1,1,1,1,1])
	var good: Dictionary = MHGolferExperience.evaluate(85, 3000, 3500, tiers, 9, 5)
	var bad: Dictionary = MHGolferExperience.evaluate(40, 6000, 3000, tiers, 3, 40)
	assert_int(int(good["score"])).is_greater(int(bad["score"]))
	assert_str(str(good["reaction"])).is_not_empty()

func test_customer_becomes_regular_then_membership_eligible() -> void:
	var c: MHGolferCustomers = MHGolferCustomers.new()
	var id: int = 12
	for i: int in range(3):
		c.record_visit(id, 90)
	assert_bool(bool((c.rows[id] as Dictionary)["regular"])).is_true()
	assert_bool(bool((c.rows[id] as Dictionary)["member_eligible"])).is_false()
	c.record_visit(id, 90)
	assert_bool(bool((c.rows[id] as Dictionary)["member_eligible"])).is_false()
	c.record_visit(id, 90)
	assert_bool(bool((c.rows[id] as Dictionary)["member_eligible"])).is_true()

func test_bad_post_regular_visit_resets_membership_streak() -> void:
	var c: MHGolferCustomers = MHGolferCustomers.new()
	for i: int in range(3):
		c.record_visit(4, 90)
	c.record_visit(4, 90)
	c.record_visit(4, 50)
	assert_int(int((c.rows[4] as Dictionary)["good_member_visits"])).is_equal(0)
	assert_bool(bool((c.rows[4] as Dictionary)["member_eligible"])).is_false()

func test_customer_ledger_round_trips() -> void:
	var c: MHGolferCustomers = MHGolferCustomers.new()
	c.record_visit(7, 88)
	var restored: MHGolferCustomers = MHGolferCustomers.from_dict(c.to_dict())
	assert_object(restored).is_not_null()
	assert_int(int((restored.rows[7] as Dictionary)["visits"])).is_equal(1)
	assert_int(int((restored.rows[7] as Dictionary)["satisfaction"])).is_equal(88)

func test_invalid_customer_id_is_rejected() -> void:
	var c: MHGolferCustomers = MHGolferCustomers.new()
	assert_bool(c.record_visit(-1, 80).is_empty()).is_true()
	assert_bool(c.record_visit(MHGolferCustomers.COUNT, 80).is_empty()).is_true()

func test_first_visit_satisfaction_is_clamped() -> void:
	var c: MHGolferCustomers = MHGolferCustomers.new()
	c.record_visit(1, 999)
	assert_int(int((c.rows[1] as Dictionary)["satisfaction"])).is_equal(100)
	c.record_visit(2, -999)
	assert_int(int((c.rows[2] as Dictionary)["satisfaction"])).is_equal(0)

func test_restore_rejects_impossible_customer_relationship_state() -> void:
	var c: MHGolferCustomers = MHGolferCustomers.new()
	var raw: Dictionary = c.to_dict()
	var rows: Array = raw["rows"] as Array
	(rows[5] as Dictionary)["member"] = true
	assert_object(MHGolferCustomers.from_dict(raw)).is_null()

func test_incomplete_course_can_explain_dissatisfaction() -> void:
	var tiers := PackedInt32Array([5,5,5,5,5,5,5,5,5,5])
	var result: Dictionary = MHGolferExperience.evaluate(100, 1000, 5000, tiers, 1, 0)
	assert_str(str(result["worst"])).is_equal("completeness")

func test_restore_rejects_mismatched_customer_id_and_wrong_field_types() -> void:
	var c: MHGolferCustomers = MHGolferCustomers.new()
	var raw: Dictionary = c.to_dict()
	((raw["rows"] as Array)[5] as Dictionary)["id"] = 90
	assert_object(MHGolferCustomers.from_dict(raw)).is_null()

	raw = c.to_dict()
	((raw["rows"] as Array)[5] as Dictionary)["visits"] = 1.0
	assert_object(MHGolferCustomers.from_dict(raw)).is_null()

	raw = c.to_dict()
	((raw["rows"] as Array)[5] as Dictionary)["regular"] = 1
	assert_object(MHGolferCustomers.from_dict(raw)).is_null()
