class_name MHRHole
extends RefCounted
## Parsed hole for the rating engine (spec rating-engine.md 2.1, 2.3 and golfer-sim.md 6).
## Hole-local frame; geometry is converted from whole yards to centiyards (x100). Mirror of Hole in
## tools/reference/rating/rating_core.py. NOT re-entrant: tree_hit writes hit_* members.
@warning_ignore_start("integer_division")

const CY: int = 100
const LIE_TEE: int = 0
const LIE_FAIRWAY: int = 1
const LIE_FRINGE: int = 2
const LIE_ROUGH: int = 3
const LIE_DEEP: int = 4
const LIE_BUNKER: int = 5
const LIE_GREEN: int = 6
const LIE_WATER: int = 7
const LIE_OB: int = 8

## Feature type index: 0 fairway, 1 deep_rough, 2 bunker, 3 water, 4 ob.
const T_FAIRWAY: int = 0
const T_DEEP: int = 1
const T_BUNKER: int = 2
const T_WATER: int = 3
const T_OB: int = 4
const TYPE_NAMES: Array = ["fairway", "deep_rough", "bunker", "water", "ob"]

var valid: bool = true
var reasons: Array = []
var slot: int = 1
var tee_x: int = 0
var tee_y: int = 0
var gx: int = 0
var gy: int = 0
var gr: int = 0
var L: int = 0
var par: int = 0
var tee_z: int = 0
var green_z: int = 0
var rects: Array = []        # 5 x PackedInt32Array flat [x0, y0, x1, y1, ...] in cy
var circles: Array = []      # 5 x PackedInt32Array flat [cx, cy, r, ...] in cy
var rock_count: int = 0
var flower_count: int = 0
var trees: PackedInt32Array = PackedInt32Array()   # flat [x, y, ...] cy, sorted by (x, y)
var buckets: Dictionary = {}                        # key -> PackedInt32Array flat trees (lookup only)
## Relief grid (optional): nodes at (x0 + i*step, y0 + j*step) yards, heights in mm, row-major.
var has_relief: bool = false
var rl_x0: int = 0
var rl_y0: int = 0
var rl_step: int = 1
var rl_cols: int = 0
var rl_rows: int = 0
var rl_z: PackedInt32Array = PackedInt32Array()
var relief_range: int = 0
var hit_t: int = 0
var hit_x: int = 0
var hit_y: int = 0


static func _bkey(bx: int, by: int) -> int:
	return (bx + 1024) * 4096 + (by + 1024)


static func par_for(length_yd: int) -> int:
	if length_yd <= MHRParams.par_limit_3:
		return 3
	if length_yd <= MHRParams.par_limit_4:
		return 4
	return 5


static func _row_less(a: Array, b: Array) -> bool:
	var n: int = mini(a.size(), b.size())
	for i in range(n):
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return a.size() < b.size()


## Fixture-only loader for {t:"tree", rect, count} (spec 2.1). Returns flat [x, y, ...] in yards.
static func expand_tree_rect(rect: Array, n: int) -> PackedInt32Array:
	var x0: int = int(rect[0])
	var y0: int = int(rect[1])
	var x1: int = int(rect[2])
	var y1: int = int(rect[3])
	var area: int = maxi(1, (x1 - x0) * (y1 - y0))
	var s: int = maxi(1, MHRMath.isqrt(area / maxi(1, n)))
	var nx: int = maxi(1, MHRMath.fdiv(x1 - x0, s))
	var out: PackedInt32Array = PackedInt32Array()
	var count: int = 0
	var j: int = 0
	var half: int = MHRMath.fdiv(s, 2)
	while count < n:
		for i in range(nx):
			if count >= n:
				break
			out.append(x0 + half + i * s)
			out.append(y0 + half + j * s)
			count += 1
		j += 1
	return out


static func from_def(d: Dictionary) -> MHRHole:
	var h: MHRHole = MHRHole.new()
	h._build(d)
	return h


