extends GdUnitTestSuite
## MHTheme: text scaling, dp maths, contrast, theme build. NOT YET RUN.


func test_clamp_text_scale() -> void:
	assert_int(MHTheme.clamp_text_scale(50)).is_equal(80)
	assert_int(MHTheme.clamp_text_scale(200)).is_equal(160)
	assert_int(MHTheme.clamp_text_scale(100)).is_equal(100)


func test_scaled() -> void:
	assert_int(MHTheme.scaled(22, 100)).is_equal(22)
	assert_int(MHTheme.scaled(22, 150)).is_equal(33)
	assert_int(MHTheme.scaled(22, 80)).is_equal(18)
	assert_int(MHTheme.scaled(40, 160)).is_equal(64)
	assert_int(MHTheme.scaled(1, 80)).is_equal(8)
	assert_int(MHTheme.scaled(22, 999)).is_equal(35)


func test_scaled_is_monotonic_across_the_range() -> void:
	var last: int = 0
	var pct: int = MHTheme.TEXT_SCALE_MIN
	while pct <= MHTheme.TEXT_SCALE_MAX:
		var v: int = MHTheme.scaled(MHTheme.FONT_BODY, pct)
		assert_bool(v >= last).is_true()
		last = v
		pct += MHTheme.TEXT_SCALE_STEP


func test_step_text_scale() -> void:
	assert_int(MHTheme.step_text_scale(100, 1)).is_equal(110)
	assert_int(MHTheme.step_text_scale(100, -1)).is_equal(90)
	assert_int(MHTheme.step_text_scale(160, 1)).is_equal(160)
	assert_int(MHTheme.step_text_scale(80, -1)).is_equal(80)
	assert_int(MHTheme.step_text_scale(95, 1)).is_equal(105)


func test_content_scale() -> void:
	assert_float(MHTheme.content_scale(Vector2(2560, 1440), Vector2(1280, 720))).is_equal_approx(2.0, 0.0001)
	assert_float(MHTheme.content_scale(Vector2(1920, 720), Vector2(1280, 720))).is_equal_approx(1.0, 0.0001)
	assert_float(MHTheme.content_scale(Vector2(0, 0), Vector2(1280, 720))).is_equal_approx(1.0, 0.0001)
	assert_float(MHTheme.content_scale(Vector2(100, 100), Vector2(0, 0))).is_equal_approx(1.0, 0.0001)


func test_units_per_dp() -> void:
	assert_float(MHTheme.units_per_dp(160.0, 1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(MHTheme.units_per_dp(480.0, 3.0)).is_equal_approx(1.0, 0.0001)
	assert_float(MHTheme.units_per_dp(96.0, 1.0)).is_equal_approx(1.0, 0.0001)
	assert_float(MHTheme.units_per_dp(320.0, 1.0)).is_equal_approx(2.0, 0.0001)
	assert_float(MHTheme.units_per_dp(320.0, 0.0)).is_equal_approx(2.0, 0.0001)


func test_touch_min_is_48_dp_with_a_floor() -> void:
	assert_float(MHTheme.touch_min(1.0)).is_equal_approx(48.0, 0.0001)
	assert_float(MHTheme.touch_min(0.5)).is_equal_approx(48.0, 0.0001)
	assert_float(MHTheme.touch_min(2.0)).is_equal_approx(96.0, 0.0001)
	assert_float(MHTheme.touch_min(0.0)).is_equal_approx(48.0, 0.0001)


func test_palette_matches_the_brief() -> void:
	assert_str(MHTheme.BG.to_html(false).to_upper()).is_equal("FBF7EC")
	assert_str(MHTheme.INK.to_html(false).to_upper()).is_equal("17342A")
	assert_str(MHTheme.ACCENT.to_html(false).to_upper()).is_equal("C8431F")
	assert_str(MHTheme.GREEN.to_html(false).to_upper()).is_equal("2F6B4F")


func test_contrast() -> void:
	assert_float(MHTheme.contrast_ratio(MHTheme.WHITE, Color.BLACK)).is_equal_approx(21.0, 0.05)
	assert_bool(MHTheme.contrast_ratio(MHTheme.INK, MHTheme.BG) >= 7.0).is_true()
	assert_bool(MHTheme.contrast_ratio(MHTheme.WHITE, MHTheme.ACCENT) >= 4.5).is_true()
	assert_bool(MHTheme.contrast_ratio(MHTheme.WHITE, MHTheme.GREEN) >= 4.5).is_true()
	assert_bool(MHTheme.contrast_ratio(MHTheme.MUTED, MHTheme.BG) >= 4.5).is_true()
	assert_bool(MHTheme.contrast_ratio(MHTheme.WARN_TEXT, MHTheme.CARD) >= 4.5).is_true()
	assert_bool(MHTheme.contrast_ratio(MHTheme.ACCENT, MHTheme.BG) >= 4.5).is_true()


func test_build_scales_font_sizes() -> void:
	var t100: Theme = MHTheme.build(100)
	var t160: Theme = MHTheme.build(160)
	assert_int(t100.default_font_size).is_equal(22)
	assert_int(t160.default_font_size).is_equal(35)
	assert_int(t100.get_font_size(&"font_size", &"H1Label")).is_equal(40)
	assert_int(t160.get_font_size(&"font_size", &"H1Label")).is_equal(64)
	assert_int(t100.get_font_size(&"font_size", &"BigNumberLabel")).is_equal(72)


func test_build_defines_button_variants() -> void:
	var t: Theme = MHTheme.build(100)
	for v: String in ["PrimaryButton", "GreenButton", "SelectedButton", "GhostButton", "ChipButton"]:
		assert_bool(t.has_stylebox(&"normal", StringName(v))).is_true()
		assert_bool(t.has_stylebox(&"disabled", StringName(v))).is_true()
	var sb: StyleBox = t.get_stylebox(&"normal", &"PrimaryButton")
	assert_bool(sb is StyleBoxFlat).is_true()
	assert_bool((sb as StyleBoxFlat).bg_color == MHTheme.ACCENT).is_true()


func test_load_fonts_never_fails_without_files() -> void:
	var f: Dictionary = MHTheme.load_fonts()
	assert_bool(f.has("body")).is_true()
	assert_bool(f.has("heading")).is_true()
