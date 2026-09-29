extends GdUnitTestSuite
## Gate 0 sim helper logic. NOT YET RUN.


func test_embedded_golden_matches_json() -> void:
	var g: Dictionary = MHGolden.load_json("shotsim.json")
	assert_int(MHGolden.i(g["course_seed"])).is_equal(MHGate0Sim.COURSE_SEED)
	assert_int(MHGolden.i(g["base_seed"])).is_equal(MHGate0Sim.BASE_SEED)
	var runs: Array = g["runs"]
	assert_int(runs.size()).is_equal(MHGate0Sim.RUNS.size())
	for i: int in range(runs.size()):
		var jr: Dictionary = runs[i]
		var er: Dictionary = MHGate0Sim.RUNS[i]
		assert_int(MHGolden.i(jr["golfers"])).is_equal(int(er["golfers"]))
		assert_int(MHGolden.i(jr["holes"])).is_equal(int(er["holes"]))
		assert_str(str(jr["hash"])).is_equal(str(er["hash"]))


func test_run_one_smallest_row_passes() -> void:
	var r: Dictionary = MHGate0Sim.run_one(MHGate0Sim.RUNS[0])
	assert_bool(bool(r["pass"])).is_true()
	assert_str(str(r["label"])).is_equal("sim_4x3")


func test_matches_is_case_insensitive_and_rejects_empty() -> void:
	assert_bool(MHGate0Sim.matches("ABCD", "abcd")).is_true()
	assert_bool(MHGate0Sim.matches("", "")).is_false()
	assert_bool(MHGate0Sim.matches("abcd", "abce")).is_false()


func test_all_pass_and_consistency() -> void:
	var row: Dictionary = MHGate0Sim.RUNS[0]
	var good: Dictionary = MHGate0Sim.make_result(row, str(row["hash"]), 10, 1, 1)
	var bad: Dictionary = MHGate0Sim.make_result(row, "0000000000000000", 10, 1, 1)
	assert_bool(MHGate0Sim.all_pass([good])).is_true()
	assert_bool(MHGate0Sim.all_pass([good, bad])).is_false()
	assert_bool(MHGate0Sim.all_pass([])).is_false()
	assert_bool(MHGate0Sim.passes_consistent([[good], [good], [good]])).is_true()
	assert_bool(MHGate0Sim.passes_consistent([[good], [bad]])).is_false()
	assert_bool(MHGate0Sim.passes_consistent([])).is_false()


func test_cost_arithmetic() -> void:
	assert_int(MHGate0Sim.us_per_sim_second(1000000, 500)).is_equal(2000)
	assert_int(MHGate0Sim.us_per_sim_second(1000000, 0)).is_equal(0)
	# 4x at 60 fps advances 4/60 simulated seconds per frame.
	assert_int(MHGate0Sim.per_frame_us(30000, 4, 60)).is_equal(2000)
	assert_int(MHGate0Sim.per_frame_us(30000, 4, 0)).is_equal(0)


func test_cost_verdict_bands() -> void:
	assert_str(MHGate0Sim.cost_verdict(1500)).contains("within main-thread")
	assert_str(MHGate0Sim.cost_verdict(3000)).contains("worker")
	assert_str(MHGate0Sim.cost_verdict(9000)).contains("GDExtension")


func test_format_result_mentions_label_and_verdict() -> void:
	var row: Dictionary = MHGate0Sim.RUNS[0]
	var r: Dictionary = MHGate0Sim.make_result(row, "deadbeef", 5000, 1, 1)
	var t: String = MHGate0Sim.format_result(r)
	assert_str(t).contains("FAIL")
	assert_str(t).contains("sim_4x3")


func test_report_and_evidence() -> void:
	var row: Dictionary = MHGate0Sim.RUNS[0]
	var good: Dictionary = MHGate0Sim.make_result(row, str(row["hash"]), 1000, 1, 1)
	var passes: Array = [[good], [good], [good]]
	assert_str(MHGate0Sim.overall_result(passes)).is_equal("pass")
	assert_str(MHGate0Sim.overall_result([[good]])).is_equal("fail")
	var f: Dictionary = MHGate0Sim.evidence_fields(passes)
	assert_int(int(f["passes_run"])).is_equal(3)
	assert_bool(bool(f["all_match_golden"])).is_true()
	assert_str(str((f["hashes"] as Dictionary)["sim_4x3"])).is_equal(str(row["hash"]))
	assert_str(MHGate0Sim.report_text(passes)).contains("identical across 3 passes: YES")