func _build(d: Dictionary) -> void:
	slot = int(d.get("slot_id", 1))
	var tee: Variant = d.get("tee", null)
	var green: Variant = d.get("green", null)
	var feats: Array = []
	if d.has("features") and typeof(d["features"]) == TYPE_ARRAY:
		feats = d["features"]
	tee_z = int(d.get("tee_z_mm", 0))
	green_z = int(d.get("green_z_mm", 0))
	for t in range(5):
		rects.append(PackedInt32Array())
		circles.append(PackedInt32Array())
	if typeof(tee) != TYPE_ARRAY or (tee as Array).size() < 2:
		valid = false
		reasons.append("RC001")
	if typeof(green) != TYPE_ARRAY or (green as Array).size() < 3:
		valid = false
		reasons.append("RC002")
	if feats.size() > 3000:
		valid = false
		reasons.append("RC005")
	if not valid:
		return
	var ta: Array = tee
	var ga: Array = green
	tee_x = int(ta[0]) * CY
	tee_y = int(ta[1]) * CY
	gx = int(ga[0]) * CY
	gy = int(ga[1]) * CY
	gr = int(ga[2])
	if d.has("relief") and typeof(d["relief"]) == TYPE_DICTIONARY:
		_load_relief(d["relief"] as Dictionary)
		tee_z = z_at(tee_x, tee_y)
		green_z = z_at(gx, gy)
	var dx: int = int(ga[0]) - int(ta[0])
	var dy: int = int(ga[1]) - int(ta[1])
	L = MHRMath.isqrt(dx * dx + dy * dy)
	par = par_for(L)
	var pts: PackedInt32Array = PackedInt32Array()   # tree points in yards
	for fv in feats:
		var f: Dictionary = fv
		var t: String = String(f["t"])
		if t == "tree":
			if f.has("at"):
				for p in (f["at"] as Array):
					pts.append(int((p as Array)[0]))
					pts.append(int((p as Array)[1]))
			else:
				pts.append_array(expand_tree_rect(f["rect"] as Array, int(f["count"])))
		elif t == "rock" or t == "flower":
			var c: int = 1
			if f.has("count"):
				c = int(f["count"])
			elif f.has("at") and (f["at"] as Array).size() > 0:
				c = (f["at"] as Array).size()
			if t == "rock":
				rock_count += c
			else:
				flower_count += c
		else:
			var ti: int = TYPE_NAMES.find(t)
			if ti < 0:
				continue
			if f.has("rect"):
				var rr: PackedInt32Array = rects[ti]
				for v in (f["rect"] as Array):
					rr.append(int(v) * CY)
				rects[ti] = rr
			elif f.has("circle"):
				var cc: PackedInt32Array = circles[ti]
				for v in (f["circle"] as Array):
					cc.append(int(v) * CY)
				circles[ti] = cc
	_sort_trees(pts)
	if _in_type(T_WATER, gx, gy) or _in_type(T_OB, gx, gy) or lie_at(gx, gy) == LIE_OB:
		valid = false
		reasons.append("RC004")
	if _in_type(T_WATER, tee_x, tee_y) or _in_type(T_OB, tee_x, tee_y) or lie_at(tee_x, tee_y) == LIE_OB:
		valid = false
		reasons.append("RC008")
	if L < 60 or L > 1000:
		valid = false
		reasons.append("RC003")
	if gr < 5 or gr > 30:
		valid = false
		reasons.append("RC006")


func _load_relief(r: Dictionary) -> void:
	has_relief = true
	rl_x0 = int(r["x0"])
	rl_y0 = int(r["y0"])
	rl_step = int(r["step"])
	rl_cols = int(r["cols"])
	rl_rows = int(r["rows"])
	rl_z = PackedInt32Array()
	var lo: int = 0
	var hi: int = 0
	var first: bool = true
	for v in (r["z"] as Array):
		var zi: int = int(v)
		rl_z.append(zi)
		if first or zi < lo:
			lo = zi
		if first or zi > hi:
			hi = zi
		first = false
	relief_range = hi - lo


## Bilinear height in mm at a centiyard point, clamped to the grid edge. 0 with no relief.
func z_at(xcy: int, ycy: int) -> int:
	if not has_relief:
		return 0
	var sc: int = rl_step * CY
	var fx: int = xcy - rl_x0 * CY
	var fy: int = ycy - rl_y0 * CY
	var i: int = MHRMath.clampi_inc(MHRMath.fdiv(fx, sc), 0, rl_cols - 2)
	var j: int = MHRMath.clampi_inc(MHRMath.fdiv(fy, sc), 0, rl_rows - 2)
	var fu: int = MHRMath.clampi_inc(fx - i * sc, 0, sc)
	var fv: int = MHRMath.clampi_inc(fy - j * sc, 0, sc)
	var z00: int = rl_z[j * rl_cols + i]
	var z10: int = rl_z[j * rl_cols + i + 1]
	var z01: int = rl_z[(j + 1) * rl_cols + i]
	var z11: int = rl_z[(j + 1) * rl_cols + i + 1]
	return MHRMath.fdiv(z00 * (sc - fu) * (sc - fv) + z10 * fu * (sc - fv) + z01 * (sc - fu) * fv + z11 * fu * fv, sc * sc)


