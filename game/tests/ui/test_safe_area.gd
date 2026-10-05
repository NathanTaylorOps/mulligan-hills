extends GdUnitTestSuite
## MHSafeArea pure maths. NOT YET RUN.


func test_notch_landscape() -> void:
	var v: Vector4 = MHSafeArea.insets(Vector2(2400, 1080), Rect2(84, 0, 2232, 1050), Vector2(1280, 720))
	assert_float(v.x).is_equal_approx(44.8, 0.01)
	assert_float(v.y).is_equal_approx(0.0, 0.01)
	assert_float(v.z).is_equal_approx(44.8, 0.01)
	assert_float(v.w).is_equal_approx(20.0, 0.01)


func test_full_cover_or_bad_input_gives_zero() -> void:
	assert_bool(MHSafeArea.is_zero(MHSafeArea.insets(Vector2(2400, 1080), Rect2(0, 0, 2400, 1080), Vector2(1280, 720)))).is_true()
	assert_bool(MHSafeArea.is_zero(MHSafeArea.insets(Vector2(2400, 1080), Rect2(0, 0, 0, 0), Vector2(1280, 720)))).is_true()
	assert_bool(MHSafeArea.is_zero(MHSafeArea.insets(Vector2(0, 0), Rect2(0, 0, 10, 10), Vector2(1280, 720)))).is_true()
	assert_bool(MHSafeArea.is_zero(MHSafeArea.insets(Vector2(2400, 1080), Rect2(0, 0, 2400, 1080), Vector2(0, 0)))).is_true()


func test_inset_is_capped_at_30_percent() -> void:
	var v: Vector4 = MHSafeArea.insets(Vector2(2400, 1080), Rect2(1000, 0, 1400, 1080), Vector2(1280, 720))
	assert_float(v.x).is_equal_approx(384.0, 0.01)


func test_negative_origin_is_ignored() -> void:
	var v: Vector4 = MHSafeArea.insets(Vector2(1000, 1000), Rect2(-10, -10, 1010, 1010), Vector2(1000, 1000))
	assert_float(v.x).is_equal_approx(0.0, 0.01)
	assert_float(v.y).is_equal_approx(0.0, 0.01)


func test_gutter_mirror_and_content_rect() -> void:
	var v: Vector4 = Vector4(40.0, 10.0, 50.0, 20.0)
	var g: Vector4 = MHSafeArea.with_gutter(v, 12.0)
	assert_float(g.x).is_equal_approx(52.0, 0.001)
	assert_float(g.w).is_equal_approx(32.0, 0.001)
	assert_float(MHSafeArea.with_gutter(v, -5.0).x).is_equal_approx(40.0, 0.001)
	var m: Vector4 = MHSafeArea.mirrored(v)
	assert_float(m.x).is_equal_approx(50.0, 0.001)
	assert_float(m.z).is_equal_approx(40.0, 0.001)
	var r: Rect2 = MHSafeArea.content_rect(Vector2(1280, 720), v)
	assert_float(r.position.x).is_equal_approx(40.0, 0.001)
	assert_float(r.position.y).is_equal_approx(10.0, 0.001)
	assert_float(r.size.x).is_equal_approx(1190.0, 0.001)
	assert_float(r.size.y).is_equal_approx(690.0, 0.001)
	assert_float(MHSafeArea.content_rect(Vector2(100, 100), Vector4(80, 0, 80, 0)).size.x).is_equal_approx(0.0, 0.001)
