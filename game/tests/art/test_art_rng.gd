extends GdUnitTestSuite
## MHArtRng golden values come from a Python port of the same integer maths. The first three sequence
## values for seed 12345 equal the MHForestRng goldens in tests/render/test_tree_placement.gd, which
## confirms the two generators are the same family. NOT YET RUN in Godot.


func test_mul32_wraps_like_unsigned_32_bit() -> void:
	assert_int(MHArtRng.mul32(3, 5)).is_equal(15)
	assert_int(MHArtRng.mul32(0xFFFFFFFF, 0xFFFFFFFF)).is_equal(1)
	assert_int(MHArtRng.mul32(0x12345678, 0x9ABCDEF0)).is_equal(606937216)


func test_hash32_golden() -> void:
	assert_int(MHArtRng.hash32(0)).is_equal(0)
	assert_int(MHArtRng.hash32(1)).is_equal(1753845952)
	assert_int(MHArtRng.hash32(12345)).is_equal(2435775735)
	assert_int(MHArtRng.hash32(0xFFFFFFFF)).is_equal(1734902346)


func test_hash2_golden_and_order_dependence() -> void:
	assert_int(MHArtRng.hash2(1, 2)).is_equal(3065084306)
	assert_int(MHArtRng.hash2(0, 0)).is_equal(0)
	assert_int(MHArtRng.hash2(7, 1000)).is_equal(3081096510)
	assert_bool(MHArtRng.hash2(1, 2) != MHArtRng.hash2(2, 1)).is_true()


func test_sequence_golden() -> void:
	var r: MHArtRng = MHArtRng.new(12345)
	assert_int(r.next_u32()).is_equal(3747499950)
	assert_int(r.next_u32()).is_equal(733492749)
	assert_int(r.next_u32()).is_equal(239011186)
	assert_int(r.next_u32()).is_equal(255071798)
	var z: MHArtRng = MHArtRng.new(0)
	assert_int(z.next_u32()).is_equal(582675419)
	assert_int(z.next_u32()).is_equal(4245288871)


func test_range_helpers_golden() -> void:
	var r: MHArtRng = MHArtRng.new(99)
	assert_int(r.range_int(10)).is_equal(2)
	assert_int(r.range_int(10)).is_equal(4)
	assert_int(r.range_int(10)).is_equal(9)
	var u: MHArtRng = MHArtRng.new(99)
	assert_float(u.unit()).is_equal_approx(0.3115, 0.00001)
	assert_float(u.unit()).is_equal_approx(0.245, 0.00001)


func test_noise2_golden_and_range() -> void:
	assert_float(MHArtRng.noise2(1, 2)).is_equal_approx(0.106, 0.00001)
	for i in range(200):
		var n: float = MHArtRng.noise2(i, i * 3 - 100)
		assert_float(n).is_between(-1.0, 1.0)


func test_ranges_stay_inside_bounds() -> void:
	var r: MHArtRng = MHArtRng.new(7)
	for i in range(500):
		assert_int(r.range_int(7)).is_between(0, 6)
		assert_float(r.unit()).is_between(0.0, 1.0)
		assert_float(r.range_f(-2.0, 3.0)).is_between(-2.0, 3.0)
		assert_float(r.signed()).is_between(-1.0, 1.0)


func test_same_seed_same_sequence_and_different_seed_differs() -> void:
	var a: MHArtRng = MHArtRng.new(5)
	var b: MHArtRng = MHArtRng.new(5)
	var c: MHArtRng = MHArtRng.new(6)
	var same: bool = true
	var differs: bool = false
	for i in range(50):
		var x: int = a.next_u32()
		if x != b.next_u32():
			same = false
		if x != c.next_u32():
			differs = true
	assert_bool(same).is_true()
	assert_bool(differs).is_true()
