extends GdUnitTestSuite
## Elevation (relief grid): bilinear heights, slope, input checks and full ratings against the Python reference.
## Relief holes: uphill, downhill, hump, sidehill, green_tilt, plus the flat twin (no relief key).

var _g: Dictionary


func before() -> void:
	_g = MHRatingGolden.load_all()


func _sim(name: String) -> Dictionary:
	for c in _g["sims"]:
		if String(c["name"]) == name:
			return c
	return {}


func _rate_matches(name: String) -> void:
	var c: Dictionary = _sim(name)
	assert_bool(c.size() > 0).is_true()
	var ctx: Dictionary = {"save_secret": MHRatingGolden.i(c["secret"]), "rating_epoch": MHRatingGolden.i(c["epoch"]),
		"condition": c["cond"], "preview": bool(c["preview"])}
	var r: Dictionary = MHRatingEngine.rate_hole(c["hole"] as Dictionary, ctx)
	assert_bool(bool(r["valid"])).is_true()
	assert_str(String(r["hash"])).is_equal(String(c["sim_hash"]))
	assert_str(String(r["content_hash"])).is_equal(String(c["content_hash"]))
	for key in ["score_pm", "score", "A", "I", "Len", "B", "F", "elev", "shape", "pace_pm", "forced_pm"]:
		assert_int(MHRatingGolden.i(r[key])).is_equal(MHRatingGolden.i(c[key]))
	var mg: Array = r["means"]
	var mw: Array = c["means"]
	for k in range(6):
		assert_int(MHRatingGolden.i(mg[k])).is_equal(MHRatingGolden.i(mw[k]))


func test_uphill() -> void:
	_rate_matches("relief_uphill")


func test_downhill() -> void:
	_rate_matches("relief_downhill")


func test_hump() -> void:
	_rate_matches("relief_hump")


func test_sidehill() -> void:
	_rate_matches("relief_sidehill")


func test_green_tilt() -> void:
	_rate_matches("relief_green_tilt")


func test_flat_twin() -> void:
	_rate_matches("relief_flat")


func test_heights_and_gradients_match() -> void:
	for c in _g["relief_z"]:
		var h: MHRHole = MHRHole.from_def(c["hole"] as Dictionary)
		assert_bool(h.valid).is_true()
		assert_int(h.tee_z).is_equal(MHRatingGolden.i(c["tee_z"]))
		assert_int(h.green_z).is_equal(MHRatingGolden.i(c["green_z"]))
		assert_int(h.elev_mm()).is_equal(MHRatingGolden.i(c["elev_mm"]))
		for p in c["pts"]:
			var a: Array = p
			assert_int(h.z_at(MHRatingGolden.i(a[0]), MHRatingGolden.i(a[1]))).is_equal(MHRatingGolden.i(a[2]))
		for q in c["grad"]:
			var b: Array = q
			var g: Vector2i = h.grad(MHRatingGolden.i(b[0]), MHRatingGolden.i(b[1]))
			assert_int(g.x).is_equal(MHRatingGolden.i(b[2]))
			assert_int(g.y).is_equal(MHRatingGolden.i(b[3]))


func test_relief_input_codes() -> void:
	for c in _g["relief_validate"]:
		var res: Dictionary = MHRatingEngine.validate_input(c["input"])
		assert_str(String(res["code"])).is_equal(String(c["code"]))


func test_hill_changes_rating_but_flat_ignores_relief_key() -> void:
	var flat: Dictionary = (_sim("relief_flat")["hole"] as Dictionary).duplicate(true)
	var hump: Dictionary = (_sim("relief_hump")["hole"] as Dictionary)
	var ctx: Dictionary = {"save_secret": 12345678, "rating_epoch": 1}
	var rf: Dictionary = MHRatingEngine.rate_hole(flat, ctx)
	var rh: Dictionary = MHRatingEngine.rate_hole(hump, ctx)
	assert_int(MHRatingGolden.i(rf["elev"])).is_equal(0)
	assert_bool(MHRatingGolden.i(rh["elev"]) > 0).is_true()
	assert_str(String(rf["hash"])).is_not_equal(String(rh["hash"]))
