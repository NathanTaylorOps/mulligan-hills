class_name MHCraftTerrainBridge
extends RefCounted
## Keeps the whole-map terrain editor and the exact-hole craft grid in the same world.
##
## The terrain editor owns the rendered 1 m height/splat map. MHCraftHole owns the
## hole-local 2 yd semantic grid used by rating. This bridge is the only conversion
## boundary between them; switching editor views must never create a second unrelated
## golf course.

static func overlay_nondefault_from_world(hole: MHCraftHole, editor: MHTerrainEditor, origin_dm: Vector2i) -> void:
	if hole == null or editor == null:
		return
	for r: int in range(hole.rows):
		for c: int in range(hole.cols):
			var sample: Vector2i = _tile_center_sample(hole, editor.grid, origin_dm, c, r)
			var layer: int = _dominant_layer(editor.splat, sample.x, sample.y)
			if layer != MHSplatMap.Layer.ROUGH:
				hole.paint_tile(c, r, _craft_surface_for_layer(layer))
			var mm: int = editor.grid.get_h_clamped(sample.x, sample.y)
			if mm != 0:
				hole.set_height_mm_tile(c, r, mm)
	hole.clear_history()


static func sync_from_world(hole: MHCraftHole, editor: MHTerrainEditor, origin_dm: Vector2i) -> void:
	if hole == null or editor == null:
		return
	_sync_from_world_rect(hole, editor, origin_dm,
		Rect2i(0, 0, editor.grid.samples_x, editor.grid.samples_y))


static func sync_from_world_rect(hole: MHCraftHole, editor: MHTerrainEditor, origin_dm: Vector2i, dirty: Rect2i) -> void:
	if hole == null or editor == null or not dirty.has_area():
		return
	# A craft tile is about 1.83 m wide. Expand by two 1 m samples so a brush
	# touching any part of a tile refreshes its representative centre sample.
	var expanded: Rect2i = dirty.grow(2)
	var touched: bool = false
	for r: int in range(hole.rows):
		for c: int in range(hole.cols):
			var sample: Vector2i = _tile_center_sample(hole, editor.grid, origin_dm, c, r)
			if not expanded.has_point(sample):
				continue
			touched = true
			hole.paint_tile(c, r, _craft_surface_for_layer(_dominant_layer(editor.splat, sample.x, sample.y)))
			hole.set_height_mm_tile(c, r, editor.grid.get_h_clamped(sample.x, sample.y))
	if touched:
		hole.clear_history()


## Writes the craft footprint back into the rendered world. With record_undo=true
## this becomes one normal terrain-editor undo step; unchanged samples are dropped
## by MHStroke.finalize().
static func sync_to_world(hole: MHCraftHole, editor: MHTerrainEditor, origin_dm: Vector2i,
		record_undo: bool = true) -> bool:
	var all_tiles: Array = []
	for r: int in range(hole.rows):
		for c: int in range(hole.cols):
			all_tiles.append(Vector2i(c, r))
	return sync_tiles_to_world(hole, editor, origin_dm, all_tiles, record_undo)


