extends GdUnitTestSuite
## Asserts MHFixed equals the Python reference golden vectors (golden/fixed.json).

var _g: Dictionary


func before() -> void:
	_g = MHGolden.load_json("fixed.json")


func test_golden_file_loaded() -> void:
	assert_bool(_g.has("mul")).is_true()


func test_mul() -> void:
	for row in _g["mul"]:
		assert_int(MHFixed.mul(MHGolden.i(row[0]), MHGolden.i(row[1]))).is_equal(MHGolden.i(row[2]))


func test_div() -> void:
	for row in _g["div"]:
		assert_int(MHFixed.div(MHGolden.i(row[0]), MHGolden.i(row[1]))).is_equal(MHGolden.i(row[2]))


func test_sqrt() -> void:
	for row in _g["sqrt"]:
		assert_int(MHFixed.sqrt_fx(MHGolden.i(row[0]))).is_equal(MHGolden.i(row[1]))


func test_isqrt() -> void:
	for row in _g["isqrt"]:
		assert_int(MHFixed.isqrt(MHGolden.i(row[0]))).is_equal(MHGolden.i(row[1]))


func test_lerp() -> void:
	for row in _g["lerp"]:
		assert_int(MHFixed.lerp_fx(MHGolden.i(row[0]), MHGolden.i(row[1]), MHGolden.i(row[2]))).is_equal(MHGolden.i(row[3]))


func test_clamp() -> void:
	for row in _g["clamp"]:
		assert_int(MHFixed.clamp_fx(MHGolden.i(row[0]), MHGolden.i(row[1]), MHGolden.i(row[2]))).is_equal(MHGolden.i(row[3]))


func test_trunc_and_floor() -> void:
	for row in _g["trunc_floor"]:
		assert_int(MHFixed.trunc_int(MHGolden.i(row[0]))).is_equal(MHGolden.i(row[1]))
		assert_int(MHFixed.floor_int(MHGolden.i(row[0]))).is_equal(MHGolden.i(row[2]))


func test_hypot() -> void:
	for row in _g["hypot"]:
		assert_int(MHFixed.hypot(MHGolden.i(row[0]), MHGolden.i(row[1]))).is_equal(MHGolden.i(row[2]))


func test_negative_semantics_documented() -> void:
	# div and trunc truncate toward zero; floor_int rounds down.
	assert_int(MHFixed.div(-1, 3)).is_equal(-21845)
	assert_int(MHFixed.trunc_int(-1)).is_equal(0)
	assert_int(MHFixed.floor_int(-1)).is_equal(-1)
	assert_int(MHFixed.mul(-65536, 65536)).is_equal(-65536)
