extends GdUnitTestSuite
## Asserts MHTrig and the generated table equal the Python reference (golden/trig.json).

var _g: Dictionary


func before() -> void:
	_g = MHGolden.load_json("trig.json")


func test_table_sizes_and_hash() -> void:
	assert_int(MHTrigTable.SIN_QUARTER.size()).is_equal(MHGolden.i(_g["sin_len"]))
	assert_int(MHTrigTable.ATAN_OCTANT.size()).is_equal(MHGolden.i(_g["atan_len"]))
	var f: MHHash = MHHash.new()
	for v in MHTrigTable.SIN_QUARTER:
		f.add_i64(v)
	for v in MHTrigTable.ATAN_OCTANT:
		f.add_i64(v)
	assert_str(f.hex()).is_equal(_g["table_hash"])


func test_sin_cos() -> void:
	for row in _g["sincos"]:
		var a: int = MHGolden.i(row[0])
		assert_int(MHTrig.sin_brad(a)).is_equal(MHGolden.i(row[1]))
		assert_int(MHTrig.cos_brad(a)).is_equal(MHGolden.i(row[2]))


func test_atan2() -> void:
	for row in _g["atan2"]:
		assert_int(MHTrig.atan2_brad(MHGolden.i(row[0]), MHGolden.i(row[1]))).is_equal(MHGolden.i(row[2]))


func test_cardinal_points() -> void:
	assert_int(MHTrig.sin_brad(0)).is_equal(0)
	assert_int(MHTrig.cos_brad(0)).is_equal(65536)
	assert_int(MHTrig.sin_brad(16384)).is_equal(65536)
	assert_int(MHTrig.sin_brad(32768)).is_equal(0)
	assert_int(MHTrig.sin_brad(-16384)).is_equal(-65536)
