extends GdUnitTestSuite
## Asserts hole generation, single-hole simulation and the N x M sim hash equal the Python reference
## (golden/shotsim.json). The 60 golfers x 18 holes case is the cross-platform determinism proof.

var _g: Dictionary


func before() -> void:
	_g = MHGolden.load_json("shotsim.json")


func test_hole_generation() -> void:
	var seed_v: int = MHGolden.i(_g["course_seed"])
	for row in _g["holes"]:
		var h: MHHole = MHShotSim.make_hole(seed_v, MHGolden.i(row["index"]))
		assert_int(h.par).is_equal(MHGolden.i(row["par"]))
		assert_int(h.w).is_equal(MHGolden.i(row["w"]))
		assert_int(h.h).is_equal(MHGolden.i(row["h"]))
		assert_int(h.tee_x).is_equal(MHGolden.i(row["tee_x"]))
		assert_int(h.tee_y).is_equal(MHGolden.i(row["tee_y"]))
		assert_int(h.pin_x).is_equal(MHGolden.i(row["pin_x"]))
		assert_int(h.pin_y).is_equal(MHGolden.i(row["pin_y"]))
		assert_str(h.lie_hash_hex()).is_equal(row["lie_hash"])


func test_single_hole_sims() -> void:
	var seed_v: int = MHGolden.i(_g["course_seed"])
	for row in _g["sims"]:
		var h: MHHole = MHShotSim.make_hole(seed_v, MHGolden.i(row["hole"]))
		var rng: MHRng = MHRng.new(MHGolden.i(row["seed"]), MHGolden.i(row["stream"]))
		var res: Dictionary = MHShotSim.simulate_hole(h, MHGolden.i(row["skill"]), MHGolden.i(row["wind_x"]), MHGolden.i(row["wind_y"]), rng, true)
		assert_int(res["strokes"]).is_equal(MHGolden.i(row["strokes"]))
		assert_int(res["holed"]).is_equal(MHGolden.i(row["holed"]))
		assert_int(res["time"]).is_equal(MHGolden.i(row["time"]))
		var trace: PackedInt64Array = res["trace"]
		assert_int(trace.size()).is_equal(MHGolden.i(row["trace_len"]))
		assert_str(MHShotSim.trace_hash_hex(trace)).is_equal(row["trace_hash"])
		if row["trace"] != null:
			for k in range(trace.size()):
				assert_int(trace[k]).is_equal(MHGolden.i(row["trace"][k]))


func test_sim_hash_runs() -> void:
	var seed_v: int = MHGolden.i(_g["course_seed"])
	var base_v: int = MHGolden.i(_g["base_seed"])
	for row in _g["runs"]:
		var res: Dictionary = MHSimHash.run(seed_v, base_v, MHGolden.i(row["golfers"]), MHGolden.i(row["holes"]), true)
		assert_str(res["hash"]).is_equal(row["hash"])
		assert_int(res["total_strokes"]).is_equal(MHGolden.i(row["total_strokes"]))
		assert_int(res["max_time"]).is_equal(MHGolden.i(row["max_time"]))


func test_trace_flag_does_not_change_results() -> void:
	var seed_v: int = MHGolden.i(_g["course_seed"])
	var base_v: int = MHGolden.i(_g["base_seed"])
	var a: Dictionary = MHSimHash.run(seed_v, base_v, 10, 18, true)
	var b: Dictionary = MHSimHash.run(seed_v, base_v, 10, 18, false)
	assert_int(a["total_strokes"]).is_equal(b["total_strokes"])
	assert_int(a["max_time"]).is_equal(b["max_time"])
