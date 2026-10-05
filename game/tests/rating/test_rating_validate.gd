extends GdUnitTestSuite
## Untrusted input rejection (spec 2.2) and invalid hole codes (2.3), from golden fuzz and invalid_holes.

var _g: Dictionary


func before() -> void:
	_g = MHRatingGolden.load_all()


func test_fuzz_rejection_codes() -> void:
	for c in _g["fuzz"]:
		var res: Dictionary = MHRatingEngine.validate_input(c["input"])
		assert_str(String(res["code"])).is_equal(String(c["code"]))
		assert_bool(bool(res["ok"])).is_false()


func test_embedded_score_ignored() -> void:
	var emb: Dictionary = _g["fuzz_embedded"]
	var inp: Dictionary = emb["input"]
	assert_bool(bool(MHRatingEngine.validate_input(inp)["ok"])).is_true()
	var ctx: Dictionary = {"save_secret": _g["secret"], "rating_epoch": 1}
	# the outer input carries claimed_score 999; a tainted hole also carries claimed axes. Neither is ever read.
	var tainted: Dictionary = (inp["hole"] as Dictionary).duplicate(true)
	tainted["score_pm"] = 999
	tainted["A"] = 1000
	var a: Dictionary = MHRatingEngine.rate_shared(inp, ctx)
	var b: Dictionary = MHRatingEngine.rate_hole(tainted, ctx)
	assert_bool(MHRatingGolden.i(a["score_pm"]) < 999).is_true()
	assert_int(MHRatingGolden.i(a["score_pm"])).is_equal(MHRatingGolden.i(b["score_pm"]))
	assert_str(String(a["hash"])).is_equal(String(b["hash"]))


func test_integer_valued_floats_are_integers() -> void:
	assert_bool(MHRValidate.is_int_value(5.0)).is_true()
	assert_bool(MHRValidate.is_int_value(5)).is_true()
	assert_bool(MHRValidate.is_int_value(0.5)).is_false()
	assert_bool(MHRValidate.is_int_value("5")).is_false()
	assert_bool(MHRValidate.is_int_value(true)).is_false()
	assert_bool(MHRValidate.is_int_value(null)).is_false()
	assert_bool(MHRValidate.is_int_value(INF)).is_false()
	assert_bool(MHRValidate.is_int_value(NAN)).is_false()


func test_invalid_holes_score_zero_with_codes() -> void:
	for c in _g["invalid_holes"]:
		var r: Dictionary = MHRatingEngine.rate_hole(c["hole"] as Dictionary, {"save_secret": 1, "rating_epoch": 1})
		assert_bool(bool(r["valid"])).is_false()
		assert_int(MHRatingGolden.i(r["score_pm"])).is_equal(0)
		var want: Array = c["reasons"]
		var got: Array = r["reasons"]
		assert_int(got.size()).is_equal(want.size())
		for k in range(want.size()):
			assert_str(String(got[k])).is_equal(String(want[k]))


func test_rate_shared_rejects_before_rating() -> void:
	var r: Dictionary = MHRatingEngine.rate_shared([1, 2, 3], {})
	assert_bool(bool(r["valid"])).is_false()
	assert_str(String(r["reasons"][0])).is_equal("E01_NOT_OBJECT")
