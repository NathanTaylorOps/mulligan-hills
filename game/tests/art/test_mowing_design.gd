extends GdUnitTestSuite

func test_all_mowing_patterns_produce_alternating_samples() -> void:
	var design: MHMowingDesign = MHMowingDesign.new()
	for pattern: int in range(MHMowingDesign.Pattern.size()):
		design.fairway_pattern = pattern as MHMowingDesign.Pattern
		var seen_on: bool = false
		var seen_off: bool = false
		for y in range(0, 32, 2):
			for x in range(-16, 18, 2):
				if design.highlighted(MHCraftHole.Surface.FAIRWAY, float(x), float(y), 0.0):
					seen_on = true
				else:
					seen_off = true
		assert_bool(seen_on).is_true()
		assert_bool(seen_off).is_true()


func test_green_and_fairway_patterns_are_independent() -> void:
	var design: MHMowingDesign = MHMowingDesign.new()
	design.fairway_pattern = MHMowingDesign.Pattern.STRIPES
	design.green_pattern = MHMowingDesign.Pattern.DIAMOND
	assert_int(int(design.pattern_for(MHCraftHole.Surface.FAIRWAY))).is_equal(MHMowingDesign.Pattern.STRIPES)
	assert_int(int(design.pattern_for(MHCraftHole.Surface.GREEN))).is_equal(MHMowingDesign.Pattern.DIAMOND)


func test_mowing_design_round_trip_and_clamps() -> void:
	var design: MHMowingDesign = MHMowingDesign.from_dict({
		"fairway_pattern": MHMowingDesign.Pattern.ZIG_ZAG,
		"green_pattern": MHMowingDesign.Pattern.CHEVRON,
		"fairway_width_yd": 99, "green_width_yd": 1,
		"direction_deg": 225, "intensity": 1.0})
	assert_int(int(design.fairway_pattern)).is_equal(MHMowingDesign.Pattern.ZIG_ZAG)
	assert_int(design.fairway_width_yd).is_equal(MHMowingDesign.MAX_WIDTH_YD)
	assert_int(design.green_width_yd).is_equal(MHMowingDesign.MIN_WIDTH_YD)
	assert_int(design.direction_deg).is_equal(45)
	assert_float(design.intensity).is_equal_approx(0.14, 0.0001)


func test_serialized_mowing_contains_no_float_values() -> void:
	var design: MHMowingDesign = MHMowingDesign.new()
	design.intensity = 0.065
	var saved: Dictionary = design.to_dict()
	assert_bool(saved.has("intensity")).is_false()
	assert_int(typeof(saved["intensity_pm"])).is_equal(TYPE_INT)
	assert_int(int(saved["intensity_pm"])).is_equal(65)
	var restored: MHMowingDesign = MHMowingDesign.from_dict(saved)
	assert_float(restored.intensity).is_equal_approx(0.065, 0.0001)


func test_persisted_mowing_contract_rejects_malformed_values() -> void:
	var saved: Dictionary = MHMowingDesign.new().to_dict()
	assert_bool(MHMowingDesign.is_save_dict_valid(saved)).is_true()
	saved["direction_deg"] = 180
	assert_bool(MHMowingDesign.is_save_dict_valid(saved)).is_false()
	saved = MHMowingDesign.new().to_dict()
	saved["intensity_pm"] = "65"
	assert_bool(MHMowingDesign.is_save_dict_valid(saved)).is_false()
	saved = MHMowingDesign.new().to_dict()
	saved["extra"] = 1
	assert_bool(MHMowingDesign.is_save_dict_valid(saved)).is_false()


func test_legacy_float_backed_mowing_is_strictly_migrated() -> void:
	var legacy: Dictionary = MHMowingDesign.new().to_dict()
	legacy["intensity"] = 0.065
	legacy.erase("intensity_pm")
	assert_bool(MHMowingDesign.is_legacy_save_dict_valid(legacy)).is_true()
	assert_bool(MHMowingDesign.is_save_dict_valid(legacy)).is_false()
	var restored: MHMowingDesign = MHMowingDesign.from_dict(legacy)
	assert_int(int(restored.to_dict()["intensity_pm"])).is_equal(65)
	legacy["extra"] = 1
	assert_bool(MHMowingDesign.is_legacy_save_dict_valid(legacy)).is_false()


func test_craft_reader_accepts_and_normalizes_legacy_float_mowing() -> void:
	var hole: MHCraftHole = MHCraftHole.new(8, 8)
	var legacy: Dictionary = hole.to_dict()
	var old_mowing: Dictionary = (legacy["mowing"] as Dictionary).duplicate(true)
	old_mowing["intensity"] = 0.065
	old_mowing.erase("intensity_pm")
	legacy["mowing"] = old_mowing
	var restored: MHCraftHole = MHCraftHole.from_dict(legacy)
	assert_object(restored).is_not_null()
	if restored != null:
		assert_bool(MHMowingDesign.is_save_dict_valid(restored.mowing)).is_true()
		assert_int(int(restored.mowing["intensity_pm"])).is_equal(65)


func test_legacy_craft_save_gets_default_mowing() -> void:
	var hole: MHCraftHole = MHCraftHole.new(8, 8)
	var legacy: Dictionary = hole.to_dict()
	legacy.erase("mowing")
	var restored: MHCraftHole = MHCraftHole.from_dict(legacy)
	assert_object(restored).is_not_null()
	var design: MHMowingDesign = MHMowingDesign.from_dict(restored.mowing)
	assert_int(int(design.fairway_pattern)).is_equal(MHMowingDesign.Pattern.STRIPES)
	assert_int(int(design.green_pattern)).is_equal(MHMowingDesign.Pattern.CROSS_CUT)
