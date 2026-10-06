extends GdUnitTestSuite
## AI display records must come from the same deterministic MHRSim that rates the submitted hole.


func _hole(relief: bool) -> Dictionary:
	var h: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 120, 5],
		"features": [{"t": "fairway", "rect": [-12, 0, 12, 120]}]}
	if relief:
		h["relief"] = {"x0": -16, "y0": 0, "step": 4, "cols": 9, "rows": 33, "z": []}
		for row: int in range(33):
			for _col: int in range(9):
				(h["relief"]["z"] as Array).append(row * 200)
	return h


func test_ai_record_is_deterministic_and_uses_exact_hole() -> void:
	var h: Dictionary = _hole(false)
	var ctx: Dictionary = {"save_secret": 123456, "rating_epoch": 7}
	var a: Dictionary = MHAIRoundRecord.play(h, ctx)
	var b: Dictionary = MHAIRoundRecord.play(h, ctx)
	assert_bool(a.is_empty()).is_false()
	assert_dict(a).is_equal(b)
	assert_str(str(a["content_hash"])).is_equal(MHRHole.from_def(h).content_hash())
	assert_bool(bool(a["has_relief"])).is_false()
	assert_int(int(a["strokes"])).is_greater(0)


func test_ai_record_consumes_elevated_relief_hole() -> void:
	var h: Dictionary = _hole(true)
	var record: Dictionary = MHAIRoundRecord.play(h, {"save_secret": 123456, "rating_epoch": 7})
	assert_bool(record.is_empty()).is_false()
	assert_bool(bool(record["has_relief"])).is_true()
	assert_str(str(record["content_hash"])).is_equal(MHRHole.from_def(h).content_hash())
	assert_bool(int(record["first_y"]) != 0 or int(record["first_x"]) != 0).is_true()
