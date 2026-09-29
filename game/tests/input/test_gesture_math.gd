extends GdUnitTestSuite
## Pure math and orbit rig tests. NOT YET RUN.

func test_wrap_angle_at_pi() -> void:
	assert_float(MHGestureMath.wrap_angle(PI)).is_equal_approx(PI, 0.0001)
	assert_float(MHGestureMath.wrap_angle(-PI)).is_equal_approx(PI, 0.0001)
	assert_float(MHGestureMath.wrap_angle(PI + 0.1)).is_equal_approx(-PI + 0.1, 0.0001)
	assert_float(MHGestureMath.wrap_angle(3.0 * PI)).is_equal_approx(PI, 0.0001)
	assert_float(MHGestureMath.wrap_angle(0.5)).is_equal_approx(0.5, 0.0001)


func test_twist_quarter_turn_clockwise() -> void:
	# Vector b-a rotates from (200,0) to (0,200): +90 degrees, y is down.
	var d: float = MHGestureMath.angle_delta(Vector2(200, 0), Vector2(0, 200))
	assert_float(d).is_equal_approx(PI / 2.0, 0.0001)


func test_twist_wraps_across_pi() -> void:
	var prev: Vector2 = Vector2.from_angle(deg_to_rad(170.0))
	var cur: Vector2 = Vector2.from_angle(deg_to_rad(-170.0))
	# Shortest way is +20 degrees, not -340.
	assert_float(MHGestureMath.angle_delta(prev, cur)).is_equal_approx(deg_to_rad(20.0), 0.0001)
	assert_float(MHGestureMath.angle_delta(cur, prev)).is_equal_approx(deg_to_rad(-20.0), 0.0001)


func test_twist_degenerate_vector_is_zero() -> void:
	assert_float(MHGestureMath.angle_delta(Vector2.ZERO, Vector2(1, 0))).is_equal(0.0)


func test_pinch_ratio() -> void:
	assert_float(MHGestureMath.pinch_ratio(100.0, 200.0)).is_equal_approx(2.0, 0.0001)
	assert_float(MHGestureMath.pinch_ratio(0.0, 200.0)).is_equal(1.0)


func test_two_finger_delta_pure_pan() -> void:
	var d: MHGestureMath.TwoFingerDelta = MHGestureMath.two_finger_delta(
		Vector2(100, 100), Vector2(200, 100), Vector2(110, 120), Vector2(210, 120))
	assert_vector(d.pan).is_equal_approx(Vector2(10, 20), Vector2(0.001, 0.001))
	assert_float(d.scale_ratio).is_equal_approx(1.0, 0.0001)
	assert_float(d.twist).is_equal_approx(0.0, 0.0001)


func test_pan_world_delta_yaw_zero_and_ninety() -> void:
	var p0: Vector3 = MHGestureMath.pan_world_delta(Vector2(10, 0), 0.0, 10.0, 0.001)
	assert_vector(p0).is_equal_approx(Vector3(-0.1, 0, 0), Vector3(0.0001, 0.0001, 0.0001))
	var p1: Vector3 = MHGestureMath.pan_world_delta(Vector2(0, 10), 0.0, 10.0, 0.001)
	assert_vector(p1).is_equal_approx(Vector3(0, 0, -0.1), Vector3(0.0001, 0.0001, 0.0001))
	var p2: Vector3 = MHGestureMath.pan_world_delta(Vector2(10, 0), PI / 2.0, 10.0, 0.001)
	assert_vector(p2).is_equal_approx(Vector3(0, 0, 0.1), Vector3(0.0001, 0.0001, 0.0001))


func test_pinch_zoom_clamps() -> void:
	var rig: MHOrbitRig = MHOrbitRig.new(MHCameraConfig.new())
	rig.apply_zoom_ratio(1000.0)
	assert_float(rig.distance).is_equal_approx(rig.config.min_distance, 0.0001)
	rig.apply_zoom_ratio(0.0001)
	assert_float(rig.distance).is_equal_approx(rig.config.max_distance, 0.0001)


func test_pinch_out_reduces_distance() -> void:
	var rig: MHOrbitRig = MHOrbitRig.new(MHCameraConfig.new())
	var before: float = rig.distance
	rig.apply_zoom_ratio(1.2)
	assert_bool(rig.distance < before).is_true()


func test_tilt_clamped_when_manual() -> void:
	var cfg: MHCameraConfig = MHCameraConfig.new()
	cfg.tilt_follows_zoom = false
	var rig: MHOrbitRig = MHOrbitRig.new(cfg)
	rig.tilt_by_deg(500.0)
	assert_float(rig.pitch_deg).is_equal_approx(cfg.tilt_max_deg, 0.0001)
	rig.tilt_by_deg(-500.0)
	assert_float(rig.pitch_deg).is_equal_approx(cfg.tilt_min_deg, 0.0001)


func test_pitch_stays_in_limits_when_following_zoom() -> void:
	var rig: MHOrbitRig = MHOrbitRig.new(MHCameraConfig.new())
	rig.apply_zoom_ratio(1000.0)
	assert_bool(rig.pitch_deg >= rig.config.tilt_min_deg and rig.pitch_deg <= rig.config.tilt_max_deg).is_true()
	rig.apply_zoom_ratio(0.0001)
	assert_bool(rig.pitch_deg >= rig.config.tilt_min_deg and rig.pitch_deg <= rig.config.tilt_max_deg).is_true()


func test_twist_changes_yaw_and_wraps() -> void:
	var rig: MHOrbitRig = MHOrbitRig.new(MHCameraConfig.new())
	rig.apply_twist(PI - 0.1, 0.0)
	rig.end_gesture()
	rig.apply_twist(0.2, 0.0)
	assert_float(rig.yaw).is_equal_approx(-PI + 0.1, 0.0001)


func test_snap_north_eases_to_exact_zero_shortest_way() -> void:
	var rig: MHOrbitRig = MHOrbitRig.new(MHCameraConfig.new())
	rig.apply_twist(-2.5, 0.0)
	rig.end_gesture()
	rig.snap_north()
	var prev_abs: float = absf(rig.yaw)
	for i in 300:
		rig.update(1.0 / 60.0)
		assert_bool(absf(rig.yaw) <= prev_abs + 0.000001).is_true()
		prev_abs = absf(rig.yaw)
	assert_float(rig.yaw).is_equal(0.0)
	assert_bool(rig.is_snapping()).is_false()


func test_user_gesture_cancels_snap() -> void:
	var rig: MHOrbitRig = MHOrbitRig.new(MHCameraConfig.new())
	rig.apply_twist(1.0, 0.0)
	rig.end_gesture()
	rig.snap_north()
	rig.apply_twist(0.01, 0.0)
	assert_bool(rig.is_snapping()).is_false()


func test_pan_bounds_clamp() -> void:
	var cfg: MHCameraConfig = MHCameraConfig.new()
	cfg.use_pan_bounds = true
	cfg.pan_bounds = Rect2(-5, -5, 10, 10)
	var rig: MHOrbitRig = MHOrbitRig.new(cfg)
	rig.apply_pan_pixels(Vector2(-100000, 100000), 0.0)
	assert_bool(rig.target.x <= 5.0 and rig.target.z <= 5.0 and rig.target.x >= -5.0 and rig.target.z >= -5.0).is_true()
