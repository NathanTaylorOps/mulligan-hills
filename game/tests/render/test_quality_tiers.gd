extends GdUnitTestSuite
## Quality tier config validity and ordering (NOT YET RUN in Godot).


func test_all_tiers_valid() -> void:
	for t in MHQuality.TIERS:
		var errs: Array = MHQuality.validate(MHQuality.get_tier(str(t)))
		assert_array(errs).is_empty()


func test_tier_names_match() -> void:
	for t in MHQuality.TIERS:
		assert_str(str(MHQuality.get_tier(str(t))["name"])).is_equal(str(t))


func test_unknown_name_falls_back_to_medium() -> void:
	assert_str(MHQuality.normalize_name("bogus")).is_equal("medium")
	assert_str(MHQuality.normalize_name(" HIGH ")).is_equal("high")


func test_tiers_are_monotonic() -> void:
	var low: Dictionary = MHQuality.get_tier("low")
	var med: Dictionary = MHQuality.get_tier("medium")
	var high: Dictionary = MHQuality.get_tier("high")
	assert_int(int(low["max_golfers"])).is_less_equal(int(med["max_golfers"]))
	assert_int(int(med["max_golfers"])).is_less_equal(int(high["max_golfers"]))
	assert_float(float(low["render_scale_max"])).is_less_equal(float(med["render_scale_max"]))
	assert_float(float(med["render_scale_max"])).is_less_equal(float(high["render_scale_max"]))
	assert_float(float(low["lod1_end"])).is_less_equal(float(high["lod1_end"]))
	assert_str(str(low["shadow_mode"])).is_equal("off")
	assert_str(str(high["shadow_mode"])).is_equal("high")


func test_validate_rejects_bad_configs() -> void:
	var bad: Dictionary = MHQuality.get_tier("medium")
	bad["shadow_atlas_size"] = 1000
	assert_array(MHQuality.validate(bad)).is_not_empty()
	bad = MHQuality.get_tier("medium")
	bad["lod1_end"] = 10.0
	assert_array(MHQuality.validate(bad)).is_not_empty()
	bad = MHQuality.get_tier("medium")
	bad["render_scale_min"] = 1.2
	assert_array(MHQuality.validate(bad)).is_not_empty()
	bad = MHQuality.get_tier("medium")
	bad.erase("msaa")
	assert_array(MHQuality.validate(bad)).is_not_empty()
	bad = MHQuality.get_tier("medium")
	bad["max_golfers"] = 41
	assert_array(MHQuality.validate(bad)).is_not_empty()
