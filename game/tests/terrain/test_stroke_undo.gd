extends GdUnitTestSuite
## Stroke apply, undo, redo, cancel rollback. NOT YET RUN.


func _make_editor() -> MHTerrainEditor:
	var g := MHHeightGrid.new(64, 64)
	g.fill_lcg_noise(5, 500)
	var e := MHTerrainEditor.new(g)
	e.set_brush(MHBrush.Mode.RAISE, 6, 200)
	return e


func _stroke(e: MHTerrainEditor, pts: Array) -> int:
	assert_bool(e.begin_stroke()).is_true()
	for p in pts:
		e.apply_brush_at(p.x, p.y)
	return e.end_stroke()


func test_stroke_apply_changes_grid_and_counts_cells() -> void:
	var e := _make_editor()
	var before: int = e.grid.hash_fnv1a()
	var n: int = _stroke(e, [Vector2i(20, 20), Vector2i(24, 20)])
	assert_int(n).is_greater(0)
	assert_bool(e.grid.hash_fnv1a() != before).is_true()
	assert_int(e.undo_stack.undo_count()).is_equal(1)


func test_undo_restores_exactly_and_redo_reapplies() -> void:
	var e := _make_editor()
	var h0: PackedInt32Array = e.grid.heights.duplicate()
	_stroke(e, [Vector2i(30, 30), Vector2i(33, 31), Vector2i(36, 32)])
	var h1: PackedInt32Array = e.grid.heights.duplicate()
	assert_bool(e.undo()).is_true()
	assert_bool(e.grid.heights == h0).is_true()
	assert_bool(e.redo()).is_true()
	assert_bool(e.grid.heights == h1).is_true()
	assert_bool(e.redo()).is_false()


func test_undo_chain_of_many_strokes_returns_to_start() -> void:
	var e := _make_editor()
	var h0: PackedInt32Array = e.grid.heights.duplicate()
	e.set_brush(MHBrush.Mode.RAISE, 8, 300)
	_stroke(e, [Vector2i(20, 20)])
	e.set_brush(MHBrush.Mode.SMOOTH, 8, 700)
	_stroke(e, [Vector2i(20, 20), Vector2i(22, 22)])
	e.set_brush(MHBrush.Mode.FLATTEN, 8, 900)
	_stroke(e, [Vector2i(21, 21)])
	e.set_brush(MHBrush.Mode.LOWER, 8, 300)
	_stroke(e, [Vector2i(0, 0), Vector2i(64, 64)])
	while e.undo():
		pass
	assert_bool(e.grid.heights == h0).is_true()


func test_cancel_rolls_back_with_no_residue() -> void:
	var e := _make_editor()
	_stroke(e, [Vector2i(10, 10)])
	var before: PackedInt32Array = e.grid.heights.duplicate()
	var undo_before: int = e.undo_stack.undo_count()
	assert_bool(e.undo()).is_true()
	assert_bool(e.redo()).is_true()  # leaves redo empty; now build a redo entry
	assert_bool(e.undo()).is_true()
	var redo_before: int = e.undo_stack.redo_count()
	var pre_cancel: PackedInt32Array = e.grid.heights.duplicate()
	assert_bool(e.begin_stroke()).is_true()
	# overlapping dabs on the same cells: first-touch value must be what is restored
	for i in range(5):
		e.apply_brush_at(40, 40)
		e.apply_brush_at(43, 41)
	assert_bool(e.grid.heights != pre_cancel).is_true()
	e.cancel_stroke()
	assert_bool(e.grid.heights == pre_cancel).is_true()
	assert_bool(e.is_stroke_open()).is_false()
	assert_int(e.undo_stack.redo_count()).is_equal(redo_before)
	assert_int(e.undo_stack.undo_count()).is_equal(undo_before - 1)
	# scratch marks fully cleared (no residue): every byte zero
	var all_zero: bool = true
	for i in range(e.grid.stroke_mark.size()):
		if e.grid.stroke_mark[i] != 0:
			all_zero = false
			break
	assert_bool(all_zero).is_true()
	# and a fresh stroke afterwards behaves normally
	assert_int(_stroke(e, [Vector2i(40, 40)])).is_greater(0)
	assert_bool(before.size() == e.grid.heights.size()).is_true()


func test_cancel_marks_cells_dirty_so_renderer_reverts() -> void:
	var e := _make_editor()
	e.dirty.take()
	e.begin_stroke()
	e.apply_brush_at(40, 40)
	e.dirty.take()
	e.cancel_stroke()
	assert_int(e.dirty.dirty_count()).is_greater(0)


func test_new_stroke_clears_redo() -> void:
	var e := _make_editor()
	_stroke(e, [Vector2i(10, 10)])
	e.undo()
	assert_int(e.undo_stack.redo_count()).is_equal(1)
	_stroke(e, [Vector2i(50, 50)])
	assert_int(e.undo_stack.redo_count()).is_equal(0)


func test_empty_stroke_is_discarded_and_keeps_redo() -> void:
	var e := _make_editor()
	_stroke(e, [Vector2i(10, 10)])
	e.undo()
	e.begin_stroke()
	assert_int(e.end_stroke()).is_equal(0)
	assert_int(e.undo_stack.redo_count()).is_equal(1)
	assert_int(e.undo_stack.undo_count()).is_equal(0)


func test_cannot_undo_or_begin_twice_during_open_stroke() -> void:
	var e := _make_editor()
	_stroke(e, [Vector2i(10, 10)])
	assert_bool(e.begin_stroke()).is_true()
	assert_bool(e.begin_stroke()).is_false()
	assert_bool(e.undo()).is_false()
	e.cancel_stroke()


func test_apply_without_stroke_is_ignored() -> void:
	var e := _make_editor()
	var h: int = e.grid.hash_fnv1a()
	e.apply_brush_at(10, 10)
	assert_int(e.grid.hash_fnv1a()).is_equal(h)


func test_undo_stack_trims_by_count() -> void:
	var e := _make_editor()
	e.undo_stack.max_strokes = 3
	for i in range(6):
		_stroke(e, [Vector2i(10 + i * 4, 10)])
	assert_int(e.undo_stack.undo_count()).is_equal(3)
