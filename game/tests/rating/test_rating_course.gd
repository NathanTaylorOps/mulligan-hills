extends GdUnitTestSuite
## Course roll-up, duplicate descriptor, tier gates, tournament formulas, advisor triggers and tie-break order.
## Roll-up tests feed the reference hole scores in (no simulation), so they run fast.

var _g: Dictionary


func before() -> void:
	_g = MHRatingGolden.load_all()
	assert_bool(MHRParams.ensure_loaded()).is_true()


func _arrays_equal(got: Array, want: Array) -> void:
	assert_int(got.size()).is_equal(want.size())
	for k in range(want.size()):
		assert_int(MHRatingGolden.i(got[k])).is_equal(MHRatingGolden.i(want[k]))


func _rollup(c: Dictionary) -> Dictionary:
	var holes: Array = []
	for d in c["holes"]:
		holes.append(MHRHole.from_def(d as Dictionary))
	var results: Array = []
	for s in c["results"]:
		results.append({"valid": bool(s["valid"]), "score_pm": MHRatingGolden.i(s["score_pm"]), "par": MHRatingGolden.i(s["par"]), "pace_pm": MHRatingGolden.i(s["pace_pm"])})
	return MHRatingEngine.rollup_course(holes, results)


func test_rollups_match_reference() -> void:
	for c in _g["courses"]:
		var ro: Dictionary = _rollup(c)
		assert_int(ro["course_x10"]).is_equal(MHRatingGolden.i(c["course_x10"]))
		assert_int(ro["mean"]).is_equal(MHRatingGolden.i(c["mean"]))
		assert_int(ro["low_third"]).is_equal(MHRatingGolden.i(c["low_third"]))
		assert_int(ro["n_dup"]).is_equal(MHRatingGolden.i(c["n_dup"]))
		assert_int(ro["tier"]).is_equal(MHRatingGolden.i(c["tier"]))
		assert_int(ro["valid_non_dead"]).is_equal(MHRatingGolden.i(c["valid_non_dead"]))
		_arrays_equal(ro["factors"] as Array, c["factors"] as Array)
		_arrays_equal(ro["adj"] as Array, c["adj"] as Array)


func test_rollup_codes_match_reference() -> void:
	for c in _g["courses"]:
		var ro: Dictionary = _rollup(c)
		var codes: Dictionary = ro["codes"]
		var want_course: Array = c["codes_course"]
		var got_course: Array = codes["course"]
		assert_int(got_course.size()).is_equal(want_course.size())
		for k in range(want_course.size()):
			assert_str(String(got_course[k])).is_equal(String(want_course[k]))
		var want_ph: Array = c["codes_per_hole"]
		var got_ph: Array = codes["per_hole"]
		assert_int(got_ph.size()).is_equal(want_ph.size())
		for k in range(want_ph.size()):
			assert_str(String(got_ph[k][0])).is_equal(String(want_ph[k][0]))
			assert_int(int(got_ph[k][1])).is_equal(MHRatingGolden.i(want_ph[k][1]))


func test_descriptor_hashes() -> void:
	for c in _g["courses"]:
		var want: Array = c["descriptor_hash"]
		var n: int = 0
		for d in c["holes"]:
			var h: MHRHole = MHRHole.from_def(d as Dictionary)
			if not h.valid:
				continue
			var desc: PackedInt32Array = MHRCourse.descriptor(h)
			assert_int(desc.size()).is_equal(72)
			var buf: PackedByteArray = PackedByteArray()
			for v in desc:
				MHRMath.push_i32(buf, v)
			assert_str(MHRMath.hash64(buf)).is_equal(String(want[n]))
			n += 1
		assert_int(n).is_equal(want.size())


func test_mirror_copy_is_detected() -> void:
	var m: Dictionary = _g["mirror"]
	var a: MHRHole = MHRHole.from_def(m["orig"] as Dictionary)
	var b: MHRHole = MHRHole.from_def(m["mirror"] as Dictionary)
	var s: int = MHRCourse.similarity(a, MHRCourse.descriptor(a), b, MHRCourse.descriptor(b))
	assert_int(s).is_equal(MHRatingGolden.i(m["S"]))
	assert_int(MHRCourse.dup_factor(1000)).is_equal(400)
	assert_int(MHRCourse.dup_factor(700)).is_equal(1000)
	assert_int(MHRCourse.dup_factor(850)).is_equal(700)


