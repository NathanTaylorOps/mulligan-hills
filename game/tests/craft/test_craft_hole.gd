extends GdUnitTestSuite
## MHCraftHole: painting, heights, tees, pins, undo. Pure logic. NOT YET RUN in Godot.


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
	assert_int(h.tile_at_yd(-1000, 5).x).is_equal(-1)


func test_paint_and_disc_and_bounds() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.paint_tile(5, 5, MHCraftHole.Surface.FAIRWAY)
	assert_int(h.get_surface(5, 5)).is_equal(MHCraftHole.Surface.FAIRWAY)
	h.paint_tile(-1, 5, MHCraftHole.Surface.FAIRWAY) # ignored
	h.paint_disc(10, 10, 1, MHCraftHole.Surface.WATER)
	assert_int(h.count_surface(MHCraftHole.Surface.WATER)).is_equal(5) # centre plus four neighbours
	assert_int(h.get_surface(99, 99)).is_equal(MHCraftHole.Surface.OUT_OF_BOUNDS)


func test_heights_are_clamped_to_the_range() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	h.set_height_tile(3, 3, 99)
	assert_int(h.get_height(3, 3)).is_equal(MHCraftHole.HEIGHT_MAX_M)
	h.set_height_tile(3, 3, -99)
	assert_int(h.get_height(3, 3)).is_equal(MHCraftHole.HEIGHT_MIN_M)
	h.raise_disc(8, 8, 0, 3)
	h.raise_disc(8, 8, 0, 20)
	assert_int(h.get_height(8, 8)).is_equal(MHCraftHole.HEIGHT_MAX_M)


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


func test_up_to_three_tees_and_four_pins_rotate_by_round() -> void:
	var h: MHCraftHole = MHCraftHole.new(24, 40)
	assert_int(h.add_tee(11, 0)).is_equal(0)
	assert_int(h.add_tee(11, 2)).is_equal(1)
	assert_int(h.add_tee(11, 4)).is_equal(2)
	assert_int(h.add_tee(11, 6)).is_equal(-1) # only three tee boxes
	assert_int(h.pin_for_round(0)).is_equal(-1) # no pins yet
	for i: int in range(4):
		assert_int(h.add_pin(10 + i, 30)).is_equal(i)
	assert_int(h.add_pin(10, 31)).is_equal(-1)
	assert_int(h.pin_for_round(0)).is_equal(0)
	assert_int(h.pin_for_round(5)).is_equal(1)
	assert_int(h.pin_for_round(-1)).is_equal(3)