static func sync_tiles_to_world(hole: MHCraftHole, editor: MHTerrainEditor, origin_dm: Vector2i,
		tiles: Array, record_undo: bool = true) -> bool:
	if hole == null or editor == null or editor.is_stroke_open() or tiles.is_empty():
		return false
	var wanted: Dictionary = {}
	for value: Variant in tiles:
		var tile: Vector2i = value as Vector2i
		if hole.in_bounds(tile.x, tile.y):
			wanted[hole.index_of(tile.x, tile.y)] = true
	if wanted.is_empty():
		return false
	var bounds: Rect2i = _footprint_samples(hole, editor.grid, origin_dm)
	if not bounds.has_area():
		return false
	var stroke: MHStroke = null
	if record_undo:
		if not editor.begin_stroke():
			return false
		stroke = editor.undo_stack.open_stroke()
	var any_change: bool = false
	var min_x: int = editor.grid.samples_x
	var min_y: int = editor.grid.samples_y
	var max_x: int = -1
	var max_y: int = -1
	for gy: int in range(bounds.position.y, bounds.end.y):
		for gx: int in range(bounds.position.x, bounds.end.x):
			var tile: Vector2i = _world_sample_to_tile(hole, editor.grid, origin_dm, gx, gy)
			if tile.x < 0 or not wanted.has(hole.index_of(tile.x, tile.y)):
				continue
			var target_h: int = hole.get_height_mm(tile.x, tile.y)
			var hi: int = editor.grid.idx(gx, gy)
			var sample_changed: bool = false
			if editor.grid.heights[hi] != target_h:
				if stroke != null:
					stroke.touch(editor.grid, hi)
				editor.grid.heights[hi] = clampi(target_h, MHHeightGrid.MIN_H_MM, MHHeightGrid.MAX_H_MM)
				sample_changed = true
			var target_layer: int = _terrain_layer_for_surface(hole.get_surface(tile.x, tile.y))
			if _set_one_hot(editor.splat, gx, gy, target_layer, stroke):
				sample_changed = true
			if sample_changed:
				any_change = true
				min_x = mini(min_x, gx)
				min_y = mini(min_y, gy)
				max_x = maxi(max_x, gx)
				max_y = maxi(max_y, gy)
	if any_change:
		editor.dirty.mark_rect(min_x, min_y, max_x, max_y)
	if record_undo:
		return editor.end_stroke() > 0
	return any_change


static func _tile_center_sample(hole: MHCraftHole, grid: MHHeightGrid, origin_dm: Vector2i,
		c: int, r: int) -> Vector2i:
	var centre: Vector2i = hole.tile_centre_yd(c, r)
	var wx_mm: int = MHCourseLayout.world_mm(origin_dm.x, centre.x * 100)
	var wy_mm: int = MHCourseLayout.world_mm(origin_dm.y, centre.y * 100)
	return Vector2i(
		clampi(MHRMath.rdiv(wx_mm, grid.cell_size_mm), 0, grid.samples_x - 1),
		clampi(MHRMath.rdiv(wy_mm, grid.cell_size_mm), 0, grid.samples_y - 1))


static func _world_sample_to_tile(hole: MHCraftHole, grid: MHHeightGrid, origin_dm: Vector2i,
		gx: int, gy: int) -> Vector2i:
	var local_x_mm: int = gx * grid.cell_size_mm - origin_dm.x * 100
	var local_y_mm: int = gy * grid.cell_size_mm - origin_dm.y * 100
	var x_cy: int = MHRMath.fdiv(local_x_mm * 1000, 9144)
	var y_cy: int = MHRMath.fdiv(local_y_mm * 1000, 9144)
	return hole.tile_at_cy(x_cy, y_cy)


static func _footprint_samples(hole: MHCraftHole, grid: MHHeightGrid, origin_dm: Vector2i) -> Rect2i:
	var x0_mm: int = MHCourseLayout.world_mm(origin_dm.x, hole.tile_x0_yd(0) * 100)
	var x1_yd: int = hole.tile_x0_yd(hole.cols - 1) + MHCraftHole.TILE_YD
	var x1_mm: int = MHCourseLayout.world_mm(origin_dm.x, x1_yd * 100)
	var y0_mm: int = MHCourseLayout.world_mm(origin_dm.y, hole.tile_y0_yd(0) * 100)
	var y1_yd: int = hole.tile_y0_yd(hole.rows - 1) + MHCraftHole.TILE_YD
	var y1_mm: int = MHCourseLayout.world_mm(origin_dm.y, y1_yd * 100)
	var gx0: int = clampi(MHRMath.fdiv(x0_mm, grid.cell_size_mm), 0, grid.samples_x - 1)
	var gy0: int = clampi(MHRMath.fdiv(y0_mm, grid.cell_size_mm), 0, grid.samples_y - 1)
	var gx1: int = clampi(MHRMath.fdiv(x1_mm + grid.cell_size_mm - 1, grid.cell_size_mm), 0, grid.samples_x - 1)
	var gy1: int = clampi(MHRMath.fdiv(y1_mm + grid.cell_size_mm - 1, grid.cell_size_mm), 0, grid.samples_y - 1)
	return Rect2i(gx0, gy0, gx1 - gx0 + 1, gy1 - gy0 + 1)


