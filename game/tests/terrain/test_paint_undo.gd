extends GdUnitTestSuite
## 11-layer splat map and undoable paint strokes. NOT YET RUN.

const SCHEMA_NAMES: Array = [
	"rough", "fairway", "first_cut", "green", "fringe", "tee",
	"bunker_sand", "water", "path", "waste", "dirt",
]


func _make_editor() -> MHTerrainEditor:
	var g := MHHeightGrid.new(64, 48)
	g.fill_lcg_noise(5, 500)
	return MHTerrainEditor.new(g)


func _paint(e: MHTerrainEditor, layer: int, pts: Array, strength: int = 900) -> int:
	e.set_paint_brush(layer, 6, strength)
	assert_bool(e.begin_stroke()).is_true()
	for p in pts:
		e.apply_brush_at(p.x, p.y)
	return e.end_stroke()


func _marks_clear(e: MHTerrainEditor) -> bool:
	for i in range(e.splat.stroke_mark.size()):
		if e.splat.stroke_mark[i] != 0:
			return false
	for i in range(e.grid.stroke_mark.size()):
		if e.grid.stroke_mark[i] != 0:
			return false
	return true


func test_layer_names_and_order_match_schema() -> void:
	assert_int(MHSplatMap.LAYER_COUNT).is_equal(11)
	assert_int(MHSplatMap.LAYER_NAMES.size()).is_equal(11)
	for i in range(11):
		assert_str(MHSplatMap.LAYER_NAMES[i]).is_equal(SCHEMA_NAMES[i])
		assert_str(MHSplatMap.layer_name(i)).is_equal(SCHEMA_NAMES[i])
		assert_int(MHSplatMap.layer_from_name(SCHEMA_NAMES[i])).is_equal(i)
	assert_int(MHSplatMap.layer_from_name("sand")).is_equal(-1)
	assert_str(MHSplatMap.layer_name(11)).is_equal("")
	assert_int(MHSplatMap.Layer.ROUGH).is_equal(0)
	assert_int(MHSplatMap.Layer.BUNKER_SAND).is_equal(6)
	assert_int(MHSplatMap.Layer.DIRT).is_equal(10)


func test_default_map_is_all_rough_and_sized_for_11_layers() -> void:
	var m := MHSplatMap.new(7, 5)
	assert_int(m.bytes.size()).is_equal(7 * 5 * 11)
	for t in range(35):
		assert_int(m.bytes[t * 11]).is_equal(255)
		for l in range(1, 11):
			assert_int(m.bytes[t * 11 + l]).is_equal(0)


func test_packed_texture_mapping_three_rgba_planes() -> void:
	var m := MHSplatMap.new(3, 3)
	m.paint_disc(1, 1, 1, MHSplatMap.Layer.WATER, 1000)  # layer 7 = plane 1 channel 3
	assert_int(m.get_packed(4, 1, 3)).is_equal(255)
	assert_int(m.get_packed(4, 0, 0)).is_equal(0)
	assert_int(m.get_packed(4, 2, 3)).is_equal(0)  # unused channel is always 0
	m.paint_disc(1, 1, 1, MHSplatMap.Layer.DIRT, 1000)  # layer 10 = plane 2 channel 2
	assert_int(m.get_packed(4, 2, 2)).is_equal(255)


func test_paint_full_strength_is_one_hot_at_centre_for_every_layer() -> void:
	for l in range(11):
		var m := MHSplatMap.new(21, 21)
		m.paint_disc(10, 10, 5, l, 1000)
		for c in range(11):
			assert_int(m.get_weight(10, 10, c)).is_equal(255 if c == l else 0)


func test_invalid_layer_paints_nothing() -> void:
	var m := MHSplatMap.new(9, 9)
	var h: int = m.hash_fnv1a()
	assert_bool(m.paint_disc(4, 4, 3, 11, 1000).has_area()).is_false()
	assert_bool(m.paint_disc(4, 4, 3, -1, 1000).has_area()).is_false()
	assert_int(m.hash_fnv1a()).is_equal(h)


func test_legacy_mapping_of_four_layers() -> void:
	var rgba := PackedByteArray([10, 20, 30, 40, 1, 2, 3, 4])
	var m: MHSplatMap = MHSplatMap.from_legacy_rgba(2, 1, rgba)
	assert_int(m.get_weight(0, 0, MHSplatMap.Layer.FAIRWAY)).is_equal(10)
	assert_int(m.get_weight(0, 0, MHSplatMap.Layer.ROUGH)).is_equal(20)
	assert_int(m.get_weight(0, 0, MHSplatMap.Layer.BUNKER_SAND)).is_equal(30)
	assert_int(m.get_weight(0, 0, MHSplatMap.Layer.GREEN)).is_equal(40)
	assert_int(m.get_weight(1, 0, MHSplatMap.Layer.GREEN)).is_equal(4)
	assert_int(m.get_weight(1, 0, MHSplatMap.Layer.WATER)).is_equal(0)
	assert_int(MHSplatMap.legacy_layer_to_layer(0)).is_equal(MHSplatMap.Layer.FAIRWAY)
	assert_int(MHSplatMap.legacy_layer_to_layer(1)).is_equal(MHSplatMap.Layer.ROUGH)
	assert_int(MHSplatMap.legacy_layer_to_layer(2)).is_equal(MHSplatMap.Layer.BUNKER_SAND)
	assert_int(MHSplatMap.legacy_layer_to_layer(3)).is_equal(MHSplatMap.Layer.GREEN)


