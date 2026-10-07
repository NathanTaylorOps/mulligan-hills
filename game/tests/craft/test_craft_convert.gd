extends GdUnitTestSuite
## MHCraftConvert: painted tiles to the rating engine's hole input. Pure logic. NOT YET RUN in Godot.


func _hole() -> MHCraftHole:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.paint_rect(10, 0, 13, 29, MHCraftHole.Surface.FAIRWAY)
	h.paint_rect(9, 30, 14, 35, MHCraftHole.Surface.GREEN)
	h.add_tee(11, 0)
	h.add_pin(11, 30)
	return h


func _rects(def: Dictionary, t: String) -> Array:
	var out: Array = []
	for f: Variant in (def["features"] as Array):
		if str((f as Dictionary)["t"]) == t and (f as Dictionary).has("rect"):
			out.append((f as Dictionary)["rect"])
	return out


func test_a_plain_fairway_becomes_one_rectangle() -> void:
	var def: Dictionary = MHCraftConvert.to_hole_def(_hole(), 3, 0, 0)
	assert_int(int(def["slot_id"])).is_equal(3)
	var r: Array = _rects(def, "fairway")
	assert_int(r.size()).is_equal(1)
	var rect: Array = r[0] as Array
	assert_int(int(rect[0])).is_equal(-4)
	assert_int(int(rect[1])).is_equal(0)
	assert_int(int(rect[2])).is_equal(4)
	assert_int(int(rect[3])).is_equal(60)


func test_tee_green_and_heights() -> void:
	var h: MHCraftHole = _hole()
	h.set_height_tile(11, 0, 2)
	h.set_height_tile(11, 30, 3)
	var def: Dictionary = MHCraftConvert.to_hole_def(h, 0, 0, 0)
	assert_int(int((def["tee"] as Array)[0])).is_equal(-1)
	assert_int(int((def["tee"] as Array)[1])).is_equal(1)
	var g: Array = def["green"] as Array
	assert_int(int(g[0])).is_equal(-1)
	assert_int(int(g[1])).is_equal(61)
	assert_int(int(g[2])).is_equal(6) # 36 tiles x 4 sq yd = 144 sq yd -> radius floor(sqrt(144 x 7/22)) = 6
	assert_int(int(def["tee_z_mm"])).is_equal(2000)
	assert_int(int(def["green_z_mm"])).is_equal(3000)


func test_an_l_shaped_bunker_becomes_two_rectangles_in_scan_order() -> void:
	var h: MHCraftHole = _hole()
	h.paint_tile(14, 20, MHCraftHole.Surface.BUNKER)
	h.paint_tile(14, 21, MHCraftHole.Surface.BUNKER)
	h.paint_tile(15, 21, MHCraftHole.Surface.BUNKER)
	var r: Array = _rects(MHCraftConvert.to_hole_def(h, 0, 0, 0), "bunker")
	assert_int(r.size()).is_equal(2)
	var a: Array = r[0] as Array
	assert_int(int(a[0])).is_equal(4)
	assert_int(int(a[1])).is_equal(40)
	assert_int(int(a[2])).is_equal(6)
	assert_int(int(a[3])).is_equal(44)
	var b: Array = r[1] as Array
	assert_int(int(b[0])).is_equal(6)
	assert_int(int(b[1])).is_equal(42)
	assert_int(int(b[2])).is_equal(8)
	assert_int(int(b[3])).is_equal(44)


func test_surfaces_map_to_feature_types() -> void:
	var h: MHCraftHole = _hole()
	h.paint_tile(2, 5, MHCraftHole.Surface.WATER)
	h.paint_tile(3, 5, MHCraftHole.Surface.WASTE)
	h.paint_tile(4, 5, MHCraftHole.Surface.DEEP_ROUGH)
	h.paint_tile(5, 5, MHCraftHole.Surface.OUT_OF_BOUNDS)
	h.paint_tile(6, 5, MHCraftHole.Surface.FIRST_CUT)
	h.paint_tile(7, 5, MHCraftHole.Surface.PATH)
	var def: Dictionary = MHCraftConvert.to_hole_def(h, 0, 0, 0)
	assert_int(_rects(def, "water").size()).is_equal(1)
	assert_int(_rects(def, "bunker").size()).is_equal(1) # waste counts as sand
	assert_int(_rects(def, "deep_rough").size()).is_equal(1)
	assert_int(_rects(def, "ob").size()).is_equal(1)
	assert_int(_rects(def, "fairway").size()).is_equal(2) # the main fairway and the first cut tile at column 6
	# Path adds no feature: the rating engine only knows the five area types.


