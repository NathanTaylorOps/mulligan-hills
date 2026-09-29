extends GdUnitTestSuite
## State machine, tracker and bridge tests using synthetic events. NOT YET RUN.

const H = preload("res://tests/input/input_test_helpers.gd")

var _m: MHGestureStateMachine
var _r: MHInputTestHelpers.Recorder


func before_test() -> void:
	_m = MHGestureStateMachine.new(MHGestureConfig.new())
	_r = MHInputTestHelpers.Recorder.new(_m)


func test_single_finger_paint() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.PENDING)
	_m.tick(100)  # commit window (80 ms) expired
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.PAINTING)
	assert_array(_r.started_positions).contains_exactly([Vector2(100, 100)])
	_m.handle_event(H.drag(0, Vector2(120, 100)), 120)
	_m.handle_event(H.drag(0, Vector2(140, 100)), 140)
	_m.handle_event(H.touch(0, Vector2(140, 100), false), 160)
	assert_int(_r.count("started")).is_equal(1)
	assert_int(_r.count("moved")).is_equal(2)
	assert_int(_r.count("ended")).is_equal(1)
	assert_int(_r.count("cancelled")).is_equal(0)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IDLE)


func test_fast_drag_beyond_dead_zone_starts_stroke_before_window() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.handle_event(H.drag(0, Vector2(150, 100)), 20)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.PAINTING)
	assert_int(_r.count("started")).is_equal(1)
	assert_array(_r.started_positions).contains_exactly([Vector2(100, 100)])
	assert_array(_r.moved_positions).contains_exactly([Vector2(150, 100)])


func test_quick_tap_paints_one_dab() -> void:
	_m.handle_event(H.touch(0, Vector2(50, 50), true), 0)
	_m.handle_event(H.touch(0, Vector2(50, 50), false), 40)
	assert_array(_r.log).contains_exactly(["started", "ended"])
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IDLE)


func test_second_finger_cancels_open_stroke() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.handle_event(H.drag(0, Vector2(160, 100)), 20)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.PAINTING)
	_m.handle_event(H.touch(1, Vector2(300, 300), true), 200)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.CAMERA)
	assert_int(_r.count("cancelled")).is_equal(1)
	assert_int(_r.count("ended")).is_equal(0)
	# Further drags of finger 0 must not paint.
	_m.handle_event(H.drag(0, Vector2(200, 100)), 220)
	assert_int(_r.count("moved")).is_equal(1)  # only the one before the cancel


func test_late_second_finger_within_window_is_camera_intent() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.handle_event(H.drag(0, Vector2(103, 102)), 20)  # jitter inside dead zone
	_m.handle_event(H.touch(1, Vector2(300, 300), true), 60)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.CAMERA)
	assert_int(_r.count("started")).is_equal(0)
	assert_int(_r.count("cancelled")).is_equal(0)
	_m.tick(500)
	assert_int(_r.count("started")).is_equal(0)


func test_second_finger_after_window_cancels_rather_than_prevents() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.handle_event(H.touch(1, Vector2(300, 300), true), 150)
	assert_int(_r.count("started")).is_equal(1)
	assert_int(_r.count("cancelled")).is_equal(1)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.CAMERA)


func test_no_paint_resume_after_second_finger_lifts() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.tick(100)
	_m.handle_event(H.touch(1, Vector2(300, 300), true), 200)
	_m.handle_event(H.touch(1, Vector2(300, 300), false), 300)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.CAMERA)
	_m.handle_event(H.drag(0, Vector2(400, 400)), 320)
	_m.tick(2000)
	assert_int(_r.count("started")).is_equal(1)  # only the original, now cancelled
	assert_int(_r.count("moved")).is_equal(0)
	_m.handle_event(H.touch(0, Vector2(400, 400), false), 400)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IDLE)
	# After all fingers lift, painting works again.
	_m.handle_event(H.touch(2, Vector2(10, 10), true), 500)
	_m.tick(600)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.PAINTING)


func test_camera_can_resume_with_new_second_finger_but_never_paints() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.handle_event(H.touch(1, Vector2(300, 100), true), 30)
	_m.handle_event(H.touch(1, Vector2(300, 100), false), 100)
	_m.handle_event(H.touch(2, Vector2(300, 100), true), 200)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.CAMERA)
	_m.handle_event(H.drag(2, Vector2(300, 150)), 220)
	assert_int(_r.camera_events).is_equal(1)
	assert_int(_r.count("started")).is_equal(0)


func test_three_fingers_ignored() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.handle_event(H.touch(1, Vector2(200, 100), true), 10)
	_m.handle_event(H.touch(2, Vector2(300, 100), true), 20)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IGNORED)
	_m.handle_event(H.drag(0, Vector2(150, 200)), 40)
	_m.handle_event(H.drag(1, Vector2(250, 200)), 41)
	assert_int(_r.camera_events).is_equal(0)
	assert_int(_r.count("started")).is_equal(0)
	# Lifting one finger must not revive camera or paint.
	_m.handle_event(H.touch(2, Vector2(300, 100), false), 60)
	_m.handle_event(H.drag(0, Vector2(160, 210)), 70)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IGNORED)
	assert_int(_r.camera_events).is_equal(0)
	_m.handle_event(H.touch(0, Vector2(160, 210), false), 80)
	_m.handle_event(H.touch(1, Vector2(250, 200), false), 90)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IDLE)


func test_third_finger_after_cancel_keeps_single_cancel() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.tick(100)
	_m.handle_event(H.touch(1, Vector2(200, 100), true), 200)
	_m.handle_event(H.touch(2, Vector2(300, 100), true), 210)
	assert_int(_r.count("cancelled")).is_equal(1)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IGNORED)


