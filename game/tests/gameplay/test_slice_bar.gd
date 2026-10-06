extends GdUnitTestSuite
## MHSliceBar: tabs, hole label and tee shot text. Pure logic. NOT YET RUN in Godot.


func test_every_button_is_in_exactly_one_tab() -> void:
	var seen: Dictionary = {}
	for tab: String in MHSliceBar.tab_ids():
		for b: Variant in MHSliceBar.buttons_for(tab):
			assert_bool(seen.has(str(b))).override_failure_message("button %s twice" % str(b)).is_false()
			seen[str(b)] = true
	for need: String in ["build_hole", "buy_land", "buildings", "pause", "speed", "fee_down", "fee_up", "zoom_in",
			"zoom_out", "turn_left", "turn_right", "quality", "back"]:
		assert_bool(seen.has(need)).override_failure_message("missing " + need).is_true()
	assert_int(MHSliceBar.buttons_for("nope").size()).is_equal(0)


func test_par_follows_length() -> void:
	assert_int(MHSliceBar.par_for_yards(65)).is_equal(3)
	assert_int(MHSliceBar.par_for_yards(260)).is_equal(3)
	assert_int(MHSliceBar.par_for_yards(381)).is_equal(4)
	assert_int(MHSliceBar.par_for_yards(471)).is_equal(5)


func test_club_grows_with_distance() -> void:
	assert_str(MHSliceBar.club_for_yards(5)).is_equal("Putter")
	assert_str(MHSliceBar.club_for_yards(65)).is_equal("Pitching wedge")
	assert_str(MHSliceBar.club_for_yards(185)).is_equal("3 iron")
	assert_str(MHSliceBar.club_for_yards(400)).is_equal("Driver")


func test_readout_text_for_a_real_hole() -> void:
	var slot: int = 1
	var yards: int = MHSliceLayout.hole_length_yd(slot)
	var d: Dictionary = MHSliceLayout.HOLE_DESIGNS[slot] as Dictionary
	var text: String = MHSliceBar.readout(slot, yards, not (d["water"] as Array).is_empty(), not (d["trees"] as Array).is_empty())
	assert_bool(text.begins_with("Hole 2  %d yd  Par 3" % yards)).is_true()
	assert_bool(text.contains("Pitching wedge")).is_true()
	assert_bool(text.contains("Suggested arc: High")).is_true() # slot 1 has water and trees
	assert_str(MHSliceBar.arc_for(false, false)).is_equal("Normal")