func test_trees_rocks_and_flowers() -> void:
	var h: MHCraftHole = _hole()
	h.add_tree_yd(8, 20)
	h.add_tree_yd(-8, 10)
	h.add_tree_yd(-8, 5)
	h.rocks = 3
	h.flowers = 12
	var feats: Array = MHCraftConvert.to_hole_def(h, 0, 0, 0)["features"] as Array
	var tree: Dictionary = {}
	var rock: int = -1
	var flower: int = -1
	for f: Variant in feats:
		var d: Dictionary = f as Dictionary
		if str(d["t"]) == "tree":
			tree = d
		elif str(d["t"]) == "rock":
			rock = int(d["count"])
		elif str(d["t"]) == "flower":
			flower = int(d["count"])
	var at: Array = tree["at"] as Array
	assert_int(at.size()).is_equal(3)
	assert_int(int((at[0] as Array)[1])).is_equal(5) # sorted by x then y
	assert_int(int((at[2] as Array)[0])).is_equal(8)
	assert_int(rock).is_equal(3)
	assert_int(flower).is_equal(12)


func test_problems_stop_a_hole_that_cannot_be_rated() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	var p: Array = MHCraftConvert.problems(h)
	assert_bool(p.has("no_tee")).is_true()
	assert_bool(p.has("no_green")).is_true()
	assert_bool(p.has("no_pin")).is_true()
	assert_bool(MHCraftConvert.to_hole_def(h, 0, 0, 0).is_empty()).is_true()
	h.paint_rect(11, 30, 12, 31, MHCraftHole.Surface.GREEN)
	h.add_tee(11, 0)
	h.add_pin(5, 5) # not on the green
	assert_bool(MHCraftConvert.problems(h).has("pin_not_on_green")).is_true()
	var h2: MHCraftHole = _hole()
	h2.paint_tile(11, 0, MHCraftHole.Surface.WATER)
	assert_bool(MHCraftConvert.problems(h2).has("tee_in_hazard")).is_true()
	assert_array(MHCraftConvert.problems(_hole())).is_empty()


func test_craft_green_and_length_requirements_match_rating_engine() -> void:
	var h: MHCraftHole = _hole()
	assert_int(MHCraftConvert.green_radius_yd(h)).is_equal(6)
	assert_bool(MHRHole.from_def(MHCraftConvert.to_hole_def(h, 0, 0, 0)).valid).is_true()
	# Legacy four-cell putting greens passed craft validation even though the
	# rating engine rejected radius=2 (RC006), blocking every Build click.
	h.paint_rect(9, 30, 14, 35, MHCraftHole.Surface.ROUGH)
	h.paint_rect(11, 30, 12, 31, MHCraftHole.Surface.GREEN)
	assert_int(MHCraftConvert.green_radius_yd(h)).is_equal(2)
	assert_bool(MHCraftConvert.problems(h).has("green_too_small")).is_true()
	assert_bool(MHCraftConvert.to_hole_def(h, 0, 0, 0).is_empty()).is_true()
	# Moving the tee too near the pin must produce a build hint, not RC003.
	h.paint_rect(9, 30, 14, 35, MHCraftHole.Surface.GREEN)
	h.tees.clear()
	h.add_tee(11, 20)
	assert_bool(MHCraftConvert.problems(h).has("hole_too_short")).is_true()


