extends GdUnitTestSuite

func test_equipment_improves_work_and_degrades_deterministically() -> void:
	var a: MHStaffEquipment = MHStaffEquipment.new()
	var b: MHStaffEquipment = MHStaffEquipment.new()
	var a_unit: Dictionary = a.add_unit("greens_mower")
	var b_unit: Dictionary = b.add_unit("greens_mower")
	assert_bool(bool(a_unit["ok"])).is_true()
	assert_bool(bool(b_unit["ok"])).is_true()
	assert_bool(a.assign_unit(int(a_unit["serial"]), 1, MHStaffDefs.KIND_GROUNDS)).is_true()
	assert_bool(b.assign_unit(int(b_unit["serial"]), 1, MHStaffDefs.KIND_GROUNDS)).is_true()
	assert_bool(a.multiplier_for_employee(1, MHStaffDefs.KIND_GROUNDS) > 1000).is_true()
	for _day: int in range(20):
		a.on_day(0, 0, [1])
		b.on_day(0, 0, [1])
	assert_dict(a.to_save_block()).is_equal(b.to_save_block())
	assert_bool(a.multiplier_for_employee(1, MHStaffDefs.KIND_GROUNDS) < 1250).is_true()


func test_workshop_tier_maintains_equipment_condition() -> void:
	var neglected: MHStaffEquipment = MHStaffEquipment.new()
	var maintained: MHStaffEquipment = MHStaffEquipment.new()
	var neglected_unit: Dictionary = neglected.add_unit("fairway_mower")
	var maintained_unit: Dictionary = maintained.add_unit("fairway_mower")
	neglected.assign_unit(int(neglected_unit["serial"]), 1, MHStaffDefs.KIND_GROUNDS)
	maintained.assign_unit(int(maintained_unit["serial"]), 1, MHStaffDefs.KIND_GROUNDS)
	for _day: int in range(30):
		neglected.on_day(0, 0, [1])
		maintained.on_day(3, 1000, [1])
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


func test_unused_equipment_does_not_wear_or_cost_money() -> void:
	var fleet: MHStaffEquipment = MHStaffEquipment.new()
	var bought: Dictionary = fleet.add_unit("greens_mower")
	var serial: int = int(bought["serial"])
	var before: int = int((fleet.units[0] as Dictionary)["condition"])
	fleet.on_day(1, 0, [])
	assert_int(int((fleet.units[0] as Dictionary)["condition"])).is_equal(before)
	assert_int(fleet.operating_cost_for_day()).is_equal(0)
	fleet.assign_unit(serial, 9, "grounds")
	fleet.on_day(1, 0, [9])
	assert_bool(int((fleet.units[0] as Dictionary)["condition"]) < before).is_true()
	assert_bool(fleet.operating_cost_for_day() > 0).is_true()


func test_condition_is_simple_player_facing_state() -> void:
	var fleet: MHStaffEquipment = MHStaffEquipment.new()
	var bought: Dictionary = fleet.add_unit("greens_mower")
	var serial: int = int(bought["serial"])
	assert_str(fleet.condition_state(serial)).is_equal("good")
	(fleet.units[0] as Dictionary)["condition"] = 500
	assert_str(fleet.condition_state(serial)).is_equal("worn")
	(fleet.units[0] as Dictionary)["broken"] = true
	assert_str(fleet.condition_state(serial)).is_equal("broken")


func test_selling_equipment_is_simple_and_removes_it() -> void:
	var fleet: MHStaffEquipment = MHStaffEquipment.new()
	var bought: Dictionary = fleet.add_unit("utility_vehicle")
	var serial: int = int(bought["serial"])
	var value: int = fleet.sell_unit(serial)
	assert_bool(value > 0).is_true()
	assert_int(fleet.units.size()).is_equal(0)
	assert_int(fleet.sell_unit(serial)).is_equal(0)


func test_difficulty_changes_pressure_without_extra_player_controls() -> void:
	var relaxed: MHStaffEquipment = MHStaffEquipment.new()
	var standard: MHStaffEquipment = MHStaffEquipment.new()
	var tycoon: MHStaffEquipment = MHStaffEquipment.new()
	for fleet: MHStaffEquipment in [relaxed, standard, tycoon]:
		var bought: Dictionary = fleet.add_unit("greens_mower")
		fleet.assign_unit(int(bought["serial"]), 5, "grounds")
	relaxed.on_day(1, 0, [5], 650, 1350)
	standard.on_day(1, 0, [5], 1000, 1000)
	tycoon.on_day(1, 0, [5], 1350, 850)
	var relaxed_condition: int = int((relaxed.units[0] as Dictionary)["condition"])
	var standard_condition: int = int((standard.units[0] as Dictionary)["condition"])
	var tycoon_condition: int = int((tycoon.units[0] as Dictionary)["condition"])
	assert_bool(relaxed_condition > standard_condition).is_true()
	assert_bool(standard_condition > tycoon_condition).is_true()


