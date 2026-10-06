extends GdUnitTestSuite

func test_equipment_improves_work_and_degrades_deterministically() -> void:
	var defs: MHStaffDefs = MHStaffDefs.load_default()
	var a: MHStaffEquipment = MHStaffEquipment.new()
	var b: MHStaffEquipment = MHStaffEquipment.new()
	assert_bool(bool(a.add_unit("greens_mower")["ok"])).is_true()
	assert_bool(bool(b.add_unit("greens_mower")["ok"])).is_true()
	assert_bool(a.available_multiplier_permille(MHStaffDefs.KIND_GROUNDS) > 1000).is_true()
	for _day: int in range(20):
		a.on_day(0)
		b.on_day(0)
	assert_dict(a.to_save_block()).is_equal(b.to_save_block())
	assert_bool(a.available_multiplier_permille(MHStaffDefs.KIND_GROUNDS) < 1250).is_true()


func test_workshop_tier_maintains_equipment_condition() -> void:
	var neglected: MHStaffEquipment = MHStaffEquipment.new()
	var maintained: MHStaffEquipment = MHStaffEquipment.new()
	neglected.add_unit("fairway_mower")
	maintained.add_unit("fairway_mower")
	for _day: int in range(30):
		neglected.on_day(0)
		maintained.on_day(3)
	var nc: int = int((neglected.units[0] as Dictionary)["condition"])
	var mc: int = int((maintained.units[0] as Dictionary)["condition"])
	assert_bool(mc > nc).is_true()


func test_equipment_save_round_trip_and_corruption_rejection() -> void:
	var a: MHStaffEquipment = MHStaffEquipment.new()
	a.add_unit("sprayer")
	a.on_day(1)
	var block: Dictionary = a.to_save_block()
	var b: MHStaffEquipment = MHStaffEquipment.new()
	assert_bool(b.from_save_block(block)).is_true()
	assert_dict(b.to_save_block()).is_equal(block)
	var bad: Dictionary = block.duplicate(true)
	(bad["units"][0] as Dictionary)["condition"] = 1001
	var c: MHStaffEquipment = MHStaffEquipment.new()
	assert_bool(c.from_save_block(bad)).is_false()
