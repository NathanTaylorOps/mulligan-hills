extends GdUnitTestSuite
## Regression coverage for the shared world <-> exact-hole terrain bridge.

const ORIGIN: Vector2i = Vector2i(480, 340)


func _editor() -> MHTerrainEditor:
	var grid: MHHeightGrid = MHHeightGrid.new(128, 128, 1000)
	return MHTerrainEditor.new(grid, MHSplatMap.new(grid.samples_x, grid.samples_y), 32)


func _sample_for(hole: MHCraftHole, editor: MHTerrainEditor, c: int, r: int) -> Vector2i:
	var centre: Vector2i = hole.tile_centre_yd(c, r)
	return Vector2i(
		MHRMath.rdiv(MHCourseLayout.world_mm(ORIGIN.x, centre.x * 100), editor.grid.cell_size_mm),
		MHRMath.rdiv(MHCourseLayout.world_mm(ORIGIN.y, centre.y * 100), editor.grid.cell_size_mm))


func test_world_water_and_submetre_height_enter_craft_grid() -> void:
	var editor: MHTerrainEditor = _editor()
	var hole: MHCraftHole = MHCraftHole.new(24, 40)
	var tile: Vector2i = Vector2i(8, 12)
	var sample: Vector2i = _sample_for(hole, editor, tile.x, tile.y)
	editor.set_paint_brush(MHSplatMap.Layer.WATER, 1, 1000)
	assert_bool(editor.begin_stroke()).is_true()
	editor.apply_brush_at(sample.x, sample.y)
	editor.end_stroke()
	editor.set_brush(MHBrush.Mode.RAISE, 1, 700)
	assert_bool(editor.begin_stroke()).is_true()
	editor.apply_brush_at(sample.x, sample.y)
	editor.end_stroke()

	MHCraftTerrainBridge.sync_from_world(hole, editor, ORIGIN)
	assert_int(hole.get_surface(tile.x, tile.y)).is_equal(MHCraftHole.Surface.WATER)
	assert_int(hole.get_height_mm(tile.x, tile.y)).is_equal(700)


func test_craft_path_and_height_write_back_to_world() -> void:
	var editor: MHTerrainEditor = _editor()
	var hole: MHCraftHole = MHCraftHole.new(24, 40)
	var tile: Vector2i = Vector2i(9, 10)
	hole.paint_tile(tile.x, tile.y, MHCraftHole.Surface.PATH)
	hole.set_height_mm_tile(tile.x, tile.y, 1350)
	var sample: Vector2i = _sample_for(hole, editor, tile.x, tile.y)

	assert_bool(MHCraftTerrainBridge.sync_to_world(hole, editor, ORIGIN, false)).is_true()
	assert_int(editor.grid.get_h_clamped(sample.x, sample.y)).is_equal(1350)
	assert_int(editor.splat.get_weight(sample.x, sample.y, MHSplatMap.Layer.PATH)).is_equal(255)
	assert_int(editor.splat.get_weight(sample.x, sample.y, MHSplatMap.Layer.ROUGH)).is_equal(0)


func test_legacy_overlay_keeps_starter_fairway_but_imports_nonrough_world_edits() -> void:
	var editor: MHTerrainEditor = _editor()
	var hole: MHCraftHole = MHCraftHole.new(24, 40)
	hole.paint_rect(10, 0, 13, 29, MHCraftHole.Surface.FAIRWAY)
	var water_tile: Vector2i = Vector2i(6, 8)
	var water_sample: Vector2i = _sample_for(hole, editor, water_tile.x, water_tile.y)
	editor.set_paint_brush(MHSplatMap.Layer.WATER, 1, 1000)
	editor.begin_stroke()
	editor.apply_brush_at(water_sample.x, water_sample.y)
	editor.end_stroke()

	MHCraftTerrainBridge.overlay_nondefault_from_world(hole, editor, ORIGIN)
	assert_int(hole.get_surface(11, 10)).is_equal(MHCraftHole.Surface.FAIRWAY)
	assert_int(hole.get_surface(water_tile.x, water_tile.y)).is_equal(MHCraftHole.Surface.WATER)


func test_world_rect_sync_only_replaces_tiles_near_that_edit() -> void:
	var editor: MHTerrainEditor = _editor()
	var hole: MHCraftHole = MHCraftHole.new(24, 40)
	hole.paint_tile(4, 4, MHCraftHole.Surface.DEEP_ROUGH)
	var target: Vector2i = Vector2i(18, 20)
	var sample: Vector2i = _sample_for(hole, editor, target.x, target.y)
	editor.set_paint_brush(MHSplatMap.Layer.PATH, 1, 1000)
	editor.begin_stroke()
	editor.apply_brush_at(sample.x, sample.y)
	editor.end_stroke()

	MHCraftTerrainBridge.sync_from_world_rect(hole, editor, ORIGIN, Rect2i(sample.x - 1, sample.y - 1, 3, 3))
	assert_int(hole.get_surface(target.x, target.y)).is_equal(MHCraftHole.Surface.PATH)
	assert_int(hole.get_surface(4, 4)).is_equal(MHCraftHole.Surface.DEEP_ROUGH)


func test_nondefault_seed_does_not_erase_neighbouring_authored_turf() -> void:
	var editor: MHTerrainEditor = _editor()
	var first: MHCraftHole = MHCraftHole.new(24, 40)
	var second: MHCraftHole = MHCraftHole.new(24, 40)
	var first_tile: Vector2i = Vector2i(4, 4)
	var second_tile: Vector2i = Vector2i(16, 18)
	first.paint_tile(first_tile.x, first_tile.y, MHCraftHole.Surface.FAIRWAY)
	second.paint_tile(second_tile.x, second_tile.y, MHCraftHole.Surface.GREEN)
	assert_bool(MHCraftTerrainBridge.sync_nondefault_to_world(first, editor, ORIGIN, false)).is_true()
	var first_sample: Vector2i = _sample_for(first, editor, first_tile.x, first_tile.y)
	assert_int(editor.splat.get_weight(first_sample.x, first_sample.y, MHSplatMap.Layer.FAIRWAY)).is_equal(255)

	# The second hole is rough at first_tile. A full-envelope sync would erase the
	# first hole there; authored-only seeding must leave it intact.
	assert_bool(MHCraftTerrainBridge.sync_nondefault_to_world(second, editor, ORIGIN, false)).is_true()
	assert_int(editor.splat.get_weight(first_sample.x, first_sample.y, MHSplatMap.Layer.FAIRWAY)).is_equal(255)
	var second_sample: Vector2i = _sample_for(second, editor, second_tile.x, second_tile.y)
	assert_int(editor.splat.get_weight(second_sample.x, second_sample.y, MHSplatMap.Layer.GREEN)).is_equal(255)
