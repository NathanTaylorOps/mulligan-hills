extends GdUnitTestSuite
## MHAdaptiveScale decision logic: p95 trigger, floor, hysteresis, flip-flop backoff (NOT YET RUN).

const B: float = 33.3


func _feed_window(s: MHAdaptiveScale, ms: float) -> void:
	for i in range(MHAdaptiveScale.WINDOW_FRAMES):
		s.step(ms)


func test_next_scale_down_on_slow_p95() -> void:
	var r: Dictionary = MHAdaptiveScale.next_scale(1.0, 40.0, B, 0.75, 1.0, 2, 4)
	assert_float(float(r["scale"])).is_equal_approx(0.95, 0.0001)
	assert_int(int(r["dir"])).is_equal(-1)
	assert_int(int(r["calm"])).is_equal(0)


func test_next_scale_never_below_floor() -> void:
	var r: Dictionary = MHAdaptiveScale.next_scale(0.75, 80.0, B, 0.75, 1.0, 0, 4)
	assert_float(float(r["scale"])).is_equal(0.75)
	assert_int(int(r["dir"])).is_equal(0)


func test_next_scale_deadband_holds() -> void:
	# Between 0.80 and 1.05 of budget: no change and calm counter resets.
	var r: Dictionary = MHAdaptiveScale.next_scale(0.9, B * 0.95, B, 0.75, 1.0, 3, 4)
	assert_float(float(r["scale"])).is_equal(0.9)
	assert_int(int(r["calm"])).is_equal(0)
	assert_int(int(r["dir"])).is_equal(0)


func test_next_scale_up_needs_calm_windows() -> void:
	var r: Dictionary = MHAdaptiveScale.next_scale(0.8, 20.0, B, 0.75, 1.0, 2, 4)
	assert_float(float(r["scale"])).is_equal(0.8)
	assert_int(int(r["calm"])).is_equal(3)
	r = MHAdaptiveScale.next_scale(0.8, 20.0, B, 0.75, 1.0, 3, 4)
	assert_float(float(r["scale"])).is_equal_approx(0.85, 0.0001)
	assert_int(int(r["dir"])).is_equal(1)


func test_next_scale_never_above_max() -> void:
	var r: Dictionary = MHAdaptiveScale.next_scale(1.0, 5.0, B, 0.75, 1.0, 10, 4)
	assert_float(float(r["scale"])).is_equal(1.0)
	assert_int(int(r["dir"])).is_equal(0)


func test_high_tier_floor_is_075_and_change_counter() -> void:
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.configure(MHQuality.get_tier("high"))
	for i in range(30):
		_feed_window(s, 50.0)
	assert_float(s.current).is_equal_approx(0.75, 0.0001)
	# 1.00 -> 0.75 in 0.05 steps is 5 changes; further windows at the floor change nothing.
	assert_int(s.changes).is_equal(5)


func test_p95_ignores_single_hitch() -> void:
	# One 200 ms hitch in a window of otherwise fast frames must not lower the scale (p95 is the 29th of 30).
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.configure(MHQuality.get_tier("high"))
	for i in range(MHAdaptiveScale.WINDOW_FRAMES - 1):
		s.step(16.0)
	s.step(200.0)
	assert_float(s.current).is_equal(1.0)
	assert_int(s.changes).is_equal(0)


func test_two_hitches_in_window_trigger_drop() -> void:
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.configure(MHQuality.get_tier("high"))
	for i in range(MHAdaptiveScale.WINDOW_FRAMES - 2):
		s.step(16.0)
	s.step(80.0)
	s.step(80.0)
	assert_float(s.current).is_less(1.0)


func test_recovery_after_calm_windows() -> void:
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.configure(MHQuality.get_tier("high"))
	_feed_window(s, 50.0)
	assert_float(s.current).is_equal_approx(0.95, 0.0001)
	for i in range(MHAdaptiveScale.UP_HOLD_WINDOWS - 1):
		_feed_window(s, 10.0)
	assert_float(s.current).is_equal_approx(0.95, 0.0001)
	_feed_window(s, 10.0)
	assert_float(s.current).is_equal_approx(1.0, 0.0001)


func test_flip_flop_backoff_doubles_calm_requirement() -> void:
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.configure(MHQuality.get_tier("high"))
	_feed_window(s, 50.0)  # down to 0.95
	for i in range(MHAdaptiveScale.UP_HOLD_WINDOWS):
		_feed_window(s, 10.0)  # up to 1.0
	assert_float(s.current).is_equal_approx(1.0, 0.0001)
	assert_int(s.required_calm).is_equal(MHAdaptiveScale.UP_HOLD_WINDOWS)
	_feed_window(s, 50.0)  # immediately slow again: flip
	assert_int(s.required_calm).is_equal(MHAdaptiveScale.UP_HOLD_WINDOWS * 2)


func test_paused_ignores_frames() -> void:
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.configure(MHQuality.get_tier("high"))
	s.paused = true
	for i in range(10):
		_feed_window(s, 200.0)
	assert_float(s.current).is_equal(1.0)
	assert_int(s.changes).is_equal(0)


func test_disabled_ignores_frames() -> void:
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.configure(MHQuality.get_tier("high"))
	s.enabled = false
	_feed_window(s, 200.0)
	assert_float(s.current).is_equal(1.0)


func test_set_target_fps_changes_budget() -> void:
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.set_target_fps(60)
	assert_float(s.target_ms).is_equal_approx(16.6667, 0.001)
