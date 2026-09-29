class_name MHBrush
extends RefCounted
## Integer-only terrain brush. Mirrors tools/reference/terrain/brush_ref.py exactly.
## Falloff: t = ((r^2 - d^2) * 1024) / r^2 (0..1024), weight = FALLOFF[t] (0..1024),
## FALLOFF[t] = (3*t^2*1024 - 2*t^3) / 1024^2 (integer smoothstep, all operands non-negative).
## Modes: RAISE/LOWER add/subtract round(strength_mm * w / 1024). SMOOTH/FLATTEN blend toward a
## target by strength_per_mille * w / (1024 * 1000), truncating toward zero.
## All divisions use non-negative operands or idiv() so GDScript and Python agree.

enum Mode { RAISE = 0, LOWER = 1, SMOOTH = 2, FLATTEN = 3 }

static var _falloff: PackedInt32Array = PackedInt32Array()


static func falloff_table() -> PackedInt32Array:
	if _falloff.size() != 1025:
		var t_arr := PackedInt32Array()
		t_arr.resize(1025)
		for t in range(1025):
			t_arr[t] = (3 * t * t * 1024 - 2 * t * t * t) / 1048576
		_falloff = t_arr
	return _falloff


static func falloff_hash() -> int:
	var table: PackedInt32Array = falloff_table()
	var h: int = MHHeightGrid.FNV_OFFSET
	for i in range(table.size()):
		var u: int = table[i] + 32768
		h = ((h ^ (u & 255)) * MHHeightGrid.FNV_PRIME) & 0xFFFFFFFF
		h = ((h ^ (u >> 8)) * MHHeightGrid.FNV_PRIME) & 0xFFFFFFFF
	return h


## Integer division truncating toward zero (same as C++ and as brush_ref.py idiv).
static func idiv(a: int, b: int) -> int:
	if a >= 0:
		return a / b
	return -((-a) / b)


## Applies one dab. Returns the affected rect (footprint clipped to the grid) or an empty Rect2i.
## If stroke is not null every changed cell is recorded (first-touch old value) before writing.
## strength: RAISE/LOWER = millimetres at centre; SMOOTH/FLATTEN = per mille 0..1000.
@warning_ignore("integer_division")
static func apply_dab(grid: MHHeightGrid, mode: int, cx: int, cy: int, radius: int,
		strength: int, level_mm: int, stroke: MHStroke) -> Rect2i:
	var r: int = maxi(radius, 1)
	var x0: int = maxi(cx - r, 0)
	var x1: int = mini(cx + r, grid.samples_x - 1)
	var y0: int = maxi(cy - r, 0)
	var y1: int = mini(cy + r, grid.samples_y - 1)
	if x0 > x1 or y0 > y1:
		return Rect2i()
	var table: PackedInt32Array = falloff_table()
	var r2: int = r * r
	var sx: int = grid.samples_x
	var sy: int = grid.samples_y
	var out_idx := PackedInt32Array()
	var out_val := PackedInt32Array()
	# Pass 1: compute new values from the pre-dab heights (order independent).
	for y in range(y0, y1 + 1):
		var dy: int = y - cy
		for x in range(x0, x1 + 1):
			var dx: int = x - cx
			var d2: int = dx * dx + dy * dy
			if d2 > r2:
				continue
			var w: int = table[((r2 - d2) * 1024) / r2]
			if w == 0:
				continue
			var i: int = y * sx + x
			var h: int = grid.heights[i]
			var nh: int = h
			if mode == Mode.RAISE:
				nh = h + (strength * w + 512) / 1024
			elif mode == Mode.LOWER:
				nh = h - (strength * w + 512) / 1024
			elif mode == Mode.SMOOTH:
				var sum: int = 0
				var cnt: int = 0
				for ny in range(maxi(y - 1, 0), mini(y + 1, sy - 1) + 1):
					for nx in range(maxi(x - 1, 0), mini(x + 1, sx - 1) + 1):
						sum += grid.heights[ny * sx + nx] + 32768
						cnt += 1
				var avg: int = sum / cnt - 32768
				nh = h + idiv((avg - h) * w * strength, 1024000)
			elif mode == Mode.FLATTEN:
				nh = h + idiv((level_mm - h) * w * strength, 1024000)
			nh = clampi(nh, MHHeightGrid.MIN_H_MM, MHHeightGrid.MAX_H_MM)
			if nh != h:
				out_idx.append(i)
				out_val.append(nh)
	# Pass 2: record and write.
	for k in range(out_idx.size()):
		if stroke != null:
			stroke.touch(grid, out_idx[k])
		grid.heights[out_idx[k]] = out_val[k]
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)