func test_paint_stroke_undo_redo_restores_splat_exactly() -> void:
	var e := _make_editor()
	var s0: PackedByteArray = e.splat.bytes.duplicate()
	var h0: PackedInt32Array = e.grid.heights.duplicate()
	var n: int = _paint(e, MHSplatMap.Layer.WATER, [Vector2i(20, 20), Vector2i(24, 21), Vector2i(28, 22)])
	assert_int(n).is_greater(0)
	var s1: PackedByteArray = e.splat.bytes.duplicate()
	assert_bool(s1 != s0).is_true()
	assert_bool(e.grid.heights == h0).is_true()
	assert_int(e.undo_stack.undo_count()).is_equal(1)
	assert_bool(e.undo()).is_true()
	assert_bool(e.splat.bytes == s0).is_true()
	assert_bool(e.redo()).is_true()
	assert_bool(e.splat.bytes == s1).is_true()
	assert_bool(e.redo()).is_false()
	assert_bool(_marks_clear(e)).is_true()


func test_paint_undo_chain_returns_to_start_with_overlapping_strokes() -> void:
	var e := _make_editor()
	var s0: PackedByteArray = e.splat.bytes.duplicate()
	_paint(e, MHSplatMap.Layer.FAIRWAY, [Vector2i(30, 20), Vector2i(34, 20)])
	_paint(e, MHSplatMap.Layer.GREEN, [Vector2i(32, 20)], 500)
	_paint(e, MHSplatMap.Layer.BUNKER_SAND, [Vector2i(0, 0), Vector2i(64, 48)])
	assert_int(e.undo_stack.undo_count()).is_equal(3)
	while e.undo():
		pass
	assert_bool(e.splat.bytes == s0).is_true()
	assert_int(e.splat.hash_fnv1a()).is_equal(MHSplatMap.new(65, 49).hash_fnv1a())


func test_paint_cancel_rolls_back_with_no_residue() -> void:
	var e := _make_editor()
	_paint(e, MHSplatMap.Layer.PATH, [Vector2i(10, 10)])
	assert_bool(e.undo()).is_true()
	assert_bool(e.redo()).is_true()
	assert_bool(e.undo()).is_true()  # one redo entry exists
	var redo_before: int = e.undo_stack.redo_count()
	var undo_before: int = e.undo_stack.undo_count()
	var pre: PackedByteArray = e.splat.bytes.duplicate()
	e.set_paint_brush(MHSplatMap.Layer.WASTE, 6, 800)
	assert_bool(e.begin_stroke()).is_true()
	for i in range(4):
		e.apply_brush_at(40, 30)
		e.apply_brush_at(43, 31)
	assert_bool(e.splat.bytes != pre).is_true()
	e.cancel_stroke()
	assert_bool(e.splat.bytes == pre).is_true()
	assert_bool(e.is_stroke_open()).is_false()
	assert_int(e.undo_stack.redo_count()).is_equal(redo_before)
	assert_int(e.undo_stack.undo_count()).is_equal(undo_before)
	assert_bool(_marks_clear(e)).is_true()
	assert_int(_paint(e, MHSplatMap.Layer.WASTE, [Vector2i(40, 30)])).is_greater(0)


func test_paint_cancel_marks_cells_dirty() -> void:
	var e := _make_editor()
	e.set_paint_brush(MHSplatMap.Layer.WATER, 4, 1000)
	e.begin_stroke()
	e.apply_brush_at(40, 30)
	e.dirty.take()
	e.cancel_stroke()
	assert_int(e.dirty.dirty_count()).is_greater(0)


func test_paint_stroke_marks_dirty_and_undo_redo_mark_dirty() -> void:
	var e := _make_editor()
	e.dirty.take()
	_paint(e, MHSplatMap.Layer.TEE, [Vector2i(10, 10)])
	assert_int(e.dirty.dirty_count()).is_greater(0)
	e.dirty.take()
	e.undo()
	assert_int(e.dirty.dirty_count()).is_greater(0)
	e.dirty.take()
	e.redo()
	assert_int(e.dirty.dirty_count()).is_greater(0)


