extends GdUnitTestSuite
## Bit exact hole ratings against the Python reference: sim hash, axes, score, advisor codes.
## Each case simulates 120 golfers (30 for preview) so these are the slow tests; NOT YET RUN in Godot.

var _g: Dictionary


func before() -> void:
	_g = MHRatingGolden.load_all()


func _case(name: String) -> Dictionary:
	for c in _g["sims"]:
		if String(c["name"]) == name:
			return c
	return {}


func _check(name: String) -> void:
	var c: Dictionary = _case(name)
	assert_bool(c.size() > 0).is_true()
	var ctx: Dictionary = {"save_secret": MHRatingGolden.i(c["secret"]), "rating_epoch": MHRatingGolden.i(c["epoch"]),
		"condition": c["cond"], "preview": bool(c["preview"])}
	var r: Dictionary = MHRatingEngine.rate_hole(c["hole"] as Dictionary, ctx)
	assert_bool(bool(r["valid"])).is_equal(bool(c["valid"]))
	assert_str(String(r["hash"])).is_equal(String(c["sim_hash"]))
	var want_reasons: Array = c["reasons"]
	var got_reasons: Array = r["reasons"]
	assert_int(got_reasons.size()).is_equal(want_reasons.size())
	for k in range(want_reasons.size()):
		assert_str(String(got_reasons[k])).is_equal(String(want_reasons[k]))
	if not bool(c["valid"]):
		assert_int(MHRatingGolden.i(r["score_pm"])).is_equal(0)
		return
	assert_int(MHRatingGolden.i(r["hole_seed"])).is_equal(MHRatingGolden.i(c["hole_seed"]))
	assert_str(String(r["content_hash"])).is_equal(String(c["content_hash"]))
	for key in ["score_pm", "score", "A", "I", "Len", "B", "F", "par", "L", "forced_pm", "pickup_pm", "tree_pm", "risk_pm",
			"raw_corr", "comps", "pace_pm", "pace_pen", "spread", "T_par", "inversions", "over", "bend_s", "elev", "Oc", "R",
			"shape", "PQ", "B_raw", "n_tree", "raw_trees", "wat", "cats", "golfers"]:
		assert_int(MHRatingGolden.i(r[key])).is_equal(MHRatingGolden.i(c[key]))
	assert_bool(bool(r["stacked"])).is_equal(bool(c["stacked"]))
	assert_bool(bool(r["dead"])).is_equal(bool(c["dead"]))
	var means_got: Array = r["means"]
	var means_want: Array = c["means"]
	for k in range(6):
		assert_int(MHRatingGolden.i(means_got[k])).is_equal(MHRatingGolden.i(means_want[k]))
	var all_got: Array = r["all_reasons"]
	var all_want: Array = c["all_reasons"]
	assert_int(all_got.size()).is_equal(all_want.size())
	for k in range(all_want.size()):
		assert_str(String(all_got[k])).is_equal(String(all_want[k]))


func test_plain_par4() -> void:
	_check("plain_par4")


func test_choice_par4() -> void:
	_check("choice_par4")


func test_forced_water() -> void:
	_check("forced_water")


func test_determinism_base() -> void:
	_check("determinism_base")


func test_tree_spam() -> void:
	_check("tree_spam")


func test_synthetic_par3() -> void:
	_check("synthetic_par3")


func test_synthetic_par5() -> void:
	_check("synthetic_par5")


func test_preview_n30() -> void:
	_check("preview_n30")


func test_headwind() -> void:
	_check("headwind")


func test_rain_epoch3() -> void:
	_check("rain2_epoch3")


func test_unplayable_island() -> void:
	_check("unplayable_island_tee")


func test_records_digest_matches_golden() -> void:
	var c: Dictionary = _case("determinism_base")
	var ctx: Dictionary = {"save_secret": MHRatingGolden.i(c["secret"]), "rating_epoch": MHRatingGolden.i(c["epoch"]), "want_records": true}
	var r: Dictionary = MHRatingEngine.rate_hole(c["hole"] as Dictionary, ctx)
	var rec: Dictionary = r["records"]
	var strokes: PackedInt32Array = rec["strokes"]
	var band: PackedInt32Array = rec["band"]
	var times: PackedInt32Array = rec["time_s"]
	var sums: Array = [0, 0, 0, 0, 0, 0]
	var tsum: Array = [0, 0, 0, 0, 0, 0]
	for g in range(strokes.size()):
		sums[band[g]] = int(sums[band[g]]) + strokes[g]
		tsum[band[g]] = int(tsum[band[g]]) + times[g]
	for b in range(6):
		assert_int(int(sums[b])).is_equal(MHRatingGolden.i(c["band_strokes"][b]))
		assert_int(int(tsum[b])).is_equal(MHRatingGolden.i(c["band_time"][b]))
	var fr: Array = c["first_rec"]
	assert_int((rec["gid"] as PackedInt32Array)[0]).is_equal(MHRatingGolden.i(fr[0]))
	assert_int(strokes[0]).is_equal(MHRatingGolden.i(fr[1]))
	assert_int((rec["flags"] as PackedInt32Array)[0]).is_equal(MHRatingGolden.i(fr[2]))
	assert_int(times[0]).is_equal(MHRatingGolden.i(fr[3]))
	assert_int((rec["fx"] as PackedInt32Array)[0]).is_equal(MHRatingGolden.i(fr[4]))
	assert_int((rec["fy"] as PackedInt32Array)[0]).is_equal(MHRatingGolden.i(fr[5]))


func test_same_input_same_hash_twice() -> void:
	var c: Dictionary = _case("plain_par4")
	var ctx: Dictionary = {"save_secret": MHRatingGolden.i(c["secret"]), "rating_epoch": 1}
	var a: Dictionary = MHRatingEngine.rate_hole(c["hole"] as Dictionary, ctx)
	var b: Dictionary = MHRatingEngine.rate_hole(c["hole"] as Dictionary, ctx)
	assert_str(String(a["hash"])).is_equal(String(b["hash"]))
	assert_int(MHRatingGolden.i(a["score_pm"])).is_equal(MHRatingGolden.i(b["score_pm"]))