func test_each_round_uses_the_next_pin() -> void:
	var h: MHCraftHole = _hole()
	h.paint_rect(10, 30, 13, 31, MHCraftHole.Surface.GREEN)
	h.add_pin(13, 31)
	var a: Dictionary = MHCraftConvert.to_hole_def(h, 0, 0, 0)
	var b: Dictionary = MHCraftConvert.to_hole_def(h, 0, 0, 1)
	var c: Dictionary = MHCraftConvert.to_hole_def(h, 0, 0, 2)
	assert_int(int((a["green"] as Array)[0])).is_not_equal(int((b["green"] as Array)[0]))
	assert_bool(a["green"] == c["green"]).is_true() # two pins take turns
	assert_bool(a["tee"] == b["tee"]).is_true()
	assert_int(MHCraftConvert.length_yd(h, 0, 1)).is_greater(MHCraftConvert.length_yd(h, 0, 0))


func test_the_output_passes_rating_validation_and_is_deterministic() -> void:
	var h: MHCraftHole = _hole()
	h.paint_rect(14, 12, 15, 14, MHCraftHole.Surface.WATER)
	h.paint_rect(8, 18, 9, 19, MHCraftHole.Surface.BUNKER)
	h.add_tree_yd(-10, 20)
	var input: Dictionary = MHCraftConvert.rating_input(h, 0, 0, 0)
	var check: Dictionary = MHRatingEngine.validate_input(input)
	assert_bool(bool(check["ok"])).override_failure_message(str(check.get("code", ""))).is_true()
	assert_bool(JSON.stringify(input) == JSON.stringify(MHCraftConvert.rating_input(h, 0, 0, 0))).is_true()
	assert_int(MHCraftConvert._isqrt(0)).is_equal(0)
	assert_int(MHCraftConvert._isqrt(99)).is_equal(9)
	assert_int(MHCraftConvert._isqrt(100)).is_equal(10)


func test_flat_hole_has_no_relief_and_a_painted_hill_does() -> void:
	var h: MHCraftHole = _hole()
	assert_bool(MHCraftConvert.to_hole_def(h, 0, 0, 0).has("relief")).is_false()
	h.set_height_tile(11, 15, 4)
	var def: Dictionary = MHCraftConvert.to_hole_def(h, 0, 0, 0)
	assert_bool(def.has("relief")).is_true()
	var rl: Dictionary = def["relief"] as Dictionary
	assert_int(int(rl["cols"])).is_equal(h.cols)
	assert_int(int(rl["rows"])).is_equal(h.rows)
	assert_int((rl["z"] as Array).size()).is_equal(h.cols * h.rows)
	assert_int(int(rl["step"])).is_equal(2)


func test_hill_hole_passes_validation_and_counts_as_elevation() -> void:
	var h: MHCraftHole = _hole()
	h.set_height_tile(11, 15, 6)
	var inp: Dictionary = MHCraftConvert.rating_input(h, 0, 0, 0)
	assert_bool(bool(MHRatingEngine.validate_input(inp)["ok"])).is_true()
	var hd: MHRHole = MHRHole.from_def(inp["hole"] as Dictionary)
	assert_int(hd.relief_range).is_equal(6000)
	assert_bool(hd.elev_mm() >= 3600).is_true()


func test_elevated_craft_hole_crosses_canonical_course_save_boundary() -> void:
	var h: MHCraftHole = _hole()
	h.set_height_tile(11, 15, 6)
	var layout: Dictionary = MHCraftConvert.to_hole_def(h, 0, 0, 0)
	assert_bool(layout.has("relief")).is_true()
	var course: Dictionary = {
		"schema_version": 1,
		"rating_engine_version": MHRatingEngine.RATING_VERSION,
		"world": {
			"width_dm": 1000,
			"height_dm": 1000,
			"parcels": [{"parcel_id": 0, "x0": 0, "y0": 0, "x1": 999, "y1": 999, "owned": true}],
		},
		"holes": [],
	}
	var encoded: MHSaveResult = MHCourseLayout.encode([layout], course, [[100, 100]])
	assert_bool(encoded.is_ok()).override_failure_message(encoded.message).is_true()
	if not encoded.is_ok():
		return
	var decoded: MHSaveResult = MHCourseLayout.decode(encoded.value as Dictionary)
	assert_bool(decoded.is_ok()).override_failure_message(decoded.message).is_true()
	if decoded.is_ok():
		assert_array(decoded.value as Array).contains_exactly([layout])