func test_paint_that_changes_nothing_is_discarded_and_keeps_redo() -> void:
	var e := _make_editor()
	_paint(e, MHSplatMap.Layer.WATER, [Vector2i(10, 10)])
	e.undo()
	assert_int(e.undo_stack.redo_count()).is_equal(1)
	# map is all rough again: painting rough at full strength changes nothing
	assert_int(_paint(e, MHSplatMap.Layer.ROUGH, [Vector2i(30, 30)], 1000)).is_equal(0)
	assert_int(e.undo_stack.undo_count()).is_equal(0)
	assert_int(e.undo_stack.redo_count()).is_equal(1)
	assert_bool(_marks_clear(e)).is_true()


func test_new_paint_stroke_clears_redo() -> void:
	var e := _make_editor()
	_paint(e, MHSplatMap.Layer.WATER, [Vector2i(10, 10)])
	e.undo()
	_paint(e, MHSplatMap.Layer.DIRT, [Vector2i(50, 30)])
	assert_int(e.undo_stack.redo_count()).is_equal(0)


func test_mixed_height_and_paint_stroke_undoes_both() -> void:
	var e := _make_editor()
	var h0: PackedInt32Array = e.grid.heights.duplicate()
	var s0: PackedByteArray = e.splat.bytes.duplicate()
	assert_bool(e.begin_stroke()).is_true()
	e.set_brush(MHBrush.Mode.RAISE, 6, 300)
	e.apply_brush_at(20, 20)
	e.set_paint_brush(MHSplatMap.Layer.FRINGE, 6, 900)
	e.apply_brush_at(22, 20)
	assert_int(e.end_stroke()).is_greater(0)
	assert_bool(e.grid.heights != h0).is_true()
	assert_bool(e.splat.bytes != s0).is_true()
	assert_int(e.undo_stack.undo_count()).is_equal(1)
	e.undo()
	assert_bool(e.grid.heights == h0).is_true()
	assert_bool(e.splat.bytes == s0).is_true()


func test_paint_stroke_does_not_change_heights() -> void:
	var e := _make_editor()
	var h: int = e.grid.hash_fnv1a()
	_paint(e, MHSplatMap.Layer.WATER, [Vector2i(20, 20)])
	assert_int(e.grid.hash_fnv1a()).is_equal(h)
	var s: MHStroke = e.undo_stack.undo(e.grid, e.splat)
	assert_int(s.height_changed_count()).is_equal(0)
	assert_int(s.splat_changed_count()).is_greater(0)


func test_paint_clipped_at_grid_corners_undoes_cleanly() -> void:
	var e := _make_editor()
	var s0: PackedByteArray = e.splat.bytes.duplicate()
	_paint(e, MHSplatMap.Layer.WATER, [Vector2i(0, 0), Vector2i(64, 48), Vector2i(0, 48), Vector2i(64, 0)])
	assert_int(e.splat.get_weight(64, 48, MHSplatMap.Layer.WATER)).is_greater(0)
	e.undo()
	assert_bool(e.splat.bytes == s0).is_true()


func test_undo_bytes_accounting_includes_splat_diff() -> void:
	var e := _make_editor()
	var n: int = _paint(e, MHSplatMap.Layer.WATER, [Vector2i(20, 20)])
	assert_int(e.undo_stack.undo_bytes()).is_equal(n * (4 + 2 * 11))
	e.undo()
	assert_int(e.undo_stack.undo_bytes()).is_equal(0)


func test_paint_is_deterministic() -> void:
	var a := _make_editor()
	var b := _make_editor()
	for e in [a, b]:
		_paint(e, MHSplatMap.Layer.FIRST_CUT, [Vector2i(20, 20), Vector2i(26, 24)], 640)
		_paint(e, MHSplatMap.Layer.FAIRWAY, [Vector2i(22, 22)], 333)
	assert_int(a.splat.hash_fnv1a()).is_equal(b.splat.hash_fnv1a())
	assert_bool(a.splat.bytes == b.splat.bytes).is_true()


func test_legacy_direct_paint_is_not_undoable() -> void:
	var e := _make_editor()
	e.paint_splat_at(20, 20, 5, MHSplatMap.Layer.WATER, 1000)
	assert_int(e.undo_stack.undo_count()).is_equal(0)
	assert_int(e.splat.get_weight(20, 20, MHSplatMap.Layer.WATER)).is_equal(255)


func test_apply_dab_in_paint_mode_does_not_touch_heights() -> void:
	var g := MHHeightGrid.new(16, 16)
	g.fill_lcg_noise(1, 300)
	var h: int = g.hash_fnv1a()
	MHBrush.apply_dab(g, MHBrush.Mode.PAINT, 8, 8, 4, 500, 0, null)
	assert_int(g.hash_fnv1a()).is_equal(h)
