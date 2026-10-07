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


func test_legacy_craft_save_gets_default_mowing() -> void:
	var hole: MHCraftHole = MHCraftHole.new(8, 8)
	var legacy: Dictionary = hole.to_dict()
	legacy.erase("mowing")
	var restored: MHCraftHole = MHCraftHole.from_dict(legacy)
	assert_object(restored).is_not_null()
	var design: MHMowingDesign = MHMowingDesign.from_dict(restored.mowing)
	assert_int(int(design.fairway_pattern)).is_equal(MHMowingDesign.Pattern.STRIPES)
	assert_int(int(design.green_pattern)).is_equal(MHMowingDesign.Pattern.CROSS_CUT)
