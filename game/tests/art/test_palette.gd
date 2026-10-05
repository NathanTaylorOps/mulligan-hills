extends GdUnitTestSuite
## Palette helpers and a few readability checks for things that sit on grass and signs. NOT YET RUN in Godot.


func test_contrast_extremes() -> void:
	assert_float(MHPalette.contrast_ratio(Color(0, 0, 0), Color(1, 1, 1))).is_equal_approx(21.0, 0.01)
	assert_float(MHPalette.contrast_ratio(Color(0.5, 0.5, 0.5), Color(0.5, 0.5, 0.5))).is_equal_approx(1.0, 0.0001)
	assert_float(MHPalette.contrast_ratio(MHPalette.BLACK_TEXT, MHPalette.WHITE_TEXT)).is_greater(15.0)


func test_text_on_picks_readable_text() -> void:
	assert_bool(MHPalette.text_on(MHPalette.SIGN_CREAM) == MHPalette.BLACK_TEXT).is_true()
	assert_bool(MHPalette.text_on(MHPalette.SIGN_GREEN) == MHPalette.WHITE_TEXT).is_true()


func test_sign_border_and_face_are_readable() -> void:
	assert_bool(MHPalette.has_contrast(MHPalette.SIGN_GREEN, MHPalette.SIGN_CREAM, 4.5)).is_true()


func test_course_accents_stand_out_on_grass() -> void:
	var accents: Array = [MHPalette.FLAG_RED, MHPalette.FLAG_YELLOW, MHPalette.FLAG_WHITE, MHPalette.TEE_WHITE,
		MHPalette.TEE_YELLOW, MHPalette.TEE_BLUE, MHPalette.TEE_RED, MHPalette.CART_BODY, MHPalette.BALL_WHITE]
	for a: Variant in accents:
		assert_bool(MHPalette.has_contrast(a as Color, MHPalette.GRASS, 1.5)).is_true()


func test_shade_keeps_alpha_and_clamps() -> void:
	var c: Color = Color(0.5, 0.6, 0.7, 0.4)
	var d: Color = MHPalette.shade(c, 0.5)
	assert_float(d.r).is_equal_approx(0.25, 0.0001)
	assert_float(d.a).is_equal_approx(0.4, 0.0001)
	var e: Color = MHPalette.shade(Color(0.9, 0.9, 0.9), 3.0)
	assert_float(e.r).is_equal_approx(1.0, 0.0001)


func test_pick_wraps_in_both_directions() -> void:
	var list: Array = MHPalette.FLOWERS
	var n: int = list.size()
	assert_bool(MHPalette.pick(list, 0) == list[0]).is_true()
	assert_bool(MHPalette.pick(list, n) == list[0]).is_true()
	assert_bool(MHPalette.pick(list, -1) == list[n - 1]).is_true()
	assert_bool(MHPalette.pick([], 3) == Color(1.0, 0.0, 1.0)).is_true()


func test_variety_lists_are_populated() -> void:
	assert_int(MHPalette.SKIN_TONES.size()).is_greater_equal(5)
	assert_int(MHPalette.HAIR_COLORS.size()).is_greater_equal(5)
	assert_int(MHPalette.OUTFIT_COLORS.size()).is_greater_equal(6)
	assert_int(MHPalette.TROUSER_COLORS.size()).is_greater_equal(4)
	assert_int(MHPalette.UMBRELLA_COLORS.size()).is_greater_equal(4)
	assert_int(MHPalette.FLOWERS.size()).is_greater_equal(4)


func test_every_list_colour_is_a_valid_srgb_value() -> void:
	var lists: Array = [MHPalette.FLOWERS, MHPalette.SKIN_TONES, MHPalette.HAIR_COLORS,
		MHPalette.OUTFIT_COLORS, MHPalette.TROUSER_COLORS, MHPalette.UMBRELLA_COLORS]
	for l: Variant in lists:
		for c: Variant in (l as Array):
			var col: Color = c
			assert_float(col.r).is_between(0.0, 1.0)
			assert_float(col.g).is_between(0.0, 1.0)
			assert_float(col.b).is_between(0.0, 1.0)
