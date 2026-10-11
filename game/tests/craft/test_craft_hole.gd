extends GdUnitTestSuite
## MHCraftHole: painting, heights, tees, pins, undo. Pure logic. NOT YET RUN in Godot.


func test_minimum_grid_is_relief_safe() -> void:
	var h: MHCraftHole = MHCraftHole.new(1, 1)
	assert_int(h.cols).is_greater_equal(2)
	assert_int(h.rows).is_greater_equal(2)


func test_tile_yard_mapping_round_trips() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	assert_int(h.tile_x0_yd(12)).is_equal(0) # column cols/2 starts at x = 0
	assert_int(h.tile_x0_yd(0)).is_equal(-24)
	var centre: Vector2i = h.tile_centre_yd(11, 0)
	assert_int(centre.x).is_equal(-1)
	assert_int(centre.y).is_equal(1)
	var t: Vector2i = h.tile_at_yd(centre.x, centre.y)
	assert_int(t.x).is_equal(11)
	assert_int(t.y).is_equal(0)
	assert_bool(h.tile_at_cy(centre.x * 100, centre.y * 100) == Vector2i(11, 0)).is_true()
	# Near a 2-yard boundary the centiyard lookup must not round into the next tile.
	assert_bool(h.tile_at_cy(199, 199) == Vector2i(12, 0)).is_true()
	assert_bool(h.tile_at_cy(200, 200) == Vector2i(13, 1)).is_true()
	assert_int(h.tile_at_yd(-1000, 5).x).is_equal(-1)


func test_paint_and_disc_and_bounds() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.paint_tile(5, 5, MHCraftHole.Surface.FAIRWAY)
	assert_int(h.get_surface(5, 5)).is_equal(MHCraftHole.Surface.FAIRWAY)
	h.paint_tile(-1, 5, MHCraftHole.Surface.FAIRWAY) # ignored
	h.paint_disc(10, 10, 1, MHCraftHole.Surface.WATER)
	assert_int(h.count_surface(MHCraftHole.Surface.WATER)).is_equal(5) # centre plus four neighbours
	assert_int(h.get_surface(99, 99)).is_equal(MHCraftHole.Surface.OUT_OF_BOUNDS)


func test_exact_millimetre_height_survives_undo_redo() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	assert_bool(h.begin_stroke()).is_true()
	h.set_height_mm_tile(7, 9, 650)
	assert_bool(h.commit_stroke()).is_true()
	assert_int(h.get_height_mm(7, 9)).is_equal(650)
	assert_int(h.get_height(7, 9)).is_equal(1)
	assert_bool(h.undo()).is_true()
	assert_int(h.get_height_mm(7, 9)).is_equal(0)
	assert_bool(h.redo()).is_true()
	assert_int(h.get_height_mm(7, 9)).is_equal(650)


func test_heights_are_clamped_to_the_range() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.set_height_tile(3, 3, 99)
	assert_int(h.get_height(3, 3)).is_equal(MHCraftHole.HEIGHT_MAX_M)
	h.set_height_tile(3, 3, -99)
	assert_int(h.get_height(3, 3)).is_equal(MHCraftHole.HEIGHT_MIN_M)
	h.raise_disc(8, 8, 0, 3)
	h.raise_disc(8, 8, 0, 20)
	assert_int(h.get_height(8, 8)).is_equal(MHCraftHole.HEIGHT_MAX_M)


func test_level_and_smooth_are_stroke_safe_and_order_independent_per_dab() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.set_height_tile(10, 10, 6)
	h.set_height_tile(11, 10, 0)
	h.set_height_tile(10, 11, 0)
	h.begin_stroke()
	h.level_disc(10, 10, 1, 3)
	assert_bool(h.commit_stroke()).is_true()
	assert_int(h.get_height(10, 10)).is_equal(3)
	assert_int(h.get_height(11, 10)).is_equal(3)
	assert_bool(h.undo()).is_true()
	assert_int(h.get_height(10, 10)).is_equal(6)
	assert_int(h.get_height(11, 10)).is_equal(0)
	h.begin_stroke()
	h.smooth_disc(10, 10, 1)
	assert_bool(h.commit_stroke()).is_true()
	assert_bool(h.get_height(10, 10) < 6).is_true()
	assert_bool(h.get_height(11, 10) > 0).is_true()


func test_a_stroke_undoes_and_redoes_as_one_step() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	assert_bool(h.begin_stroke()).is_true()
	h.paint_rect(2, 2, 4, 3, MHCraftHole.Surface.BUNKER)
	h.raise_disc(3, 2, 0, 5)
	assert_bool(h.commit_stroke()).is_true()
	assert_int(h.count_surface(MHCraftHole.Surface.BUNKER)).is_equal(6)
	assert_int(h.get_height(3, 2)).is_equal(5)
	assert_int(h.undo_count()).is_equal(1)
	assert_bool(h.undo()).is_true()
	assert_int(h.count_surface(MHCraftHole.Surface.BUNKER)).is_equal(0)
	assert_int(h.get_height(3, 2)).is_equal(0)
	assert_bool(h.can_redo()).is_true()
	assert_bool(h.redo()).is_true()
	assert_int(h.count_surface(MHCraftHole.Surface.BUNKER)).is_equal(6)
	assert_int(h.get_height(3, 2)).is_equal(5)
	assert_bool(h.undo()).is_true()
	assert_bool(h.undo()).is_false() # nothing left


