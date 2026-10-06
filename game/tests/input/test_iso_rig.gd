extends GdUnitTestSuite
## MHIsoRig: isometric camera maths (DEC-085). Pure logic. NOT YET RUN in Godot.


func test_four_views_wrap_in_both_directions() -> void:
	var r: MHIsoRig = MHIsoRig.new()
	assert_int(r.view).is_equal(0)
	for i: int in range(4):
		r.rotate_step(1)
	assert_int(r.view).is_equal(0)
	assert_int(r.rotate_step(-1)).is_equal(3)
	assert_float(MHIsoRig.yaw_for_view(3)).is_equal_approx(315.0, 0.0001)
	assert_float(MHIsoRig.yaw_for_view(4)).is_equal_approx(45.0, 0.0001)


func test_zoom_steps_clamp_at_both_ends() -> void:
	var r: MHIsoRig = MHIsoRig.new()
	for i: int in range(10):
		r.zoom_step(1)
	assert_int(r.zoom_index).is_equal(0)
	for i: int in range(10):
		r.zoom_step(-1)
	assert_int(r.zoom_index).is_equal(MHIsoRig.ZOOM_SIZES.size() - 1)


func test_camera_looks_down_at_the_fixed_pitch() -> void:
	var r: MHIsoRig = MHIsoRig.new()
	r.target = Vector3(64.0, 0.0, 70.0)
	var d: Vector3 = r.get_camera_position() - r.target
	var pitch: float = rad_to_deg(asin(d.y / d.length()))
	assert_float(pitch).is_equal_approx(MHIsoRig.PITCH_DEG, 0.001)
	assert_float(d.length()).is_equal_approx(MHIsoRig.EYE_DISTANCE_M, 0.001)
	# View 0 looks from the south-east: positive x and z.
	assert_float(d.x).is_greater(0.0)
	assert_float(d.z).is_greater(0.0)


func test_screen_axes_are_perpendicular_ground_directions_in_every_view() -> void:
	var r: MHIsoRig = MHIsoRig.new()
	for v: int in range(4):
		r.snap_view(v)
		var up: Vector3 = r.screen_up_ground()
		var right: Vector3 = r.screen_right_ground()
		assert_float(up.length()).is_equal_approx(1.0, 0.0001)
		assert_float(right.length()).is_equal_approx(1.0, 0.0001)
		assert_float(up.dot(right)).is_equal_approx(0.0, 0.0001)
		assert_float(up.y).is_equal_approx(0.0, 0.0001)
		# The camera sits behind the screen-up direction: up points away from the eye on the ground.
		var eye: Vector3 = r.eye_direction()
		assert_float(up.x * eye.x + up.z * eye.z).is_less(0.0)


func test_dragging_moves_the_ground_with_the_finger() -> void:
	var r: MHIsoRig = MHIsoRig.new()
	r.bounds = Rect2(-1000.0, -1000.0, 2000.0, 2000.0)
	r.target = Vector3(0.0, 0.0, 0.0)
	r.pan_pixels(Vector2(100.0, 0.0), 720.0)
	# Finger moved right: the target moves left on screen (against screen-right).
	assert_float(r.target.dot(r.screen_right_ground())).is_less(0.0)
	var per_px: float = r.size_m / 720.0
	assert_float(r.target.length()).is_equal_approx(100.0 * per_px, 0.0001)
	r.target = Vector3.ZERO
	r.pan_pixels(Vector2(0.0, 100.0), 720.0)
	# Finger moved down: the target moves up the screen, and a screen row is longer on the ground.
	assert_float(r.target.dot(r.screen_up_ground())).is_greater(0.0)
	assert_float(r.target.length()).is_equal_approx(100.0 * per_px / sin(deg_to_rad(MHIsoRig.PITCH_DEG)), 0.001)


func test_pan_stays_inside_the_bounds() -> void:
	var r: MHIsoRig = MHIsoRig.new()
	r.pan_pixels(Vector2(-100000.0, 100000.0), 720.0)
	assert_float(r.target.x).is_between(r.bounds.position.x, r.bounds.end.x)
	assert_float(r.target.z).is_between(r.bounds.position.y, r.bounds.end.y)
	r.focus_target(Vector3(9999.0, 5.0, -9999.0))
	assert_float(r.target.x).is_equal(r.bounds.end.x)
	assert_float(r.target.z).is_equal(r.bounds.position.y)
	assert_float(r.target.y).is_equal(0.0)


func test_easing_reaches_the_goal_by_the_shortest_way_and_stops() -> void:
	var r: MHIsoRig = MHIsoRig.new()
	r.snap_view(0)
	r.rotate_step(-1) # view 3, yaw 315 from 45: shortest way is -90 degrees
	r.update(0.02)
	assert_float(r.yaw_deg).is_less(45.0)
	var guard: int = 0
	while r.update(0.05) and guard < 200:
		guard += 1
	assert_float(r.yaw_deg).is_equal_approx(315.0, 0.5) # 315 or -45 are the same direction
	assert_int(guard).is_less(200)
	r.zoom_step(1)
	guard = 0
	while r.update(0.05) and guard < 200:
		guard += 1
	assert_float(r.size_m).is_equal(float(MHIsoRig.ZOOM_SIZES[MHIsoRig.DEFAULT_ZOOM - 1]))
