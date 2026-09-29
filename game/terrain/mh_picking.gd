class_name MHPicking
extends RefCounted
## Touch picking by ray-marching the heightmap. RENDERING-SIDE ONLY: uses floats (camera ray,
## bilinear height). Its only output is an integer cell, and that integer is what the
## gesture/command layer records and replays. Floats here never feed authoritative edits.
## World mapping: world_x = cell_x * cell_size_m, world_z = cell_y * cell_size_m, world_y = height_mm / 1000.

const MISS: Vector2i = Vector2i(-1, -1)


static func sample_height_m(grid: MHHeightGrid, gx: float, gz: float) -> float:
	var x0: int = mini(int(gx), grid.cells_x - 1)
	var z0: int = mini(int(gz), grid.cells_y - 1)
	x0 = maxi(x0, 0)
	z0 = maxi(z0, 0)
	var fx: float = clampf(gx - float(x0), 0.0, 1.0)
	var fz: float = clampf(gz - float(z0), 0.0, 1.0)
	var h00: float = float(grid.get_h(x0, z0))
	var h10: float = float(grid.get_h(x0 + 1, z0))
	var h01: float = float(grid.get_h(x0, z0 + 1))
	var h11: float = float(grid.get_h(x0 + 1, z0 + 1))
	var top: float = lerpf(h00, h10, fx)
	var bot: float = lerpf(h01, h11, fx)
	return lerpf(top, bot, fz) * 0.001


static func _is_above(grid: MHHeightGrid, origin: Vector3, d: Vector3, t: float, cs: float) -> bool:
	var p: Vector3 = origin + d * t
	var gx: float = p.x / cs
	var gz: float = p.z / cs
	if gx < 0.0 or gz < 0.0 or gx > float(grid.cells_x) or gz > float(grid.cells_y):
		return true
	return p.y >= sample_height_m(grid, gx, gz)


## Returns the nearest sample cell hit by the ray, or MISS. Step = half a cell, then 10 bisections.
static func pick(grid: MHHeightGrid, origin: Vector3, dir: Vector3, max_dist_m: float = 2000.0) -> Vector2i:
	var cs: float = float(grid.cell_size_mm) * 0.001
	var d: Vector3 = dir.normalized()
	var step_m: float = cs * 0.5
	var steps: int = int(max_dist_m / step_m)
	var prev_t: float = 0.0
	var prev_above: bool = true
	for s in range(steps + 1):
		var t: float = float(s) * step_m
		var above: bool = _is_above(grid, origin, d, t, cs)
		if prev_above and not above and s > 0:
			var lo: float = prev_t
			var hi: float = t
			for _i in range(10):
				var mid: float = 0.5 * (lo + hi)
				if _is_above(grid, origin, d, mid, cs):
					lo = mid
				else:
					hi = mid
			var p: Vector3 = origin + d * hi
			return Vector2i(
				clampi(roundi(p.x / cs), 0, grid.cells_x),
				clampi(roundi(p.z / cs), 0, grid.cells_y))
		prev_above = above
		prev_t = t
	return MISS