func test_equipment_restore_rejects_wrong_types_and_impossible_state() -> void:
	var fleet: MHStaffEquipment = MHStaffEquipment.new()
	fleet.add_unit("greens_mower")
	var good: Dictionary = fleet.to_save_block()

	var fractional_serial: Dictionary = good.duplicate(true)
	(fractional_serial["units"][0] as Dictionary)["serial"] = 1.5
	assert_bool(MHStaffEquipment.new().from_save_block(fractional_serial)).is_false()

	var string_assignment: Dictionary = good.duplicate(true)
	(string_assignment["units"][0] as Dictionary)["assigned_employee"] = "7"
	assert_bool(MHStaffEquipment.new().from_save_block(string_assignment)).is_false()

	var impossible_broken: Dictionary = good.duplicate(true)
	(impossible_broken["units"][0] as Dictionary)["broken"] = true
	(impossible_broken["units"][0] as Dictionary)["condition"] = 900
	assert_bool(MHStaffEquipment.new().from_save_block(impossible_broken)).is_false()

	var extra_key: Dictionary = good.duplicate(true)
	(extra_key["units"][0] as Dictionary)["free_upgrade"] = true
	assert_bool(MHStaffEquipment.new().from_save_block(extra_key)).is_false()


func test_assigning_second_machine_moves_operator_instead_of_double_using() -> void:
	var fleet: MHStaffEquipment = MHStaffEquipment.new()
	var first: Dictionary = fleet.add_unit("greens_mower")
	var second: Dictionary = fleet.add_unit("utility_vehicle")
	assert_bool(fleet.assign_unit(int(first["serial"]), 12, MHStaffDefs.KIND_GROUNDS)).is_true()
	assert_bool(fleet.assign_unit(int(second["serial"]), 12, MHStaffDefs.KIND_GROUNDS)).is_true()
	assert_int(int((fleet.units[0] as Dictionary)["assigned_employee"])).is_equal(0)
	assert_int(int((fleet.units[1] as Dictionary)["assigned_employee"])).is_equal(12)
	fleet.on_day(0, 0, [12])
	assert_int(int((fleet.units[0] as Dictionary)["condition"])).is_equal(1000)
	assert_bool(int((fleet.units[1] as Dictionary)["condition"]) < 1000).is_true()


func test_equipment_restore_rejects_duplicate_operator_assignment() -> void:
	var fleet: MHStaffEquipment = MHStaffEquipment.new()
	fleet.add_unit("greens_mower")
	fleet.add_unit("utility_vehicle")
	var bad: Dictionary = fleet.to_save_block()
	(bad["units"][0] as Dictionary)["assigned_employee"] = 4
	(bad["units"][1] as Dictionary)["assigned_employee"] = 4
	assert_bool(MHStaffEquipment.new().from_save_block(bad)).is_false()


func test_relaxed_auto_assignment_is_compatible_deterministic_and_one_to_one() -> void:
	var a: MHStaffEquipment = MHStaffEquipment.new()
	var b: MHStaffEquipment = MHStaffEquipment.new()
	for fleet: MHStaffEquipment in [a, b]:
		fleet.add_unit("greens_mower")
		fleet.add_unit("utility_vehicle")
		fleet.add_unit("sprayer")
	var employees: Array = [
		{"serial": 2, "role": "groundskeeper", "areas": [0]},
		{"serial": 3, "role": "groundskeeper", "areas": [1]},
		{"serial": 4, "role": "pest_controller", "areas": [2]},
		{"serial": 5, "role": "groundskeeper", "areas": []},
	]
	var kind_of: Callable = func(role_id: String) -> String:
		return MHStaffDefs.KIND_PEST if role_id == "pest_controller" else MHStaffDefs.KIND_GROUNDS
	assert_int(a.auto_assign(employees, kind_of)).is_equal(3)
	assert_int(b.auto_assign(employees, kind_of)).is_equal(3)
	assert_dict(a.to_save_block()).is_equal(b.to_save_block())
	var seen: Dictionary = {}
	for unit_v: Variant in a.units:
		var operator: int = int((unit_v as Dictionary)["assigned_employee"])
		assert_bool(operator != 0).is_true()
		assert_bool(not seen.has(operator)).is_true()
		seen[operator] = true
	assert_bool(not seen.has(5)).is_true()
