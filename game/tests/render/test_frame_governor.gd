extends GdUnitTestSuite
## Pure decision logic of MHFrameGovernor and the cap setting helpers (NOT YET RUN in Godot).
## These tests never call apply(), so Engine.max_fps and OS.low_processor_usage_mode are untouched.


func test_normalize_setting() -> void:
	assert_str(MHFrameGovernor.normalize_setting("30")).is_equal("30")
	assert_str(MHFrameGovernor.normalize_setting(" 60 ")).is_equal("60")
	assert_str(MHFrameGovernor.normalize_setting("AUTO")).is_equal("auto")
	assert_str(MHFrameGovernor.normalize_setting("120")).is_equal("auto")
	assert_str(MHFrameGovernor.normalize_setting("")).is_equal("auto")


func test_resolve_cap_fixed() -> void:
	assert_int(MHFrameGovernor.resolve_cap("30", "high")).is_equal(30)
	assert_int(MHFrameGovernor.resolve_cap("60", "low")).is_equal(60)


func test_resolve_cap_auto_by_tier() -> void:
	assert_int(MHFrameGovernor.resolve_cap("auto", "low")).is_equal(30)
	assert_int(MHFrameGovernor.resolve_cap("auto", "medium")).is_equal(30)
	assert_int(MHFrameGovernor.resolve_cap("auto", "high")).is_equal(60)
	assert_int(MHFrameGovernor.resolve_cap("auto", "bogus")).is_equal(30)


func test_decide_active_within_hold() -> void:
	var d: Dictionary = MHFrameGovernor.decide(60, 0, 2000, 15, false)
	assert_str(str(d["mode"])).is_equal("active")
	assert_int(int(d["target_fps"])).is_equal(60)
	assert_bool(bool(d["low_processor"])).is_false()
	var d2: Dictionary = MHFrameGovernor.decide(60, 1999, 2000, 15, false)
	assert_str(str(d2["mode"])).is_equal("active")


func test_decide_idle_after_hold() -> void:
	var d: Dictionary = MHFrameGovernor.decide(60, 2000, 2000, 15, false)
	assert_str(str(d["mode"])).is_equal("idle")
	assert_int(int(d["target_fps"])).is_equal(15)
	assert_bool(bool(d["low_processor"])).is_true()


func test_decide_ambient_blocks_low_processor() -> void:
	var d: Dictionary = MHFrameGovernor.decide(30, 5000, 2000, 15, true)
	assert_str(str(d["mode"])).is_equal("idle")
	assert_bool(bool(d["low_processor"])).is_false()


func test_decide_idle_fps_never_above_cap() -> void:
	var d: Dictionary = MHFrameGovernor.decide(10, 5000, 2000, 15, false)
	assert_int(int(d["target_fps"])).is_equal(10)
	var d0: Dictionary = MHFrameGovernor.decide(0, 0, 2000, 15, false)
	assert_int(int(d0["target_fps"])).is_equal(1)


func test_update_sequence_active_then_idle_then_wake() -> void:
	var g: MHFrameGovernor = MHFrameGovernor.new()
	g.set_setting("60")
	var d: Dictionary = g.update(1000, false, false, true, false)
	assert_str(str(d["mode"])).is_equal("active")
	assert_int(g.target_fps).is_equal(60)
	# Animation stops at t=1000; still inside the hold at t=2500.
	d = g.update(2500, false, false, false, false)
	assert_str(str(d["mode"])).is_equal("active")
	d = g.update(3000, false, false, false, false)
	assert_str(str(d["mode"])).is_equal("idle")
	assert_int(g.target_fps).is_equal(15)
	assert_int(g.transitions).is_equal(1)
	# Camera motion wakes it at once.
	d = g.update(3100, false, true, false, false)
	assert_str(str(d["mode"])).is_equal("active")
	assert_int(g.target_fps).is_equal(60)
	assert_int(g.transitions).is_equal(2)


func test_update_input_alone_keeps_active() -> void:
	var g: MHFrameGovernor = MHFrameGovernor.new()
	g.update(0, true, false, false, false)
	var d: Dictionary = g.update(1500, false, false, false, false)
	assert_str(str(d["mode"])).is_equal("active")
	d = g.update(2001, false, false, false, false)
	assert_str(str(d["mode"])).is_equal("idle")


func test_note_input_resets_hold() -> void:
	var g: MHFrameGovernor = MHFrameGovernor.new()
	g.update(0, true, false, false, false)
	g.note_input(5000)
	var d: Dictionary = g.update(6000, false, false, false, false)
	assert_str(str(d["mode"])).is_equal("active")


func test_disabled_returns_disabled_and_zero_fps() -> void:
	var g: MHFrameGovernor = MHFrameGovernor.new()
	g.enabled = false
	var d: Dictionary = g.update(10000, false, false, false, false)
	assert_str(str(d["mode"])).is_equal("disabled")
	assert_int(int(d["target_fps"])).is_equal(0)


func test_idle_pct_accounting() -> void:
	var g: MHFrameGovernor = MHFrameGovernor.new()
	g.hold_ms = 1000
	g.update(0, true, false, false, false)
	g.update(1000, false, false, false, false)  # idle starts here (since_activity = 1000)
	g.update(2000, false, false, false, false)
	g.update(3000, false, false, false, false)
	# dt 1000 active-classified at t=1000? mode at 1000 is idle, so idle = 1000 + 1000 + 1000.
	assert_int(g.idle_ms_total).is_equal(3000)
	assert_float(g.idle_pct()).is_equal(100.0)


func test_cap_setting_cycle() -> void:
	assert_str(MHFrameCapSetting.next("30")).is_equal("60")
	assert_str(MHFrameCapSetting.next("60")).is_equal("auto")
	assert_str(MHFrameCapSetting.next("auto")).is_equal("30")
	assert_str(MHFrameCapSetting.next("junk")).is_equal("30")


func test_cap_setting_options_ids_are_valid() -> void:
	for o in MHFrameCapSetting.options():
		var od: Dictionary = o
		assert_bool(MHFrameGovernor.SETTINGS.has(str(od["id"]))).is_true()