func test_empty_stroke_is_dropped_and_new_stroke_clears_redo() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.begin_stroke()
	assert_bool(h.commit_stroke()).is_false()
	assert_int(h.undo_count()).is_equal(0)
	h.begin_stroke()
	h.paint_tile(1, 1, MHCraftHole.Surface.WATER)
	h.commit_stroke()
	h.undo()
	h.begin_stroke()
	h.paint_tile(2, 2, MHCraftHole.Surface.WATER)
	h.commit_stroke()
	assert_bool(h.can_redo()).is_false()


func test_painting_the_same_value_changes_nothing() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.begin_stroke()
	h.paint_tile(4, 4, MHCraftHole.Surface.ROUGH) # already rough
	assert_bool(h.commit_stroke()).is_false()


func test_cancel_rolls_back_and_no_edit_while_undo_blocked() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.begin_stroke()
	h.paint_rect(0, 0, 3, 3, MHCraftHole.Surface.WATER)
	assert_bool(h.can_undo()).is_false() # a stroke is open
	h.cancel_stroke()
	assert_int(h.count_surface(MHCraftHole.Surface.WATER)).is_equal(0)
	assert_int(h.undo_count()).is_equal(0)


func test_craft_draft_serialization_preserves_exact_state() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.paint_tile(4, 5, MHCraftHole.Surface.OUT_OF_BOUNDS)
	h.paint_tile(8, 12, MHCraftHole.Surface.WATER)
	h.set_height_mm_tile(8, 12, 650)
	h.add_tee(11, 0)
	h.add_pin(11, 30)
	h.add_pin(12, 31)
	h.add_tree_yd(-5, 20)
	h.rocks = 3
	h.flowers = 9
	var restored: MHCraftHole = MHCraftHole.from_dict(h.to_dict())
	assert_object(restored).is_not_null()
	assert_int(restored.get_surface(4, 5)).is_equal(MHCraftHole.Surface.OUT_OF_BOUNDS)
	assert_int(restored.get_surface(8, 12)).is_equal(MHCraftHole.Surface.WATER)
	assert_int(restored.get_height_mm(8, 12)).is_equal(650)
	assert_array(restored.tees).contains_exactly([Vector2i(11, 0)])
	assert_array(restored.pins).contains_exactly([Vector2i(11, 30), Vector2i(12, 31)])
	assert_array(restored.trees).contains_exactly([Vector2i(-5, 20)])
	assert_int(restored.rocks).is_equal(3)
	assert_int(restored.flowers).is_equal(9)
	assert_int(restored.undo_count()).is_equal(0)


func test_craft_course_rejects_out_of_range_world_origins() -> void:
	var craft: MHCraftCourse = MHCraftCourse.new()
	var saved: Dictionary = craft.to_dict()
	saved["origins_dm"] = [[-1, 560]]
	assert_object(MHCraftCourse.from_dict(saved)).is_null()
	saved = craft.to_dict()
	saved["origins_dm"] = [[65536, 560]]
	assert_object(MHCraftCourse.from_dict(saved)).is_null()
	saved = craft.to_dict()
	saved["origins_dm"] = [[600, 65535]]
	assert_object(MHCraftCourse.from_dict(saved)).is_not_null()


func test_all_default_course_origins_are_unique_integer_only_and_round_trip() -> void:
	var craft: MHCraftCourse = MHCraftCourse.new()
	craft.ensure_holes(MHCraftCourse.MAX_HOLES)
	var seen: Dictionary = {}
	for origin_value: Variant in craft.origins_dm:
		var origin: Array = origin_value as Array
		assert_int(typeof(origin[0])).is_equal(TYPE_INT)
		assert_int(typeof(origin[1])).is_equal(TYPE_INT)
		var key: String = "%d,%d" % [int(origin[0]), int(origin[1])]
		assert_bool(seen.has(key)).override_failure_message("duplicate origin " + key).is_false()
		seen[key] = true
	var restored: MHCraftCourse = MHCraftCourse.from_dict(craft.to_dict())
	assert_object(restored).is_not_null()
	if restored != null:
		assert_array(restored.origins_dm).is_equal(craft.origins_dm)