## Central-difference slope in mm per yard; returns Vector2i(dz/dx, dz/dy).
func grad(xcy: int, ycy: int) -> Vector2i:
	var gdx: int = MHRMath.fdiv(z_at(xcy + CY, ycy) - z_at(xcy - CY, ycy), 2)
	var gdy: int = MHRMath.fdiv(z_at(xcy, ycy + CY) - z_at(xcy, ycy - CY), 2)
	return Vector2i(gdx, gdy)


## Height change that drives the elevation axes: end to end, or the relief share of the range if larger.
func elev_mm() -> int:
	return maxi(absi(green_z - tee_z), MHRMath.fdiv(relief_range * MHRParams.rl_range_pm, 1000))


func _sort_trees(pts_yd: PackedInt32Array) -> void:
	var keys: PackedInt64Array = PackedInt64Array()
	var n: int = pts_yd.size() / 2
	for i in range(n):
		keys.append((pts_yd[i * 2] * CY + 500000) * 2097152 + (pts_yd[i * 2 + 1] * CY + 500000))
	keys.sort()
	trees = PackedInt32Array()
	for k in keys:
		var kx: int = k / 2097152 - 500000
		var ky: int = k % 2097152 - 500000
		trees.append(kx)
		trees.append(ky)
		var bk: int = _bkey(MHRMath.fdiv(kx, 1000), MHRMath.fdiv(ky, 1000))
		if not buckets.has(bk):
			buckets[bk] = PackedInt32Array()
		var arr: PackedInt32Array = buckets[bk]
		arr.append(kx)
		arr.append(ky)
		buckets[bk] = arr


func tree_count() -> int:
	return trees.size() / 2


func has_bunker() -> bool:
	return (rects[T_BUNKER] as PackedInt32Array).size() > 0 or (circles[T_BUNKER] as PackedInt32Array).size() > 0


## Canonical content bytes (spec 2.1): tee, green, z, features sorted by (type code, shape, coords),
## rock and flower counts, tree count, trees sorted by (x, y). All int32 little endian, yards.
func canonical_bytes() -> PackedByteArray:
	var b: PackedByteArray = PackedByteArray()
	MHRMath.push_i32(b, MHRMath.fdiv(tee_x, CY))
	MHRMath.push_i32(b, MHRMath.fdiv(tee_y, CY))
	MHRMath.push_i32(b, MHRMath.fdiv(gx, CY))
	MHRMath.push_i32(b, MHRMath.fdiv(gy, CY))
	MHRMath.push_i32(b, gr)
	MHRMath.push_i32(b, tee_z)
	MHRMath.push_i32(b, green_z)
	var rows: Array = []
	for t in range(5):
		var ra: PackedInt32Array = rects[t]
		for i in range(ra.size() / 4):
			rows.append([t + 1, 0, ra[i * 4] / CY, ra[i * 4 + 1] / CY, ra[i * 4 + 2] / CY, ra[i * 4 + 3] / CY])
		var ca: PackedInt32Array = circles[t]
		for i in range(ca.size() / 3):
			rows.append([t + 1, 1, ca[i * 3] / CY, ca[i * 3 + 1] / CY, ca[i * 3 + 2] / CY])
	rows.sort_custom(func(a: Array, c: Array) -> bool: return MHRHole._row_less(a, c))
	MHRMath.push_i32(b, rows.size())
	for r in rows:
		for v in (r as Array):
			MHRMath.push_i32(b, int(v))
	MHRMath.push_i32(b, rock_count)
	MHRMath.push_i32(b, flower_count)
	MHRMath.push_i32(b, tree_count())
	for i in range(tree_count()):
		MHRMath.push_i32(b, MHRMath.fdiv(trees[i * 2], CY))
		MHRMath.push_i32(b, MHRMath.fdiv(trees[i * 2 + 1], CY))
	if has_relief:
		MHRMath.push_ascii(b, "RLF1")
		MHRMath.push_i32(b, rl_x0)
		MHRMath.push_i32(b, rl_y0)
		MHRMath.push_i32(b, rl_step)
		MHRMath.push_i32(b, rl_cols)
		MHRMath.push_i32(b, rl_rows)
		for v in rl_z:
			MHRMath.push_i32(b, v)
	return b


