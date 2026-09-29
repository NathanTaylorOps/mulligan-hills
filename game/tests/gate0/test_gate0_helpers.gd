extends GdUnitTestSuite
## Stats, report, panel hit test, anim-cost math. NOT YET RUN.


func test_stats_summary_basic() -> void:
	var s: MHGate0Stats = MHGate0Stats.new(100)
	for i: int in range(100):
		s.add(10.0)
	var d: Dictionary = s.summary()
	assert_int(int(d["frames"])).is_equal(100)
	assert_float(float(d["avg_ms"])).is_equal_approx(10.0, 0.01)
	assert_float(float(d["avg_fps"])).is_equal_approx(100.0, 0.5)
	assert_float(float(d["max_ms"])).is_equal_approx(10.0, 0.01)
	assert_str(MHGate0Stats.verdict_30fps(d)).is_equal("PASS_30FPS")


func test_stats_percentile_and_over_33() -> void:
	var s: MHGate0Stats = MHGate0Stats.new(100)
	for i: int in range(95):
		s.add(10.0)
	for i: int in range(5):
		s.add(60.0)
	var d: Dictionary = s.summary()
	assert_float(float(d["p95_ms"])).is_equal_approx(10.0, 0.01)
	assert_float(float(d["p99_ms"])).is_equal_approx(60.0, 0.01)
	assert_float(float(d["pct_over_33ms"])).is_equal_approx(5.0, 0.1)


func test_stats_window_rolls_but_totals_keep_counting() -> void:
	var s: MHGate0Stats = MHGate0Stats.new(10)
	for i: int in range(25):
		s.add(float(i))
	assert_int(s.window_count()).is_equal(10)
	assert_int(s.total_frames).is_equal(25)
	# The window holds samples 15..24.
	var d: Dictionary = s.summary()
	assert_float(float(d["max_ms"])).is_equal_approx(24.0, 0.01)
	assert_float(float(d["avg_ms"])).is_equal_approx(19.5, 0.01)


func test_stats_empty_and_reset() -> void:
	var s: MHGate0Stats = MHGate0Stats.new(10)
	assert_str(MHGate0Stats.verdict_30fps(s.summary())).is_equal("NO_DATA")
	s.add(50.0)
	s.reset()
	assert_int(s.window_count()).is_equal(0)
	assert_int(s.total_frames).is_equal(0)


func test_verdict_fails_slow_or_stall() -> void:
	var s: MHGate0Stats = MHGate0Stats.new(100)
	for i: int in range(99):
		s.add(16.0)
	s.add(150.0)
	assert_str(MHGate0Stats.verdict_30fps(s.summary())).is_equal("FAIL_30FPS")


func test_evidence_has_required_fields() -> void:
	var e: Dictionary = MHGate0Report.evidence("05_terrain_android", "pass", {"fps": 41.5}, "abc1234", "4.7.2", {"model": "X"}, "gl_compatibility", "2026-09-29T00:00:00Z")
	for k: String in ["item", "commit_sha", "godot_version", "device", "renderer", "date_utc", "result", "fps"]:
		assert_bool(e.has(k)).is_true()
	assert_str(str(e["commit_sha"])).is_equal("abc1234")
	var text: String = MHGate0Report.to_json(e)
	var back: Variant = JSON.parse_string(text)
	assert_bool(typeof(back) == TYPE_DICTIONARY).is_true()
	assert_str(str((back as Dictionary)["item"])).is_equal("05_terrain_android")


func test_sha_from_build_info_text() -> void:
	assert_str(MHGate0Report.sha_from_build_info_text("{\"sha\": \"deadbee\", \"run_number\": \"5\"}")).is_equal("deadbee")
	assert_str(MHGate0Report.sha_from_build_info_text("not json")).is_equal("dev")
	assert_str(MHGate0Report.sha_from_build_info_text("{\"sha\": \"\"}")).is_equal("dev")


func test_panel_hit_test() -> void:
	var rects: Dictionary = {&"a": Rect2(0, 0, 100, 50), &"b": Rect2(120, 0, 100, 50)}
	assert_str(String(MHGate0Panel.hit_test(rects, Vector2(10, 10)))).is_equal("a")
	assert_str(String(MHGate0Panel.hit_test(rects, Vector2(150, 10)))).is_equal("b")
	assert_str(String(MHGate0Panel.hit_test(rects, Vector2(110, 10)))).is_equal("")


func test_anim_layout_centred_and_counted() -> void:
	var pts: PackedVector3Array = MHGate0AnimCost.layout(20, 5, 2.0)
	assert_int(pts.size()).is_equal(20)
	var sx: float = 0.0
	var sz: float = 0.0
	for p: Vector3 in pts:
		sx += p.x
		sz += p.z
	assert_float(sx).is_equal_approx(0.0, 0.001)
	assert_float(sz).is_equal_approx(0.0, 0.001)
	assert_int(MHGate0AnimCost.layout(0, 5, 2.0).size()).is_equal(0)
	assert_int(MHGate0AnimCost.layout(3, 5, 2.0).size()).is_equal(3)


func test_anim_cost_math() -> void:
	assert_float(MHGate0AnimCost.per_golfer_ms(1.0, 3.0, 20)).is_equal_approx(0.1, 0.0001)
	assert_float(MHGate0AnimCost.per_golfer_ms(3.0, 1.0, 20)).is_equal_approx(0.0, 0.0001)
	assert_float(MHGate0AnimCost.per_golfer_ms(1.0, 3.0, 0)).is_equal_approx(0.0, 0.0001)
	assert_float(MHGate0AnimCost.projected_ms(0.1, 20)).is_equal_approx(2.0, 0.0001)
	assert_str(MHGate0AnimCost.verdict(0.1, 3.0)).is_equal("within budget")
	assert_str(MHGate0AnimCost.verdict(0.2, 3.0)).is_equal("OVER budget")


func test_clip_size_counts_keys() -> void:
	var a: Animation = Animation.new()
	var t: int = a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, NodePath("Skeleton3D:Hips"))
	a.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
	a.rotation_track_insert_key(t, 1.0, Quaternion.IDENTITY)
	var d: Dictionary = MHGate0AnimCost.clip_size(a)
	assert_int(int(d["tracks"])).is_equal(1)
	assert_int(int(d["keys"])).is_equal(2)
