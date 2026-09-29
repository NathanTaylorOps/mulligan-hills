extends GdUnitTestSuite
## Percentile math, user-arg parsing and adaptive scale logic (NOT YET RUN in Godot).


func test_percentile_nearest_rank() -> void:
	var a: PackedFloat32Array = PackedFloat32Array()
	for i in range(1, 101):
		a.append(float(i))
	assert_float(MHBenchStats.percentile_sorted(a, 50.0)).is_equal(50.0)
	assert_float(MHBenchStats.percentile_sorted(a, 95.0)).is_equal(95.0)
	assert_float(MHBenchStats.percentile_sorted(a, 99.0)).is_equal(99.0)
	assert_float(MHBenchStats.percentile_sorted(a, 100.0)).is_equal(100.0)


func test_summarize_steady_30fps_passes() -> void:
	var a: PackedFloat32Array = PackedFloat32Array()
	for i in range(300):
		a.append(33.0)
	var s: Dictionary = MHBenchStats.summarize(a)
	assert_int(int(s["frames"])).is_equal(300)
	assert_float(float(s["avg_fps"])).is_between(30.0, 30.5)
	assert_str(MHBenchStats.verdict(s)).is_equal("PASS_30FPS")


func test_summarize_slow_fails() -> void:
	var a: PackedFloat32Array = PackedFloat32Array()
	for i in range(300):
		a.append(45.0)
	assert_str(MHBenchStats.verdict(MHBenchStats.summarize(a))).is_equal("FAIL_30FPS")


func test_empty_is_no_data() -> void:
	assert_str(MHBenchStats.verdict(MHBenchStats.summarize(PackedFloat32Array()))).is_equal("NO_DATA")


func test_parse_user_args() -> void:
	var d: Dictionary = MHBenchScene.parse_user_args(PackedStringArray(["--tier=low", "--autostart", "--seconds=5", "junk"]))
	assert_str(str(d["tier"])).is_equal("low")
	assert_bool(d.has("autostart")).is_true()
	assert_str(str(d["seconds"])).is_equal("5")
	assert_bool(d.has("junk")).is_false()


func test_adaptive_scale_drops_and_recovers() -> void:
	var s: MHAdaptiveScale = MHAdaptiveScale.new()
	s.configure(MHQuality.get_tier("high"))
	assert_float(s.current).is_equal(1.0)
	for i in range(MHAdaptiveScale.WINDOW_FRAMES):
		s.step(50.0)
	assert_float(s.current).is_less(1.0)
	for i in range(200):
		for j in range(MHAdaptiveScale.WINDOW_FRAMES):
			s.step(50.0)
	assert_float(s.current).is_equal(0.75)
	for i in range(MHAdaptiveScale.WINDOW_FRAMES * MHAdaptiveScale.UP_HOLD_WINDOWS):
		s.step(10.0)
	assert_float(s.current).is_greater(0.75)