func test_tier_gates_and_dead_hole_counting() -> void:
	assert_int(MHRParams.score_gates[0]).is_equal(320)
	assert_int(MHRParams.score_gates[1]).is_equal(420)
	assert_int(MHRParams.score_gates[2]).is_equal(520)
	assert_int(MHRParams.score_gates[3]).is_equal(620)
	assert_int(MHRCourse.tier_reached(6, 320)).is_equal(2)
	assert_int(MHRCourse.tier_reached(5, 900)).is_equal(1)     # not enough holes
	assert_int(MHRCourse.tier_reached(18, 619)).is_equal(4)    # score just under the tier 5 gate
	assert_int(MHRCourse.tier_reached(18, 620)).is_equal(5)
	assert_int(MHRCourse.tier_reached(18, 319)).is_equal(1)
	# 18 holes of which 8 are dead (score 249 permille): only 10 count toward the hole gate
	var holes: Array = []
	var results: Array = []
	var def: Dictionary = {"slot_id": 1, "tee": [0, 0], "green": [0, 400, 14], "features": []}
	for i in range(18):
		holes.append(MHRHole.from_def(def))
		var s: int = 700 if i < 10 else 249
		results.append({"valid": true, "score_pm": s, "par": 3 + (i % 3), "pace_pm": 1000})
	var ro: Dictionary = MHRatingEngine.rollup_course(holes, results)
	assert_int(ro["valid_non_dead"]).is_equal(10)
	assert_int(ro["n"]).is_equal(18)


func test_empty_course_is_safe() -> void:
	var ro: Dictionary = MHRatingEngine.rollup_course([], [])
	assert_int(ro["course_x10"]).is_equal(0)


func test_sustained_and_prestige() -> void:
	for row in _g["tournament"]["sustained"]:
		assert_int(MHRTournament.sustained(row[0] as Array)).is_equal(MHRatingGolden.i(row[1]))
	for row in _g["tournament"]["prestige"]:
		var p: int = MHRTournament.prestige(MHRatingGolden.i(row[0]), MHRatingGolden.i(row[1]), MHRatingGolden.i(row[2]), MHRatingGolden.i(row[3]), MHRatingGolden.i(row[4]))
		assert_int(p).is_equal(MHRatingGolden.i(row[5]))
	for row in _g["tournament"]["facility"]:
		assert_int(MHRTournament.facility_points(row[0] as Array)).is_equal(MHRatingGolden.i(row[1]))


func test_tournament_and_misc_codes() -> void:
	for row in _g["tournament"]["codes"]:
		var a: Array = row["args"]
		var got: Array = MHRTournament.tournament_codes(MHRatingGolden.i(a[0]), MHRatingGolden.i(a[1]), bool(a[2]), bool(a[3]), MHRatingGolden.i(a[4]), MHRatingGolden.i(a[5]))
		var want: Array = row["codes"]
		assert_int(got.size()).is_equal(want.size())
		for k in range(want.size()):
			assert_str(String(got[k])).is_equal(String(want[k]))
	for row in _g["tournament"]["wind"]:
		var w: Array = MHRTournament.wind_codes(MHRatingGolden.i(row[0]), MHRatingGolden.i(row[1]))
		assert_int(w.size()).is_equal((row[2] as Array).size())
	var st: Array = _g["tournament"]["stale"]
	assert_int(MHRTournament.stale_codes(String(st[0])).size()).is_equal((st[1] as Array).size())
	assert_int(MHRTournament.stale_codes(MHRParams.ENGINE_VERSION).size()).is_equal(0)
	var nr: Dictionary = _g["tournament"]["near"]
	var hit: Array = MHRTournament.near_holes(nr["origins"] as Array, nr["tg"] as Array)
	_arrays_equal(hit, nr["hit"] as Array)


func test_rank_tie_break() -> void:
	var r: Dictionary = _g["rank"]
	var got: Array = MHRTournament.rank(r["entries"] as Array)
	var want: Array = r["order"]
	assert_int(got.size()).is_equal(want.size())
	for k in range(want.size()):
		assert_str(String(got[k])).is_equal(String(want[k]))
