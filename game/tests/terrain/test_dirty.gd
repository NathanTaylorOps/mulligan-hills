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
