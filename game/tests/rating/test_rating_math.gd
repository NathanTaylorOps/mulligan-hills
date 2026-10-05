extends GdUnitTestSuite
## Integer helpers, hashes, seeds and params against golden/rating_golden.json (fn_vectors).

var _g: Dictionary


func before() -> void:
	_g = MHRatingGolden.load_all()


func test_params_load_and_hash() -> void:
	assert_bool(MHRParams.ensure_loaded()).is_true()
	assert_str(MHRParams.params_hash).is_equal(_g["params_hash"])
	assert_str(MHRParams.ENGINE_VERSION).is_equal(_g["engine"])
	assert_str(MHRParams.SIM_VERSION).is_equal(_g["sim_version"])
	assert_int(MHRParams.z256.size()).is_equal(256)
	assert_int(MHRParams.z256[0]).is_equal(-2886)
	assert_int(MHRParams.z256[255]).is_equal(2886)


func test_division_vectors() -> void:
	var v: Dictionary = _g["fn_vectors"]
	for row in v["rdiv"]:
		assert_int(MHRMath.rdiv(MHRatingGolden.i(row[0]), MHRatingGolden.i(row[1]))).is_equal(MHRatingGolden.i(row[2]))
	for row in v["fdiv"]:
		assert_int(MHRMath.fdiv(MHRatingGolden.i(row[0]), MHRatingGolden.i(row[1]))).is_equal(MHRatingGolden.i(row[2]))
	for row in v["isqrt"]:
		assert_int(MHRMath.isqrt(MHRatingGolden.i(row[0]))).is_equal(MHRatingGolden.i(row[1]))


func test_interp_length_table() -> void:
	assert_bool(MHRParams.ensure_loaded()).is_true()
	for row in _g["fn_vectors"]["interp"]:
		assert_int(MHRMath.interp(MHRParams.length_table, MHRatingGolden.i(row[0]))).is_equal(MHRatingGolden.i(row[1]))


func test_h32_vectors() -> void:
	for row in _g["fn_vectors"]["h32"]:
		var args: Array = MHRatingGolden.ints(row[0])
		assert_int(MHRMath.h32(args)).is_equal(MHRatingGolden.i(row[1]))
	# the fixed-arity versions must agree with the generic one
	assert_int(MHRMath.h32b(0xC0FFEE, 5)).is_equal(MHRMath.h32([0xC0FFEE, 5]))
	assert_int(MHRMath.h32c(1, 2, 3)).is_equal(MHRMath.h32([1, 2, 3]))
	assert_int(MHRMath.h32d(-1, 4294967295, 7, 9)).is_equal(MHRMath.h32([-1, 4294967295, 7, 9]))


func test_hash64_vectors() -> void:
	for row in _g["fn_vectors"]["hash64"]:
		assert_str(MHRMath.hash64(String(row[0]).to_utf8_buffer())).is_equal(row[1])


func test_z256_hash() -> void:
	assert_bool(MHRParams.ensure_loaded()).is_true()
	var buf: PackedByteArray = PackedByteArray()
	for z in MHRParams.z256:
		MHRMath.push_i32(buf, z)
	assert_str(MHRMath.hash64(buf)).is_equal(_g["fn_vectors"]["z256_hash"])


func test_seeds() -> void:
	var v: Dictionary = _g["fn_vectors"]
	for row in v["hole_seed"]:
		assert_int(MHRMath.hole_seed(MHRatingGolden.i(row[0]), MHRatingGolden.i(row[1]), MHRatingGolden.i(row[2]))).is_equal(MHRatingGolden.i(row[3]))
	for row in v["daily_seed"]:
		assert_int(MHRMath.daily_seed(MHRatingGolden.i(row[0]), MHRatingGolden.i(row[1]))).is_equal(MHRatingGolden.i(row[2]))
	for row in v["tournament_seed"]:
		assert_int(MHRMath.tournament_seed(MHRatingGolden.i(row[0]), MHRatingGolden.i(row[1]), MHRatingGolden.i(row[2]))).is_equal(MHRatingGolden.i(row[3]))


func test_tree_rect_expansion() -> void:
	for row in _g["fn_vectors"]["tree_expand"]:
		var pts: PackedInt32Array = MHRHole.expand_tree_rect(row[0] as Array, MHRatingGolden.i(row[1]))
		var want: Array = row[2]
		assert_int(pts.size()).is_equal(want.size() * 2)
		for k in range(want.size()):
			assert_int(pts[k * 2]).is_equal(MHRatingGolden.i(want[k][0]))
			assert_int(pts[k * 2 + 1]).is_equal(MHRatingGolden.i(want[k][1]))


func test_reason_code_table() -> void:
	var table: Array = _g["codes"]["table"]
	assert_int(table.size()).is_equal(66)
	assert_int(MHRAdvisor.SEVERITY.size()).is_equal(66)
	for row in table:
		assert_int(MHRAdvisor.severity(String(row[0]))).is_equal(MHRatingGolden.i(row[1]))
	for row in _g["codes"]["top"]:
		var got: Array = MHRAdvisor.top_codes(row[0] as Array)
		var want: Array = row[1]
		assert_int(got.size()).is_equal(want.size())
		for k in range(want.size()):
			assert_str(String(got[k])).is_equal(String(want[k]))
