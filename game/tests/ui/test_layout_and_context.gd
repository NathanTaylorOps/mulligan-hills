extends GdUnitTestSuite
## MHLayout and MHUIContext. NOT YET RUN.


func test_classify() -> void:
	assert_int(MHLayout.classify(Vector2(1280, 720), 1.75)).is_equal(MHLayout.Kind.PHONE_LANDSCAPE)
	assert_int(MHLayout.classify(Vector2(720, 1280), 1.75)).is_equal(MHLayout.Kind.PHONE_PORTRAIT)
	assert_int(MHLayout.classify(Vector2(1280, 720), 0.875)).is_equal(MHLayout.Kind.TABLET)
	assert_int(MHLayout.classify(Vector2(400, 300), 0.0)).is_equal(MHLayout.Kind.PHONE_LANDSCAPE)


func test_columns() -> void:
	assert_int(MHLayout.columns(MHLayout.Kind.PHONE_PORTRAIT)).is_equal(1)
	assert_int(MHLayout.columns(MHLayout.Kind.PHONE_LANDSCAPE)).is_equal(2)
	assert_int(MHLayout.columns(MHLayout.Kind.TABLET)).is_equal(3)
	assert_int(MHLayout.columns(MHLayout.Kind.TABLET, 2)).is_equal(2)
	assert_int(MHLayout.columns(MHLayout.Kind.TABLET, 0)).is_equal(1)


func test_kind_names() -> void:
	assert_str(MHLayout.kind_name(MHLayout.Kind.TABLET)).is_equal("tablet")
	assert_str(MHLayout.kind_name(MHLayout.Kind.PHONE_LANDSCAPE)).is_equal("phone_landscape")
	assert_str(MHLayout.kind_name(MHLayout.Kind.PHONE_PORTRAIT)).is_equal("phone_portrait")


func test_context_phone() -> void:
	var c: MHUIContext = MHUIContext.new()
	c.recompute(Vector2(2400, 1080), Vector2(1280, 720), 420.0, Rect2(0, 0, 2400, 1080))
	assert_float(c.units_per_dp).is_equal_approx(1.75, 0.001)
	assert_int(c.layout_kind).is_equal(MHLayout.Kind.PHONE_LANDSCAPE)
	assert_float(c.touch_min()).is_equal_approx(84.0, 0.01)
	assert_bool(MHSafeArea.is_zero(c.safe_insets)).is_true()
	assert_int(c.columns(3)).is_equal(2)


func test_context_tablet_and_safe_area() -> void:
	var c: MHUIContext = MHUIContext.new()
	c.recompute(Vector2(2560, 1600), Vector2(1280, 720), 280.0, Rect2(0, 40, 2560, 1560))
	assert_int(c.layout_kind).is_equal(MHLayout.Kind.TABLET)
	assert_float(c.safe_insets.y).is_greater(0.0)
	assert_int(c.columns(3)).is_equal(3)


func test_context_follows_settings() -> void:
	var c: MHUIContext = MHUIContext.new()
	c.settings.set_text_scale(150)
	c.settings.set_units(MHUISettings.UNITS_IMPERIAL)
	c.settings.set_left_handed(true)
	assert_int(c.text_scale()).is_equal(150)
	assert_int(c.scaled(22)).is_equal(33)
	assert_bool(c.metric()).is_false()
	assert_bool(c.left_handed()).is_true()
