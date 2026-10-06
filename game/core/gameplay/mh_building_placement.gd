class_name MHBuildingPlacement
extends RefCounted
## Pure terrain-aware freeform building placement validation.
## Authoritative inputs are integer millimetres/grid samples; presentation may convert the result to Vector3.

const MAX_SLOPE_PER_MILLE: int = 180 # ~10 degrees across a footprint edge.
const MAX_RELIEF_MM: int = 1200
const CLEARANCE_MM: int = 750
const HAZARD_WEIGHT_MIN: int = 128
const SAMPLE_STEP_CELLS: int = 2

static func footprint_m(building_id: String, tier: int) -> Vector2i:
	var base: Dictionary = {
		"clubhouse": Vector2i(18, 14), "pro_shop": Vector2i(10, 8), "driving_range": Vector2i(14, 10),
		"restaurant": Vector2i(14, 12), "pool_spa": Vector2i(18, 14), "cart_barn": Vector2i(14, 10),
		"maintenance": Vector2i(18, 14), "lodging": Vector2i(20, 14), "homes": Vector2i(16, 12),
		"landmark": Vector2i(10, 10)}
	var size: Vector2i = base.get(building_id, Vector2i(12, 10))
	var grow: int = maxi(0, tier - 1) * 2
	return size + Vector2i(grow, grow)


static func validate(grid: MHHeightGrid, splat: MHSplatMap, land: MHLandModel, building_id: String, tier: int,
		center_mm: Vector2i, existing: Array = []) -> Dictionary:
	if grid == null or splat == null or land == null:
		return _bad("missing_world")
	var size_m: Vector2i = footprint_m(building_id, tier)
	var half_x: int = size_m.x * 500
	var half_y: int = size_m.y * 500
	var x0: int = center_mm.x - half_x
	var x1: int = center_mm.x + half_x
	var y0: int = center_mm.y - half_y
	var y1: int = center_mm.y + half_y
	var world_x: int = grid.cells_x * grid.cell_size_mm
	var world_y: int = grid.cells_y * grid.cell_size_mm
	if x0 < 0 or y0 < 0 or x1 > world_x or y1 > world_y:
		return _bad("world_edge")
	if not _owned_rect(land, x0, y0, x1, y1, world_x, world_y):
		return _bad("unowned_land")
	for v: Variant in existing:
		var b: Dictionary = v
		var c: Array = b.get("center_mm", [])
		var s: Array = b.get("size_m", [])
		if c.size() == 2 and s.size() == 2:
			if _rect_overlap(x0 - CLEARANCE_MM, y0 - CLEARANCE_MM, x1 + CLEARANCE_MM, y1 + CLEARANCE_MM,
					int(c[0]) - int(s[0]) * 500, int(c[1]) - int(s[1]) * 500,
					int(c[0]) + int(s[0]) * 500, int(c[1]) + int(s[1]) * 500):
				return _bad("building_overlap")
	var min_h: int = MHHeightGrid.MAX_H_MM
	var max_h: int = MHHeightGrid.MIN_H_MM
	var sum_h: int = 0
	var samples: int = 0
	var cell: int = grid.cell_size_mm
	var gx0: int = x0 / cell
	var gx1: int = x1 / cell
	var gy0: int = y0 / cell
	var gy1: int = y1 / cell
	for gy: int in range(gy0, gy1 + 1, SAMPLE_STEP_CELLS):
		for gx: int in range(gx0, gx1 + 1, SAMPLE_STEP_CELLS):
			var sx: int = clampi(gx, 0, grid.samples_x - 1)
			var sy: int = clampi(gy, 0, grid.samples_y - 1)
			if _hazard_at(splat, sx, sy):
				return _bad("hazard")
			var h: int = grid.get_h(sx, sy)
			min_h = mini(min_h, h)
			max_h = maxi(max_h, h)
			sum_h += h
			samples += 1
	if samples == 0:
		return _bad("unsupported")
	var relief: int = max_h - min_h
	if relief > MAX_RELIEF_MM:
		return _bad("terrain_relief")
	var run_mm: int = maxi(size_m.x, size_m.y) * 1000
	if relief * 1000 > run_mm * MAX_SLOPE_PER_MILLE:
		return _bad("terrain_slope")
	return {"ok": true, "reason": "", "center_mm": [center_mm.x, center_mm.y], "size_m": [size_m.x, size_m.y],
		"ground_mm": MHRMath.rdiv(sum_h, samples), "min_h_mm": min_h, "max_h_mm": max_h}


static func _hazard_at(splat: MHSplatMap, x: int, y: int) -> bool:
	for layer: int in [MHSplatMap.Layer.WATER, MHSplatMap.Layer.BUNKER_SAND, MHSplatMap.Layer.PATH, MHSplatMap.Layer.WASTE]:
		if splat.get_weight(x, y, layer) >= HAZARD_WEIGHT_MIN:
			return true
	return false


static func _owned_rect(land: MHLandModel, x0: int, y0: int, x1: int, y1: int, world_x: int, world_y: int) -> bool:
	# Land remains the ownership/economy boundary, not a placement grid. Check footprint corners + centre.
	for p: Vector2i in [Vector2i(x0, y0), Vector2i(x1 - 1, y0), Vector2i(x0, y1 - 1), Vector2i(x1 - 1, y1 - 1),
			Vector2i((x0 + x1) / 2, (y0 + y1) / 2)]:
		var col: int = clampi((p.x * 4) / maxi(world_x, 1), 0, 3)
		var row: int = clampi((p.y * 4) / maxi(world_y, 1), 0, 3)
		if not land.is_owned(row * 4 + col):
			return false
	return true


static func _rect_overlap(ax0: int, ay0: int, ax1: int, ay1: int, bx0: int, by0: int, bx1: int, by1: int) -> bool:
	return ax0 < bx1 and ax1 > bx0 and ay0 < by1 and ay1 > by0


static func _bad(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