func test_craft_course_rejects_coerced_metadata_extra_keys_and_bad_active_index() -> void:
	var craft: MHCraftCourse = MHCraftCourse.new()
	var saved: Dictionary = craft.to_dict()
	saved["v"] = "2"
	assert_object(MHCraftCourse.from_dict(saved)).is_null()
	saved = craft.to_dict()
	saved["extra"] = 1
	assert_object(MHCraftCourse.from_dict(saved)).is_null()
	saved = craft.to_dict()
	saved["active"] = 1
	assert_object(MHCraftCourse.from_dict(saved)).is_null()


func test_one_tee_and_four_pins_rotate_by_round() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	assert_int(h.add_tee(11, 0)).is_equal(0)
	assert_int(h.add_tee(11, 2)).is_equal(-1) # one tee box per hole (DEC-090)
	assert_int(h.pin_for_round(0)).is_equal(-1) # no pins yet
	for i: int in range(4):
		assert_int(h.add_pin(10 + i, 30)).is_equal(i)
	assert_int(h.add_pin(10, 31)).is_equal(-1)
	assert_int(h.pin_for_round(0)).is_equal(0)
	assert_int(h.pin_for_round(5)).is_equal(1)
	assert_int(h.pin_for_round(-1)).is_equal(3)


func test_precision_tools_preserve_imported_heights_and_exact_level() -> void:
	var h: MHCraftHole = MHCraftHole.new(8, 8)
	h.set_height_mm_tile(3, 3, 650)
	h.begin_stroke()
	h.raise_disc_mm(3, 3, 0, 250)
	assert_int(h.get_height_mm(3, 3)).is_equal(900)
	h.level_disc_mm(4, 3, 0, h.get_height_mm(3, 3))
	assert_int(h.get_height_mm(4, 3)).is_equal(900)
	h.commit_stroke()
	h.undo()
	assert_int(h.get_height_mm(3, 3)).is_equal(650)
	assert_int(h.get_height_mm(4, 3)).is_equal(0)
	h.redo()
	assert_int(h.get_height_mm(4, 3)).is_equal(900)
	h.raise_disc(3, 3, 0, 1)
	assert_int(h.get_height_mm(3, 3)).is_equal(1900)
	h.raise_disc_mm(3, 3, 0, -99999)
	assert_int(h.get_height_mm(3, 3)).is_equal(-4000)


func test_smoothing_retains_submetre_shape_and_cancels_exactly() -> void:
	var h: MHCraftHole = MHCraftHole.new(8, 8)
	h.set_height_mm_tile(3, 3, 900)
	h.begin_stroke()
	h.smooth_disc(3, 3, 0)
	assert_int(h.get_height_mm(3, 3)).is_equal(100)
	h.cancel_stroke()
	assert_int(h.get_height_mm(3, 3)).is_equal(900)


func test_markers_and_terrain_share_one_history_and_cancel_boundary() -> void:
	var h: MHCraftHole = MHCraftHole.new(8, 8)
	h.add_tee(1, 1)
	h.add_pin(4, 4)
	h.begin_stroke()
	h.move_tee(2, 2)
	h.set_pin(0, 5, 5)
	h.paint_tile(5, 5, MHCraftHole.Surface.GREEN)
	h.commit_stroke()
	assert_int(h.undo_count()).is_equal(1)
	h.undo()
	assert_array(h.tees).is_equal([Vector2i(1, 1)])
	assert_array(h.pins).is_equal([Vector2i(4, 4)])
	assert_int(h.get_surface(5, 5)).is_equal(MHCraftHole.Surface.ROUGH)
	h.redo()
	assert_array(h.pins).is_equal([Vector2i(5, 5)])
	assert_int(h.get_surface(5, 5)).is_equal(MHCraftHole.Surface.GREEN)
	h.begin_stroke()
	h.remove_pin(0)
	h.move_tee(0, 0)
	h.cancel_stroke()
	assert_array(h.tees).is_equal([Vector2i(2, 2)])
	assert_array(h.pins).is_equal([Vector2i(5, 5)])


func test_pin_edit_rejects_duplicate_and_fifth_without_erasing_existing_pins() -> void:
	var h: MHCraftHole = MHCraftHole.new(8, 8)
	for i: int in range(4):
		assert_bool(h.set_pin(i, i, 4)).is_true()
	var original: Array = h.pins.duplicate()
	assert_bool(h.set_pin(4, 5, 4)).is_false()
	assert_bool(h.set_pin(0, 1, 4)).is_false()
	assert_array(h.pins).is_equal(original)
	assert_int(h.add_pin(0, 4)).is_equal(-1)
	h.begin_stroke()
	assert_bool(h.remove_pin(1)).is_true()
	h.commit_stroke()
	assert_int(h.last_changed_tiles().size()).is_equal(0)
	h.undo()
	assert_array(h.pins).is_equal(original)
	var restored: MHCraftHole = MHCraftHole.from_dict(h.to_dict())
	assert_object(restored).is_not_null()
	assert_array(restored.pins).is_equal(original)
