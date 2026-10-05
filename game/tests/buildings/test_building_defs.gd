extends GdUnitTestSuite
## MHBuildingDefs: loads the shipped catalogue and checks DEC-048/050/055/056 values. NOT YET RUN.

var _defs: MHBuildingDefs


func before_test() -> void:
	_defs = MHBuildingDefs.load_default()


func test_loads() -> void:
	assert_str(_defs.error()).is_equal("")
	assert_bool(_defs.is_loaded()).is_true()
	assert_int(_defs.ids().size()).is_equal(10)


func test_building_order_and_classes() -> void:
	var expect: Array = ["clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn", "maintenance", "lodging", "homes", "landmark"]
	assert_array(_defs.ids()).is_equal(expect)
	for id: String in ["driving_range", "pool_spa", "lodging", "homes", "landmark"]:
		assert_bool(_defs.is_heavy(id)).is_true()
	for id2: String in ["clubhouse", "pro_shop", "restaurant", "cart_barn", "maintenance"]:
		assert_bool(_defs.is_heavy(id2)).is_false()


func test_score_and_hole_gates_every_building() -> void:
	var scores: Array = [0, 32, 42, 52, 62]
	var holes: Array = [0, 6, 10, 14, 18]
	for b: Variant in _defs.ids():
		var id: String = str(b)
		for t: int in range(1, 6):
			var r: Dictionary = _defs.tier_requires(id, t)
			assert_int(int(r["min_avg_hole_score"])).is_equal(int(scores[t - 1]))
			assert_int(int(r["min_holes"])).is_equal(int(holes[t - 1]))


func test_payback_targets_and_no_fixed_cost() -> void:
	var pay: Array = [10, 12, 16, 50, 80]
	for b: Variant in _defs.ids():
		var id: String = str(b)
		for t: int in range(1, 6):
			assert_int(_defs.target_payback_days(id, t)).is_equal(int(pay[t - 1]))
			assert_bool(_defs.tier_data(id, t).has("cost")).is_false()
	assert_int(_defs.price_for("clubhouse", 2, 500)).is_equal(6000)
	assert_int(_defs.price_for("clubhouse", 2, -5)).is_equal(0)


func test_heavy_buildings_need_one_extra_parcel_tiers_2_to_5() -> void:
	var light: Array = [5, 5, 8, 11, 14]
	for b: Variant in _defs.ids():
		var id: String = str(b)
		for t: int in range(1, 6):
			var extra: int = 1 if (_defs.is_heavy(id) and t >= 2) else 0
			var r: Dictionary = _defs.tier_requires(id, t)
			assert_int(int(r["min_parcels_owned"])).is_equal(int(light[t - 1]) + extra)


func test_demo_caps() -> void:
	assert_int(_defs.demo_max_holes()).is_equal(9)
	assert_int(_defs.demo_max_tier("clubhouse")).is_equal(2)
	assert_int(_defs.demo_max_tier("pro_shop")).is_equal(2)
	assert_int(_defs.demo_max_tier("driving_range")).is_equal(2)
	assert_int(_defs.demo_max_tier("restaurant")).is_equal(1)
	for id: String in ["pool_spa", "cart_barn", "maintenance", "lodging", "homes", "landmark"]:
		assert_int(_defs.demo_max_tier(id)).is_equal(0)


func test_prerequisite_links_and_tier5_gate() -> void:
	var r: Dictionary = _defs.tier_requires("restaurant", 3)
	assert_int((r["specific"] as Array).size()).is_equal(1)
	assert_int(int(_defs.tier_requires("landmark", 5)["specific"][0]["min_tier"])).is_equal(3)
	for b: Variant in _defs.ids():
		var t5: Dictionary = _defs.tier_requires(str(b), 5)
		assert_bool(t5["hosted_tournament"] != null).is_true()
		for t: int in range(1, 5):
			assert_bool(_defs.tier_requires(str(b), t)["hosted_tournament"] == null).is_true()
	assert_int(int(_defs.tier_requires("clubhouse", 4)["min_members"])).is_equal(50)


func test_homes_slots_and_parcel_kind() -> void:
	assert_int(_defs.home_slots_max()).is_equal(6)
	assert_str(_defs.needs_parcel_kind("homes")).is_equal("homes")
	assert_str(_defs.needs_parcel_kind("clubhouse")).is_equal("")


func test_dead_hole_threshold() -> void:
	assert_int(_defs.dead_hole_score_below()).is_equal(25)
	assert_int(_defs.hole_cap()).is_equal(18)


func test_rejects_garbage_and_non_integers() -> void:
	assert_bool(MHBuildingDefs.from_text("not json").is_loaded()).is_false()
	assert_bool(MHBuildingDefs.from_text("[1,2]").is_loaded()).is_false()
	var text: String = FileAccess.get_file_as_string(MHBuildingDefs.DEFAULT_PATH)
	var bad_float: String = text.replace('"hole_cap": 18', '"hole_cap": 18.5')
	assert_bool(bad_float != text).is_true()
	assert_bool(MHBuildingDefs.from_text(bad_float).is_loaded()).is_false()


func test_rejects_prerequisite_cycle() -> void:
	# Clubhouse tier 2 needs Homes 4, and Homes 4 already needs Clubhouse 4: a cycle.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MHBuildingDefs.DEFAULT_PATH))
	var d: Dictionary = parsed
	var blist: Array = d["buildings"]
	var club: Dictionary = blist[0]
	var tiers: Array = club["tiers"]
	var t2: Dictionary = tiers[1]
	var rq: Dictionary = t2["requires"]
	rq["specific"] = [{"building": "homes", "min_tier": 4}]
	var defs: MHBuildingDefs = MHBuildingDefs.from_text(JSON.stringify(d))
	assert_bool(defs.is_loaded()).is_false()
	assert_str(defs.error()).contains("deadlock")


func test_runtime_copy_equals_spec_data() -> void:
	var root: String = ProjectSettings.globalize_path("res://")
	var spec_path: String = root.path_join("../docs/spec/data/buildings.json")
	assert_bool(FileAccess.file_exists(spec_path)).is_true()
	var spec_text: String = FileAccess.get_file_as_string(spec_path)
	var copy_text: String = FileAccess.get_file_as_string(MHBuildingDefs.DEFAULT_PATH)
	var a: Variant = JSON.parse_string(spec_text)
	var b: Variant = JSON.parse_string(copy_text)
	assert_bool(typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY).is_true()
	assert_str(JSON.stringify(b, "", true)).is_equal(JSON.stringify(a, "", true))
