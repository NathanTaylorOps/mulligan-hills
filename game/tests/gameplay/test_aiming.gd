extends GdUnitTestSuite
## Aim selection cannot commit a shot; contact ownership remains independent of camera projection.

func test_world_tap_aims_but_ui_tap_does_not() -> void:
	var tap: MHAimTap = MHAimTap.new()
	assert_bool(tap.down(0, Vector2(10, 20), false)).is_true()
	var result: Dictionary = tap.up(0, Vector2(12, 22), false)
	assert_bool(result["consume"]).is_true()
	assert_bool(result["aim"]).is_true()
	assert_bool(tap.down(0, Vector2(10, 20), true)).is_false()
	result = tap.up(0, Vector2(10, 20), false)
	assert_bool(result["consume"]).is_false()
	assert_bool(result["aim"]).is_false()

func test_drag_return_cancel_and_ui_crossing_do_not_aim() -> void:
	var tap: MHAimTap = MHAimTap.new()
	tap.down(0, Vector2.ZERO, false)
	assert_bool(tap.drag(0, Vector2(30, 0))).is_true()
	assert_bool(tap.up(0, Vector2.ZERO, false)["aim"]).is_false()
	tap.down(0, Vector2.ZERO, false)
	assert_bool(tap.up(0, Vector2.ZERO, false, true)["aim"]).is_false()
	tap.down(0, Vector2.ZERO, false)
	assert_bool(tap.up(0, Vector2.ZERO, true)["aim"]).is_false()

func test_second_finger_in_ui_cancels_world_tap_until_all_lift() -> void:
	var tap: MHAimTap = MHAimTap.new()
	tap.down(0, Vector2.ZERO, false)
	tap.down(1, Vector2(50, 50), true)
	assert_bool(tap.up(1, Vector2(50, 50), true)["aim"]).is_false()
	assert_bool(tap.up(0, Vector2.ZERO, false)["aim"]).is_false()
	tap.down(2, Vector2.ZERO, false)
	assert_bool(tap.up(2, Vector2.ZERO, false)["aim"]).is_true()

func test_clear_prevents_latent_release_and_hybrid_pointer_aim() -> void:
	var tap: MHAimTap = MHAimTap.new()
	tap.down(-1, Vector2.ZERO, false)
	tap.clear()
	assert_bool(tap.up(-1, Vector2.ZERO, false)["aim"]).is_false()
	tap.down(-1, Vector2.ZERO, false)
	tap.down(0, Vector2.ZERO, false)
	assert_bool(tap.up(-1, Vector2.ZERO, false)["aim"]).is_false()
	assert_bool(tap.up(0, Vector2.ZERO, false)["aim"]).is_false()

func _round() -> MHPracticeRound:
	return MHPracticeRound.create({"slot_id": 0, "tee": [0, 0], "green": [0, 60, 5],
		"features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}, {"t": "water", "rect": [10, 20, 14, 30]}]}, 1234)

func test_preview_uses_carry_without_consuming_next_draw_or_game_state() -> void:
	var r: MHPracticeRound = _round()
	var before: Dictionary = r.to_dict()
	var preview: Dictionary = r.aim_preview(0, 6000)
	assert_bool(preview["ok"]).is_true()
	assert_bool(preview["reachable"]).is_true()
	assert_int(int(preview["landing_x"])).is_equal(0)
	assert_int(int(preview["landing_y"])).is_equal(6000)
	assert_dict(r.to_dict()).is_equal(before)
	var copy: MHPracticeRound = MHPracticeRound.restore({"slot_id": 0, "tee": [0, 0], "green": [0, 60, 5],
		"features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}, {"t": "water", "rect": [10, 20, 14, 30]}]}, before)
	assert_dict(r.play(0, 6000)).is_equal(copy.play(0, 6000))

func test_unreachable_and_water_target_feedback() -> void:
	var r: MHPracticeRound = _round()
	var preview: Dictionary = r.aim_preview(0, 100000)
	assert_bool(preview["reachable"]).is_false()
	assert_int(int(preview["landing_y"])).is_less(100000)
	preview = r.aim_preview(1200, 2500)
	assert_int(int(preview["landing_lie"])).is_equal(MHRHole.LIE_WATER)
	assert_bool(r.aim_preview(120001, 0)["ok"]).is_false()