static func _dominant_layer(splat: MHSplatMap, x: int, y: int) -> int:
	var texel: int = clampi(y, 0, splat.samples_y - 1) * splat.samples_x + clampi(x, 0, splat.samples_x - 1)
	var base: int = texel * MHSplatMap.LAYER_COUNT
	var best_layer: int = MHSplatMap.Layer.ROUGH
	var best_weight: int = -1
	for layer: int in range(MHSplatMap.LAYER_COUNT):
		var weight: int = int(splat.bytes[base + layer])
		if weight > best_weight:
			best_weight = weight
			best_layer = layer
	return best_layer


static func _set_one_hot(splat: MHSplatMap, x: int, y: int, layer: int, stroke: MHStroke) -> bool:
	var texel: int = y * splat.samples_x + x
	var base: int = texel * MHSplatMap.LAYER_COUNT
	var changed: bool = false
	for i: int in range(MHSplatMap.LAYER_COUNT):
		var target: int = 255 if i == layer else 0
		if int(splat.bytes[base + i]) != target:
			changed = true
			break
	if not changed:
		return false
	if stroke != null:
		stroke.touch_splat(splat, texel)
	for i: int in range(MHSplatMap.LAYER_COUNT):
		splat.bytes[base + i] = 255 if i == layer else 0
	return true


static func _craft_surface_for_layer(layer: int) -> int:
	match layer:
		MHSplatMap.Layer.FAIRWAY: return MHCraftHole.Surface.FAIRWAY
		MHSplatMap.Layer.FIRST_CUT: return MHCraftHole.Surface.FIRST_CUT
		MHSplatMap.Layer.GREEN: return MHCraftHole.Surface.GREEN
		MHSplatMap.Layer.FRINGE: return MHCraftHole.Surface.FRINGE
		MHSplatMap.Layer.TEE: return MHCraftHole.Surface.TEE
		MHSplatMap.Layer.BUNKER_SAND: return MHCraftHole.Surface.BUNKER
		MHSplatMap.Layer.WATER: return MHCraftHole.Surface.WATER
		MHSplatMap.Layer.PATH: return MHCraftHole.Surface.PATH
		MHSplatMap.Layer.WASTE: return MHCraftHole.Surface.WASTE
		MHSplatMap.Layer.DIRT: return MHCraftHole.Surface.DIRT
		_: return MHCraftHole.Surface.ROUGH


static func _terrain_layer_for_surface(surface_id: int) -> int:
	match surface_id:
		MHCraftHole.Surface.FAIRWAY: return MHSplatMap.Layer.FAIRWAY
		MHCraftHole.Surface.FIRST_CUT: return MHSplatMap.Layer.FIRST_CUT
		MHCraftHole.Surface.GREEN: return MHSplatMap.Layer.GREEN
		MHCraftHole.Surface.FRINGE: return MHSplatMap.Layer.FRINGE
		MHCraftHole.Surface.TEE: return MHSplatMap.Layer.TEE
		MHCraftHole.Surface.BUNKER: return MHSplatMap.Layer.BUNKER_SAND
		MHCraftHole.Surface.WATER: return MHSplatMap.Layer.WATER
		MHCraftHole.Surface.PATH: return MHSplatMap.Layer.PATH
		MHCraftHole.Surface.WASTE: return MHSplatMap.Layer.WASTE
		MHCraftHole.Surface.DIRT: return MHSplatMap.Layer.DIRT
		# Deep rough and out-of-bounds are rating semantics not represented by the
		# current 11-channel world splat. Preserve them in MHCraftHole; render their
		# closest world analogue without pretending the splat can round-trip them.
		MHCraftHole.Surface.OUT_OF_BOUNDS: return MHSplatMap.Layer.DIRT
		_: return MHSplatMap.Layer.ROUGH
