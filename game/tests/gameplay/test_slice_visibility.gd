extends GdUnitTestSuite
## MHSliceVisibility: figure / baked / hidden cap logic. Pure. NOT YET RUN in Godot.

const H: int = MHSliceVisibility.HIDDEN
const B: int = MHSliceVisibility.BAKED
const F: int = MHSliceVisibility.FIGURE


func test_empty_input() -> void:
	assert_int(MHSliceVisibility.classify([], [], 2, 10).size()).is_equal(0)


func test_nearest_golfers_become_figures() -> void:
	var out: PackedInt32Array = MHSliceVisibility.classify([100.0, 4.0, 9.0], [0, 1, 2], 2, 3)
	assert_int(out[0]).is_equal(B)
	assert_int(out[1]).is_equal(F)
	assert_int(out[2]).is_equal(F)


func test_farthest_golfers_are_hidden_beyond_the_total_cap() -> void:
	var out: PackedInt32Array = MHSliceVisibility.classify([50.0, 10.0, 40.0, 20.0, 30.0], [0, 1, 2, 3, 4], 1, 3)
	assert_int(out[1]).is_equal(F)
	assert_int(out[3]).is_equal(B)
	assert_int(out[4]).is_equal(B)
	assert_int(out[2]).is_equal(H)
	assert_int(out[0]).is_equal(H)


func test_two_near_golfers_with_the_same_look_cannot_both_be_figures() -> void:
	var out: PackedInt32Array = MHSliceVisibility.classify([1.0, 2.0, 3.0], [5, 5, 6], 2, 10)
	assert_int(out[0]).is_equal(F)
	assert_int(out[1]).is_equal(B)
	assert_int(out[2]).is_equal(F)


func test_equal_distance_ties_go_to_the_lower_index() -> void:
	var out: PackedInt32Array = MHSliceVisibility.classify([4.0, 4.0], [0, 1], 1, 10)
	assert_int(out[0]).is_equal(F)
	assert_int(out[1]).is_equal(B)


func test_zero_caps() -> void:
	var none: PackedInt32Array = MHSliceVisibility.classify([1.0, 2.0], [0, 1], 0, 0)
	assert_int(MHSliceVisibility.count_state(none, H)).is_equal(2)
	var no_figures: PackedInt32Array = MHSliceVisibility.classify([1.0, 2.0], [0, 1], 0, 5)
	assert_int(MHSliceVisibility.count_state(no_figures, B)).is_equal(2)
	var negative: PackedInt32Array = MHSliceVisibility.classify([1.0], [0], -3, -3)
	assert_int(negative[0]).is_equal(H)


func test_caps_are_never_exceeded() -> void:
	var rng: MHArtRng = MHArtRng.new(77)
	for trial: int in range(25):
		var n: int = 1 + rng.range_int(40)
		var dist2: Array = []
		var looks: Array = []
		for i: int in range(n):
			dist2.append(float(rng.range_int(10000)))
			looks.append(rng.range_int(12))
		var near: int = rng.range_int(9)
		var total: int = rng.range_int(30)
		var out: PackedInt32Array = MHSliceVisibility.classify(dist2, looks, near, total)
		assert_int(out.size()).is_equal(n)
		assert_int(MHSliceVisibility.count_state(out, F)).is_less_equal(near)
		assert_int(MHSliceVisibility.count_state(out, F) + MHSliceVisibility.count_state(out, B)).is_less_equal(total)
		assert_int(MHSliceVisibility.count_state(out, F) + MHSliceVisibility.count_state(out, B)).is_equal(mini(n, total))
		# Figures have distinct looks.
		var seen: Dictionary = {}
		for i: int in range(n):
			if out[i] == F:
				assert_bool(seen.has(int(looks[i]))).is_false()
				seen[int(looks[i])] = true


func test_a_visible_golfer_is_never_farther_than_a_hidden_one() -> void:
	var dist2: Array = [90.0, 10.0, 70.0, 30.0, 50.0, 20.0]
	var out: PackedInt32Array = MHSliceVisibility.classify(dist2, [0, 1, 2, 3, 4, 5], 2, 4)
	var far_visible: float = 0.0
	var near_hidden: float = 1.0e9
	for i: int in range(dist2.size()):
		if out[i] == H:
			near_hidden = minf(near_hidden, float(dist2[i]))
		else:
			far_visible = maxf(far_visible, float(dist2[i]))
	assert_float(far_visible).is_less(near_hidden)


func test_tier_caps_grow_with_the_tier_and_stay_in_the_stated_range() -> void:
	var low: Dictionary = MHSliceVisibility.caps_for_tier("low")
	var med: Dictionary = MHSliceVisibility.caps_for_tier("medium")
	var high: Dictionary = MHSliceVisibility.caps_for_tier("high")
	assert_int(int(low["near"])).is_less_equal(int(med["near"]))
	assert_int(int(med["near"])).is_less_equal(int(high["near"]))
	assert_int(int(high["near"])).is_less_equal(8)
	assert_int(int(low["total"])).is_less_equal(int(med["total"]))
	assert_int(int(med["total"])).is_less_equal(int(high["total"]))
	for caps: Variant in [low, med, high]:
		assert_int(int((caps as Dictionary)["total"])).is_greater_equal(int((caps as Dictionary)["near"]))
	var unknown: Dictionary = MHSliceVisibility.caps_for_tier("nonsense")
	assert_int(int(unknown["near"])).is_equal(int(med["near"]))
