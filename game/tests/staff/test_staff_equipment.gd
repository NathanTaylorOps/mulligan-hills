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
		maintained.on_day(3, 1000)
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


func test_equipment_only_boosts_assigned_compatible_employee() -> void:
	var defs: MHStaffDefs = MHStaffDefs.load_default()
	var roster: MHStaffRoster = MHStaffRoster.new()
	var equipment: MHStaffEquipment = MHStaffEquipment.new()
	roster.employees = [
		{"serial": 1, "role": "groundskeeper", "hired_day": 0, "tenure": 0, "areas": [0]},
		{"serial": 2, "role": "groundskeeper", "hired_day": 0, "tenure": 0, "areas": [1]},
	]
	var unit: Dictionary = equipment.add_unit("greens_mower")
	assert_bool(equipment.assign_unit(int(unit["serial"]), 1, MHStaffDefs.KIND_GROUNDS)).is_true()
	var view: Dictionary = {"tiers": {"maintenance": 1}, "owned": [0, 1], "kinds": ["golf","golf","golf","golf","golf","golf","golf","golf","golf","golf","golf","golf","golf","golf","golf","golf"]}
	var wc: Dictionary = roster.work_by_parcel(defs, view, equipment)
	assert_bool(int(wc["work"][0]) > int(wc["work"][1])).is_true()


func test_incompatible_operator_assignment_is_rejected() -> void:
	var equipment: MHStaffEquipment = MHStaffEquipment.new()
	var unit: Dictionary = equipment.add_unit("sprayer")
	assert_bool(equipment.assign_unit(int(unit["serial"]), 7, MHStaffDefs.KIND_GROUNDS)).is_false()


func test_broken_equipment_requires_technician_capacity() -> void:
	var fleet: MHStaffEquipment = MHStaffEquipment.new()
	fleet.add_unit("greens_mower")
	var unit: Dictionary = fleet.units[0]
	unit["condition"] = 100
	unit["broken"] = true
	fleet.on_day(3, 0)
	assert_int(int(unit["condition"])).is_equal(100)
	fleet.on_day(3, 1000)
	assert_bool(int(unit["condition"]) > 100).is_true()
	assert_bool(fleet.repair_cost_for_day() > 0).is_true()