func content_hash() -> String:
	if not valid:
		return ""
	return MHRMath.hash64(canonical_bytes())


func _in_type(t: int, x: int, y: int) -> bool:
	var ra: PackedInt32Array = rects[t]
	for i in range(ra.size() / 4):
		var k: int = i * 4
		if ra[k] <= x and x <= ra[k + 2] and ra[k + 1] <= y and y <= ra[k + 3]:
			return true
	var ca: PackedInt32Array = circles[t]
	for i in range(ca.size() / 3):
		var k: int = i * 3
		var ddx: int = x - ca[k]
		var ddy: int = y - ca[k + 1]
		if ddx * ddx + ddy * ddy <= ca[k + 2] * ca[k + 2]:
			return true
	return false


func in_water(x: int, y: int) -> bool:
	return _in_type(T_WATER, x, y)


func in_bunker(x: int, y: int) -> bool:
	return _in_type(T_BUNKER, x, y)


func in_ob_feature(x: int, y: int) -> bool:
	return _in_type(T_OB, x, y)


func lie_at(x: int, y: int) -> int:
	if x < -12000 or x > 12000 or y < -3000 or y > L * CY + 8000 or _in_type(T_OB, x, y):
		return LIE_OB
	if _in_type(T_WATER, x, y):
		return LIE_WATER
	var ddx: int = x - gx
	var ddy: int = y - gy
	var d2: int = ddx * ddx + ddy * ddy
	if d2 <= (gr * CY) * (gr * CY):
		return LIE_GREEN
	if d2 <= ((gr + 3) * CY) * ((gr + 3) * CY):
		return LIE_FRINGE
	if _in_type(T_BUNKER, x, y):
		return LIE_BUNKER
	if _in_type(T_FAIRWAY, x, y):
		return LIE_FAIRWAY
	if _in_type(T_DEEP, x, y):
		return LIE_DEEP
	return LIE_ROUGH


## First tree intercepting a -> b (t <= tmax_pm) or covering b. Sets hit_t, hit_x, hit_y on success.
func tree_hit(ax: int, ay: int, bx: int, by: int, tmax_pm: int) -> bool:
	if trees.size() == 0:
		return false
	var ex: int = bx - ax
	var ey: int = by - ay
	var e2: int = ex * ex + ey * ey
	var r2: int = 200 * 200
	var found: bool = false
	var best_t: int = 0
	var best_x: int = 0
	var best_y: int = 0
	var x0: int = mini(ax, bx)
	var x1: int = maxi(ax, bx)
	var y0: int = mini(ay, by)
	var y1: int = maxi(ay, by)
	var bx_lo: int = MHRMath.fdiv(x0 - 200, 1000)
	var bx_hi: int = MHRMath.fdiv(x1 + 200, 1000)
	var by_lo: int = MHRMath.fdiv(y0 - 200, 1000)
	var by_hi: int = MHRMath.fdiv(y1 + 200, 1000)
	for bxk in range(bx_lo, bx_hi + 1):
		for byk in range(by_lo, by_hi + 1):
			var key: int = _bkey(bxk, byk)
			if not buckets.has(key):
				continue
			var arr: PackedInt32Array = buckets[key]
			for i in range(arr.size() / 2):
				var tx: int = arr[i * 2]
				var ty: int = arr[i * 2 + 1]
				var t_pm: int = 0
				if e2 != 0:
					t_pm = MHRMath.clampi_inc(MHRMath.fdiv(((tx - ax) * ex + (ty - ay) * ey) * 1000, e2), 0, 1000)
				var px: int = ax + MHRMath.fdiv(ex * t_pm, 1000)
				var py: int = ay + MHRMath.fdiv(ey * t_pm, 1000)
				var ddx: int = tx - px
				var ddy: int = ty - py
				if ddx * ddx + ddy * ddy <= r2:
					var ex2: int = tx - bx
					var ey2: int = ty - by
					var at_end: bool = ex2 * ex2 + ey2 * ey2 <= r2
					if t_pm <= tmax_pm or at_end:
						if not found or t_pm < best_t:
							found = true
							best_t = t_pm
							best_x = px
							best_y = py
	if found:
		hit_t = best_t
		hit_x = best_x
		hit_y = best_y
	return found
