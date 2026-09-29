extends GdUnitTestSuite
## Asserts MHRng equals the Python reference (golden/rng.json). Case 0 is the published PCG32 demo
## vector (seed 42, stream 54): a15c02b7 7b47f409 ba1d3330 83d2f293 bfa4784b cbed606e.

var _g: Dictionary


func before() -> void:
	_g = MHGolden.load_json("rng.json")


func test_published_pcg32_vector() -> void:
	var r: MHRng = MHRng.new(42, 54)
	var expect: Array = [0xa15c02b7, 0x7b47f409, 0xba1d3330, 0x83d2f293, 0xbfa4784b, 0xcbed606e]
	for e in expect:
		assert_int(r.next_u32()).is_equal(e)


func test_u32_streams() -> void:
	for c in _g["cases"]:
		var r: MHRng = MHRng.new(MHGolden.i(c["seed"]), MHGolden.i(c["stream"]))
		for v in c["u32"]:
			assert_int(r.next_u32()).is_equal(MHGolden.i(v))


func test_bounded_and_range() -> void:
	for c in _g["cases"]:
		var s: int = MHGolden.i(c["seed"])
		var st: int = MHGolden.i(c["stream"])
		var r: MHRng = MHRng.new(s, st)
		for v in c["bounded100"]:
			assert_int(r.bounded(100)).is_equal(MHGolden.i(v))
		r = MHRng.new(s, st)
		for v in c["bounded3"]:
			assert_int(r.bounded(3)).is_equal(MHGolden.i(v))
		r = MHRng.new(s, st)
		for v in c["range_m5_5"]:
			assert_int(r.range_incl(-5, 5)).is_equal(MHGolden.i(v))


func test_gauss() -> void:
	for c in _g["cases"]:
		var r: MHRng = MHRng.new(MHGolden.i(c["seed"]), MHGolden.i(c["stream"]))
		for v in c["gauss"]:
			assert_int(r.gauss_q16()).is_equal(MHGolden.i(v))


func test_mixed_1000_hash() -> void:
	for c in _g["cases"]:
		var r: MHRng = MHRng.new(MHGolden.i(c["seed"]), MHGolden.i(c["stream"]))
		var f: MHHash = MHHash.new()
		for i in range(1000):
			var k: int = i % 4
			var v: int
			if k == 0:
				v = r.next_u32()
			elif k == 1:
				v = r.bounded(1000)
			elif k == 2:
				v = r.range_incl(-100, 100)
			else:
				v = r.gauss_q16()
			f.add_i64(v)
		assert_str(f.hex()).is_equal(c["mixed1000_hash"])
