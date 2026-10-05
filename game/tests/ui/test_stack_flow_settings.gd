extends GdUnitTestSuite
## MHScreenStack, MHFirstLaunchFlow, MHUISettings (pure parts), MHTouchBridge maths. NOT YET RUN.


func test_stack_push_pop_root_protected() -> void:
	var s: MHScreenStack = MHScreenStack.new()
	s.reset("hud")
	assert_int(s.depth()).is_equal(1)
	assert_bool(s.can_pop()).is_false()
	assert_str(s.pop()).is_equal("")
	assert_bool(s.push("build")).is_true()
	assert_bool(s.push("build")).is_false()
	assert_bool(s.push("")).is_false()
	assert_str(s.top()).is_equal("build")
	assert_str(s.pop()).is_equal("build")
	assert_str(s.top()).is_equal("hud")
	assert_int(s.depth()).is_equal(1)


func test_stack_limits_and_pop_to() -> void:
	var s: MHScreenStack = MHScreenStack.new()
	s.reset("a")
	for i: int in range(MHScreenStack.MAX_DEPTH - 1):
		assert_bool(s.push("s%d" % i)).is_true()
	assert_bool(s.push("overflow")).is_false()
	assert_int(s.depth()).is_equal(MHScreenStack.MAX_DEPTH)
	assert_int(s.pop_to("s1")).is_equal(MHScreenStack.MAX_DEPTH - 3)
	assert_str(s.top()).is_equal("s1")
	assert_int(s.pop_to("missing")).is_equal(0)
	assert_bool(s.contains("a")).is_true()
	assert_bool(s.replace_top("z")).is_true()
	assert_str(s.top()).is_equal("z")
	assert_str(s.at(99)).is_equal("")


func test_first_launch_one_tap_under_30_seconds() -> void:
	var f: MHFirstLaunchFlow = MHFirstLaunchFlow.new()
	f.begin(1000, false)
	assert_int(f.step).is_equal(MHFirstLaunchFlow.Step.CONSENT)
	assert_str(MHFirstLaunchFlow.screen_for(f.step)).is_equal("consent")
	assert_bool(MHFirstLaunchFlow.overlay_for(f.step)).is_false()
	f.on_first_stroke(2000)
	assert_int(f.time_to_first_stroke_ms()).is_equal(-1)
	f.on_consent_continue()
	assert_int(f.taps).is_equal(MHFirstLaunchFlow.TAPS_BEFORE_STROKE)
	assert_int(f.step).is_equal(MHFirstLaunchFlow.Step.COACH_STROKE)
	assert_str(MHFirstLaunchFlow.screen_for(f.step)).is_equal("editor")
	assert_bool(MHFirstLaunchFlow.overlay_for(f.step)).is_true()
	f.on_first_stroke(1000 + 12000)
	assert_int(f.time_to_first_stroke_ms()).is_equal(12000)
	assert_bool(f.within_budget()).is_true()
	assert_int(f.step).is_equal(MHFirstLaunchFlow.Step.COACH_RATING)
	f.on_rating_opened()
	assert_bool(f.is_done()).is_true()


func test_first_launch_budget_and_skip() -> void:
	var f: MHFirstLaunchFlow = MHFirstLaunchFlow.new()
	f.begin(0, true)
	assert_int(f.step).is_equal(MHFirstLaunchFlow.Step.COACH_STROKE)
	f.on_first_stroke(MHFirstLaunchFlow.BUDGET_MS + 1)
	assert_bool(f.within_budget()).is_false()
	var g: MHFirstLaunchFlow = MHFirstLaunchFlow.new()
	g.begin(0, false)
	g.skip()
	assert_bool(g.is_done()).is_true()
	assert_bool(g.within_budget()).is_false()


func test_settings_defaults_have_analytics_off() -> void:
	var s: MHUISettings = MHUISettings.new()
	assert_bool(s.analytics_opt_in).is_false()
	assert_bool(s.consent_shown).is_false()
	assert_int(s.text_scale_pct).is_equal(100)
	assert_str(s.frame_cap).is_equal("auto")


func test_settings_normalisers() -> void:
	assert_str(MHUISettings.normalize_units(" IMPERIAL ")).is_equal(MHUISettings.UNITS_IMPERIAL)
	assert_str(MHUISettings.normalize_units("")).is_equal(MHUISettings.UNITS_METRIC)
	assert_str(MHUISettings.default_units_for_locale("en_US")).is_equal(MHUISettings.UNITS_IMPERIAL)
	assert_str(MHUISettings.default_units_for_locale("en-US")).is_equal(MHUISettings.UNITS_IMPERIAL)
	assert_str(MHUISettings.default_units_for_locale("en_AU")).is_equal(MHUISettings.UNITS_METRIC)
	assert_str(MHUISettings.default_units_for_locale("de")).is_equal(MHUISettings.UNITS_METRIC)
	assert_int(MHUISettings.normalize_colorblind(9)).is_equal(3)
	assert_int(MHUISettings.normalize_colorblind(-1)).is_equal(0)


func test_settings_apply_dict_sanitises_and_round_trips() -> void:
	var s: MHUISettings = MHUISettings.new()
	s.apply_dict({"text_scale_pct": 500, "units": "weird", "colorblind": 7, "frame_cap": "144", "mystery": 1})
	assert_int(s.text_scale_pct).is_equal(160)
	assert_str(s.units).is_equal(MHUISettings.UNITS_METRIC)
	assert_int(s.colorblind).is_equal(3)
	assert_str(s.frame_cap).is_equal("auto")
	s.set_analytics_opt_in(true)
	s.set_left_handed(true)
	s.set_units(MHUISettings.UNITS_IMPERIAL)
	var copy: MHUISettings = MHUISettings.new()
	copy.apply_dict(s.to_dict())
	assert_bool(copy.analytics_opt_in).is_true()
	assert_bool(copy.left_handed).is_true()
	assert_bool(copy.is_metric()).is_false()
	assert_int(copy.text_scale_pct).is_equal(160)


func test_settings_signal() -> void:
	var s: MHUISettings = MHUISettings.new()
	var keys: Array = []
	s.changed.connect(func(k: String) -> void: keys.append(k))
	s.set_text_scale(120)
	s.set_frame_cap("60")
	assert_int(keys.size()).is_equal(2)
	assert_str(str(keys[0])).is_equal("text_scale_pct")
	assert_str(str(keys[1])).is_equal("frame_cap")
	assert_str(s.frame_cap).is_equal("60")


func test_touch_pick_prefers_the_last_rect() -> void:
	var rects: Array = [Rect2(0, 0, 100, 100), Rect2(50, 50, 100, 100)]
	assert_int(MHTouchBridge.pick(rects, Vector2(60, 60))).is_equal(1)
	assert_int(MHTouchBridge.pick(rects, Vector2(10, 10))).is_equal(0)
	assert_int(MHTouchBridge.pick(rects, Vector2(500, 500))).is_equal(-1)
	assert_int(MHTouchBridge.pick([], Vector2(1, 1))).is_equal(-1)


func test_touch_slop() -> void:
	assert_bool(MHTouchBridge.within_slop(Vector2(0, 0), Vector2(10, 0))).is_true()
	assert_bool(MHTouchBridge.within_slop(Vector2(0, 0), Vector2(MHTouchBridge.TAP_SLOP, 0))).is_true()
	assert_bool(MHTouchBridge.within_slop(Vector2(0, 0), Vector2(30, 0))).is_false()
