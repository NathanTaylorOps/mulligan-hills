extends GdUnitTestSuite
## Independently generated Python vectors; profile numbers normalized at JSON test boundary only.

func _profile() -> Dictionary:
	var p: Dictionary = {"v": 1}
	for key: String in MHPersonalEnvelope.ATTRIBUTES:
		p[key] = 500
	return p

func test_python_shot_vectors() -> void:
	assert_bool(MHRParams.ensure_loaded()).is_true()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/gameplay/fixtures/personal_shot_golden.json")) as Dictionary
	assert_int((data["cases"] as Array).size()).is_equal(12)
	for row: Dictionary in data["cases"]:
		var input: Dictionary = row["inputs"]
		var h: MHRHole = MHRHole.from_def(input["raw_hole"] as Dictionary)
		assert_bool(h.valid).is_true()
		var p: Dictionary = {}
		for key: String in input["raw_profile"]:
			p[key] = int(input["raw_profile"][key])
		var ball: Vector2i = Vector2i(int(input["ball"][0]), int(input["ball"][1]))
		var aim: Vector2i = Vector2i(int(input["aim"][0]), int(input["aim"][1]))
		var actual: Dictionary = MHPersonalShot.play(h, p, ball, str(input["lie"]), aim, int(input["seed"]), int(input["shot_index"]), str(input.get("style", "straight")), int(input.get("pressure_pm", 0)))
		assert_bool(actual.is_empty()).is_false()
		if actual.is_empty():
			continue
		var expected: Dictionary = row["expected"]
		assert_int(actual.size()).is_equal(expected.size())
		for key: String in expected:
			if typeof(expected[key]) == TYPE_FLOAT:
				assert_int(typeof(actual[key])).is_equal(TYPE_INT)
				assert_int(int(actual[key])).is_equal(int(expected[key]))
			elif typeof(expected[key]) == TYPE_BOOL:
				assert_int(typeof(actual[key])).is_equal(TYPE_BOOL)
				assert_bool(bool(actual[key])).is_equal(bool(expected[key]))
			else:
				assert_int(typeof(actual[key])).is_equal(TYPE_STRING)
				assert_str(str(actual[key])).is_equal(str(expected[key]))
		var before: Dictionary = actual.duplicate(true)
		MHPersonalShot.preview(h, p, ball, str(input["lie"]), aim, str(input.get("style", "straight")), int(input.get("pressure_pm", 0)))
		assert_dict(MHPersonalShot.play(h, p, ball, str(input["lie"]), aim, int(input["seed"]), int(input["shot_index"]), str(input.get("style", "straight")), int(input.get("pressure_pm", 0)))).is_equal(before)

func test_envelope_vector_and_strict_profile() -> void:
	var p: Dictionary = _profile()
	assert_dict(MHPersonalEnvelope.envelope(p, 10000, 30000, "fairway")).is_equal({"model": MHPersonalEnvelope.VERSION, "carry_max_cy": 24000, "effective_cy": 10000, "lie_spread_pm": 1000, "lateral_scale_cy": 850, "depth_scale_cy": 430})
	p["luck"] = true
	assert_bool(MHPersonalEnvelope.profile(p).is_empty()).is_true()
	p["luck"] = 500.0
	assert_bool(MHPersonalEnvelope.profile(p).is_empty()).is_true()
	p = _profile()
	var copied: Dictionary = MHPersonalEnvelope.profile(p)
	copied["power"] = 0
	assert_int(int(p["power"])).is_equal(500)
	assert_bool(MHPersonalEnvelope.envelope(p, 0, 30000, "fairway").is_empty()).is_true()
	assert_bool(MHPersonalEnvelope.envelope(p, 500, 30000, "green", "straight").is_empty()).is_true()

func test_zero_width_hazard_and_invalid_start() -> void:
	MHRParams.ensure_loaded()
	var h: MHRHole = MHRHole.from_def({"slot_id": 1, "tee": [0, 0], "green": [0, 100, 5], "features": [{"t": "fairway", "rect": [-20, 0, 20, 95]}, {"t": "water", "rect": [-5, 96, 5, 96]}]})
	var r: Dictionary = MHPersonalShot.play(h, _profile(), Vector2i(0, 9500), "green", Vector2i(0, 10000), 1234, 1, "putt")
	assert_int(int(r["penalty_kind"])).is_equal(1)
	assert_bool(MHPersonalShot.play(h, _profile(), Vector2i(0, 100), "tee", Vector2i(0, 6000), 1234, 1).is_empty()).is_true()
	assert_bool(MHPersonalShot.play(h, _profile(), Vector2i.ZERO, "tee", Vector2i(0, 6000), 1234, 0).is_empty()).is_true()
