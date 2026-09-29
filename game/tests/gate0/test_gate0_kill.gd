extends GdUnitTestSuite
## Kill log parsing/judging and the save harness (no real kills). NOT YET RUN.

const PRIMARY: String = "user://mh_gate0_test_kill.mhts"
const LOG: String = "user://mh_gate0_test_kill_log.txt"


func _rm(p: String) -> void:
	if FileAccess.file_exists(p):
		var d: DirAccess = DirAccess.open("user://")
		if d != null:
			d.remove(p.get_file())


func before_test() -> void:
	MHGate0TerrainApi.clear_fault()
	for p: String in [PRIMARY, PRIMARY + ".bak", PRIMARY + ".tmp", PRIMARY + ".bak.tmp", LOG]:
		_rm(p)


func after_test() -> void:
	MHGate0TerrainApi.clear_fault()
	for p: String in [PRIMARY, PRIMARY + ".bak", PRIMARY + ".tmp", PRIMARY + ".bak.tmp", LOG]:
		_rm(p)


func test_parse_counts_and_ignores_torn_lines() -> void:
	var text: String = "B 1 10\nD 1 20\nB 2 30\nV OK 1 40\nD 2 5"
	text += "\nB 3 "  # torn final line
	var p: Dictionary = MHGate0KillLog.parse(text)
	assert_int(int(p["last_begun"])).is_equal(2)
	assert_int(int(p["last_done"])).is_equal(1)
	assert_int(int(p["begun"])).is_equal(2)
	assert_int(int(p["verifies"])).is_equal(1)
	assert_int(int(p["torn_lines"])).is_equal(2)


func test_parse_empty() -> void:
	var p: Dictionary = MHGate0KillLog.parse("")
	assert_int(int(p["last_begun"])).is_equal(-1)
	assert_bool(MHGate0KillLog.judge("NONE", -1, p)).is_true()
	assert_bool(MHGate0KillLog.judge("OK", 0, p)).is_false()


func test_judge_ok_accepts_done_or_inflight_only() -> void:
	var p: Dictionary = MHGate0KillLog.parse("B 4 1\nD 4 2\nB 5 3")
	assert_bool(MHGate0KillLog.judge("OK", 4, p)).is_true()
	assert_bool(MHGate0KillLog.judge("OK", 5, p)).is_true()
	assert_bool(MHGate0KillLog.judge("OK", 3, p)).is_false()
	assert_bool(MHGate0KillLog.judge("OK", 6, p)).is_false()


func test_judge_fallback_allows_previous_generation() -> void:
	var p: Dictionary = MHGate0KillLog.parse("B 4 1\nD 4 2\nB 5 3")
	assert_bool(MHGate0KillLog.judge("FALLBACK", 3, p)).is_true()
	assert_bool(MHGate0KillLog.judge("FALLBACK", 2, p)).is_false()


func test_judge_corrupt_never_ok() -> void:
	var p: Dictionary = MHGate0KillLog.parse("B 1 1\nD 1 2")
	assert_bool(MHGate0KillLog.judge("CORRUPT", -1, p)).is_false()


func test_judge_none_after_saves_began_is_a_fail() -> void:
	var p: Dictionary = MHGate0KillLog.parse("B 1 1")
	assert_bool(MHGate0KillLog.judge("NONE", -1, p)).is_false()


func test_stamp_round_trip_and_tear_detection() -> void:
	var e: MHTerrainEditor = MHGate0TerrainApi.make_editor(16, 16)
	MHGate0SaveHarness.stamp(e, 123)
	assert_int(MHGate0SaveHarness.read_stamp(e.grid)).is_equal(123)
	MHGate0TerrainApi.set_height(e.grid, 1, 0, 5)
	assert_int(MHGate0SaveHarness.read_stamp(e.grid)).is_equal(-1)


func test_save_then_verify_ok() -> void:
	var h: MHGate0SaveHarness = MHGate0SaveHarness.new(PRIMARY, LOG, 32, 32)
	var v0: Dictionary = h.verify()
	assert_str(str(v0["outcome"])).is_equal("NONE")
	assert_int(h.save_generation(1)).is_equal(OK)
	assert_int(h.save_generation(2)).is_equal(OK)
	var v: Dictionary = h.verify()
	assert_str(str(v["outcome"])).is_equal("OK")
	assert_int(int(v["gen"])).is_equal(2)
	assert_bool(bool(v["judged_ok"])).is_true()
	assert_bool(FileAccess.file_exists(PRIMARY + ".bak")).is_true()
	assert_int(h.next_generation()).is_equal(3)


func test_corrupt_primary_falls_back_to_backup() -> void:
	var h: MHGate0SaveHarness = MHGate0SaveHarness.new(PRIMARY, LOG, 32, 32)
	assert_int(h.save_generation(1)).is_equal(OK)
	assert_int(h.save_generation(2)).is_equal(OK)
	var f: FileAccess = FileAccess.open(PRIMARY, FileAccess.WRITE)
	f.store_buffer(PackedByteArray([1, 2, 3, 4, 5]))
	f.close()
	var v: Dictionary = h.verify()
	assert_str(str(v["outcome"])).is_equal("FALLBACK")
	assert_int(int(v["gen"])).is_equal(1)
	assert_bool(bool(v["judged_ok"])).is_true()


func test_both_corrupt_is_corrupt() -> void:
	var h: MHGate0SaveHarness = MHGate0SaveHarness.new(PRIMARY, LOG, 32, 32)
	assert_int(h.save_generation(1)).is_equal(OK)
	for p: String in [PRIMARY, PRIMARY + ".bak"]:
		var f: FileAccess = FileAccess.open(p, FileAccess.WRITE)
		f.store_buffer(PackedByteArray([9, 9, 9]))
		f.close()
	var v: Dictionary = h.verify()
	assert_str(str(v["outcome"])).is_equal("CORRUPT")
	assert_bool(bool(v["judged_ok"])).is_false()


func test_interrupted_write_leaves_previous_generation() -> void:
	# Fault injection with RETURN_ERROR (no kill): a failed mid-write save must leave generation 1 loadable.
	var h: MHGate0SaveHarness = MHGate0SaveHarness.new(PRIMARY, LOG, 32, 32)
	assert_int(h.save_generation(1)).is_equal(OK)
	h.fault_mode = 1
	h.fault_kill = false
	h.fault_target = "primary"
	assert_bool(h.save_generation(2) != OK).is_true()
	h.fault_mode = 0
	var v: Dictionary = h.verify()
	assert_str(str(v["outcome"])).is_equal("OK")
	assert_int(int(v["gen"])).is_equal(1)
	assert_bool(bool(v["judged_ok"])).is_true()


func test_interrupted_after_write_before_rename_keeps_old_primary() -> void:
	var h: MHGate0SaveHarness = MHGate0SaveHarness.new(PRIMARY, LOG, 32, 32)
	assert_int(h.save_generation(1)).is_equal(OK)
	h.fault_mode = 2
	h.fault_kill = false
	h.fault_target = "primary"
	assert_bool(h.save_generation(2) != OK).is_true()
	h.fault_mode = 0
	var v: Dictionary = h.verify()
	assert_str(str(v["outcome"])).is_equal("OK")
	assert_int(int(v["gen"])).is_equal(1)
	assert_bool(bool(v["stale_tmp"])).is_true()
	assert_bool(FileAccess.file_exists(PRIMARY + ".tmp")).is_false()