func test_two_finger_twist_emits_camera_gesture() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 200), true), 0)
	_m.handle_event(H.touch(1, Vector2(300, 200), true), 10)
	# Rotate a quarter turn clockwise about (200,200) in a few steps.
	var steps: int = 9
	for i in range(1, steps + 1):
		var a: float = (PI / 2.0) * float(i) / float(steps)
		var off: Vector2 = Vector2.from_angle(a) * 100.0
		_m.handle_event(H.drag(0, Vector2(200, 200) - off), 20 + i * 10)
		_m.handle_event(H.drag(1, Vector2(200, 200) + off), 20 + i * 10)
	assert_float(_r.twist_sum).is_equal_approx(PI / 2.0, 0.001)
	assert_int(_r.count("started")).is_equal(0)


func test_edge_rejection() -> void:
	_m.tracker.screen_size = Vector2(1000, 600)
	_m.tracker.edge_margin_px = 20.0
	_m.handle_event(H.touch(0, Vector2(5, 300), true), 0)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IDLE)
	assert_int(_m.tracker.count()).is_equal(0)
	_m.handle_event(H.touch(0, Vector2(5, 300), false), 10)  # release of rejected touch is harmless
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IDLE)


func test_palm_filter_hook() -> void:
	_m.tracker.reject_filter = func(pos: Vector2, _index: int, _active: int) -> bool:
		return pos.y < 500.0  # reject anything in the bottom area
	_m.handle_event(H.touch(0, Vector2(100, 550), true), 0)
	assert_int(_m.tracker.count()).is_equal(0)
	_m.handle_event(H.touch(1, Vector2(100, 100), true), 5)
	assert_int(_m.tracker.count()).is_equal(1)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.PENDING)


func test_long_press_mode() -> void:
	var cfg: MHGestureConfig = MHGestureConfig.new()
	cfg.long_press_ms = 300
	var m: MHGestureStateMachine = MHGestureStateMachine.new(cfg)
	var r: MHInputTestHelpers.Recorder = MHInputTestHelpers.Recorder.new(m)
	# Move before the hold: inert until lift.
	m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	m.handle_event(H.drag(0, Vector2(200, 100)), 50)
	m.tick(1000)
	assert_int(m.state).is_equal(MHGestureStateMachine.State.IGNORED)
	assert_int(r.count("started")).is_equal(0)
	m.handle_event(H.touch(0, Vector2(200, 100), false), 1100)
	# Hold still: paints after 300 ms.
	m.handle_event(H.touch(0, Vector2(100, 100), true), 2000)
	m.tick(2200)
	assert_int(r.count("started")).is_equal(0)
	m.tick(2300)
	assert_int(r.count("started")).is_equal(1)


func test_canceled_touch_event_rolls_back() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.tick(100)
	_m.handle_event(H.touch(0, Vector2(100, 100), false, true), 150)
	assert_int(_r.count("cancelled")).is_equal(1)
	assert_int(_r.count("ended")).is_equal(0)


func test_cancel_all_on_focus_loss() -> void:
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.tick(100)
	_m.cancel_all()
	assert_int(_r.count("cancelled")).is_equal(1)
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IDLE)
	assert_int(_m.tracker.count()).is_equal(0)


func test_desktop_left_drag_paints() -> void:
	_m.desktop_stroke_begin(Vector2(10, 10))
	_m.desktop_stroke_move(Vector2(20, 20))
	_m.desktop_stroke_end()
	assert_array(_r.log).contains_exactly(["started", "moved", "ended"])
	assert_int(_m.state).is_equal(MHGestureStateMachine.State.IDLE)


func test_tracker_ignores_drag_for_unknown_index() -> void:
	var t: MHTouchTracker = MHTouchTracker.new()
	var res: int = t.handle_event(H.drag(7, Vector2(1, 1)), 0)
	assert_int(res).is_equal(MHTouchTracker.Result.IGNORED)
	assert_int(t.count()).is_equal(0)


func test_tracker_ids_sorted() -> void:
	var t: MHTouchTracker = MHTouchTracker.new()
	t.handle_event(H.touch(3, Vector2(1, 1), true), 0)
	t.handle_event(H.touch(1, Vector2(2, 2), true), 0)
	assert_array(t.ids()).contains_exactly([1, 3])


func test_bridge_forwards_to_sink_and_rolls_back() -> void:
	var sink: MHMockStrokeSink = MHMockStrokeSink.new()
	var conv: Callable = func(p: Vector2) -> Vector2i:
		return Vector2i(int(p.x / 10.0), int(p.y / 10.0))
	var bridge: MHStrokeBridge = MHStrokeBridge.new(sink, conv, _m)
	_m.handle_event(H.touch(0, Vector2(100, 100), true), 0)
	_m.handle_event(H.drag(0, Vector2(150, 100)), 20)
	_m.handle_event(H.touch(1, Vector2(400, 400), true), 100)
	assert_array(sink.calls).contains_exactly(["begin", "apply(10,10)", "apply(15,10)", "cancel"])
	assert_object(bridge).is_not_null()


func test_bridge_normal_stroke_and_no_cell() -> void:
	var sink: MHMockStrokeSink = MHMockStrokeSink.new()
	var conv: Callable = func(p: Vector2) -> Vector2i:
		if p.x < 0.0:
			return MHStrokeBridge.NO_CELL
		return Vector2i(int(p.x / 10.0), int(p.y / 10.0))
	var bridge: MHStrokeBridge = MHStrokeBridge.new(sink, conv, _m)
	_m.desktop_stroke_begin(Vector2(-5, 0))
	_m.desktop_stroke_move(Vector2(30, 40))
	_m.desktop_stroke_end()
	assert_array(sink.calls).contains_exactly(["begin", "apply(3,4)", "end"])
	assert_object(bridge).is_not_null()
