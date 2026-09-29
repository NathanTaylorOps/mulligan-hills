extends GdUnitTestSuite
## Dirty rectangle tracking. Grid 512 cells (513 samples), chunk 32. NOT YET RUN.


func _t() -> MHDirtyTracker:
	return MHDirtyTracker.new(513, 513, 32)


func test_chunk_counts() -> void:
	var t: MHDirtyTracker = _t()
	assert_int(t.chunks_x).is_equal(16)
	assert_int(t.chunk_count()).is_equal(256)


func test_interior_cell_dirties_one_chunk() -> void:
	var t: MHDirtyTracker = _t()
	t.mark_rect(50, 50, 50, 50)
	assert_int(t.dirty_count()).is_equal(1)
	var e: PackedInt32Array = t.take()
	assert_int(e.size()).is_equal(5)
	assert_int(e[0]).is_equal(1 * 16 + 1)
	assert_int(e[1]).is_equal(50)
	assert_int(e[4]).is_equal(50)


func test_border_cell_dirties_neighbour_chunks() -> void:
	var t: MHDirtyTracker = _t()
	t.mark_rect(32, 32, 32, 32)  # shared vertex of 4 chunks
	assert_int(t.dirty_count()).is_equal(4)
	t.take()
	t.mark_rect(31, 100, 31, 100)  # border texel of chunk 1 (x 31..65) and inside chunk 0
	assert_int(t.dirty_count()).is_equal(2)


func test_take_clears_and_is_ordered() -> void:
	var t: MHDirtyTracker = _t()
	t.mark_rect(200, 200, 200, 200)
	t.mark_rect(5, 5, 5, 5)
	var e: PackedInt32Array = t.take()
	assert_int(e.size()).is_equal(10)
	assert_int(e[0]).is_equal((200 / 32) * 16 + (200 / 32))
	assert_int(e[5]).is_equal(0)
	assert_int(t.dirty_count()).is_equal(0)
	assert_bool(t.is_dirty(0)).is_false()
	assert_int(t.take().size()).is_equal(0)


func test_rects_union_within_chunk() -> void:
	var t: MHDirtyTracker = _t()
	t.mark_rect(40, 40, 42, 42)
	t.mark_rect(50, 45, 52, 47)
	var r: Rect2i = t.peek_rect(1 * 16 + 1)
	assert_int(r.position.x).is_equal(40)
	assert_int(r.position.y).is_equal(40)
	assert_int(r.end.x).is_equal(53)
	assert_int(r.end.y).is_equal(48)


func test_out_of_grid_is_clipped() -> void:
	var t: MHDirtyTracker = _t()
	t.mark_rect(-50, -50, -10, -10)
	assert_int(t.dirty_count()).is_equal(0)
	t.mark_rect(500, 500, 900, 900)
	assert_bool(t.dirty_count() >= 1).is_true()


func test_mark_all_covers_every_chunk() -> void:
	var t: MHDirtyTracker = _t()
	t.mark_all()
	assert_int(t.dirty_count()).is_equal(256)


func test_editor_stroke_marks_footprint_chunks_only() -> void:
	var e := MHTerrainEditor.new(MHHeightGrid.new(512, 512))
	e.set_brush(MHBrush.Mode.RAISE, 4, 100)
	e.begin_stroke()
	e.apply_brush_at(112, 112)
	e.end_stroke()
	assert_int(e.dirty.dirty_count()).is_equal(1)


# ---- 600 x 400 cells (601 x 401 samples), chunk 32: 19 x 13 chunks, last column/row partial ----

func _t600() -> MHDirtyTracker:
	return MHDirtyTracker.new(601, 401, 32)


func test_600x400_chunk_counts() -> void:
	var t: MHDirtyTracker = _t600()
	assert_int(t.chunks_x).is_equal(19)
	assert_int(t.chunks_y).is_equal(13)
	assert_int(t.chunk_count()).is_equal(247)


func test_600x400_last_sample_dirties_only_last_chunk() -> void:
	var t: MHDirtyTracker = _t600()
	t.mark_rect(600, 400, 600, 400)
	assert_int(t.dirty_count()).is_equal(1)
	var e: PackedInt32Array = t.take()
	assert_int(e[0]).is_equal(12 * 19 + 18)
	assert_int(e[1]).is_equal(600)
	assert_int(e[2]).is_equal(400)
	assert_int(e[3]).is_equal(600)
	assert_int(e[4]).is_equal(400)


func test_600x400_border_sample_of_partial_chunk_dirties_two_chunks() -> void:
	var t: MHDirtyTracker = _t600()
	t.mark_rect(575, 10, 575, 10)  # x 575 = 18*32 - 1: border texel of chunk 18, inside chunk 17
	assert_int(t.dirty_count()).is_equal(2)
	t.take()
	t.mark_rect(574, 10, 574, 10)
	assert_int(t.dirty_count()).is_equal(1)
	t.take()
	t.mark_rect(10, 383, 10, 383)  # y 383 = 12*32 - 1
	assert_int(t.dirty_count()).is_equal(2)


func test_600x400_mark_all_covers_every_chunk_and_stays_in_grid() -> void:
	var t: MHDirtyTracker = _t600()
	t.mark_all()
	assert_int(t.dirty_count()).is_equal(247)
	var e: PackedInt32Array = t.take()
	assert_int(e.size()).is_equal(247 * 5)
	var max_x: int = 0
	var max_y: int = 0
	for k in range(247):
		assert_bool(e[k * 5 + 1] >= 0 and e[k * 5 + 2] >= 0).is_true()
		assert_bool(e[k * 5 + 3] <= 600 and e[k * 5 + 4] <= 400).is_true()
		max_x = maxi(max_x, e[k * 5 + 3])
		max_y = maxi(max_y, e[k * 5 + 4])
	assert_int(max_x).is_equal(600)
	assert_int(max_y).is_equal(400)


func test_600x400_editor_stroke_at_far_corner_marks_one_chunk() -> void:
	var e := MHTerrainEditor.new(MHHeightGrid.new(600, 400), null, 32)
	e.set_brush(MHBrush.Mode.RAISE, 4, 100)
	e.begin_stroke()
	e.apply_brush_at(598, 398)
	e.end_stroke()
	assert_int(e.dirty.chunk_count()).is_equal(247)
	assert_int(e.dirty.dirty_count()).is_equal(1)
	assert_bool(e.dirty.is_dirty(12 * 19 + 18)).is_true()


func test_600x400_paint_stroke_at_far_corner_marks_one_chunk_and_undo_marks_again() -> void:
	var e := MHTerrainEditor.new(MHHeightGrid.new(600, 400), null, 32)
	e.set_paint_brush(MHSplatMap.Layer.WATER, 4, 1000)
	e.begin_stroke()
	e.apply_brush_at(598, 398)
	e.end_stroke()
	assert_int(e.dirty.dirty_count()).is_equal(1)
	e.dirty.take()
	assert_bool(e.undo()).is_true()
	assert_int(e.dirty.dirty_count()).is_equal(1)
