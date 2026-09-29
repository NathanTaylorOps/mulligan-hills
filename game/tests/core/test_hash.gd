extends GdUnitTestSuite
## Asserts MHHash equals the Python reference (golden/hash.json). Includes the published
## FNV-1a 64 vectors: "a" = af63dc4c8601ec8c, "foobar" = 85944171f73967e8.

var _g: Dictionary


func before() -> void:
	_g = MHGolden.load_json("hash.json")


func test_byte_vectors() -> void:
	for c in _g["bytes"]:
		var f: MHHash = MHHash.new()
		for b in c["bytes"]:
			f.add_byte(MHGolden.i(b))
		assert_str(f.hex()).is_equal(c["hex"])


func test_published_vectors() -> void:
	var f: MHHash = MHHash.new()
	assert_str(f.hex()).is_equal("cbf29ce484222325")
	f.add_byte(97)
	assert_str(f.hex()).is_equal("af63dc4c8601ec8c")


func test_single_i64() -> void:
	for row in _g["single_i64"]:
		var f: MHHash = MHHash.new()
		f.add_i64(MHGolden.i(row[0]))
		assert_str(f.hex()).is_equal(row[1])


func test_u32() -> void:
	for row in _g["u32"]:
		var f: MHHash = MHHash.new()
		f.add_u32(MHGolden.i(row[0]))
		assert_str(f.hex()).is_equal(row[1])


func test_sequence() -> void:
	var f: MHHash = MHHash.new()
	for v in _g["seq_i64"]:
		f.add_i64(MHGolden.i(v))
	assert_str(f.hex()).is_equal(_g["seq_hash"])
