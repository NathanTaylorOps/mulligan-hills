class_name MHShotSim
extends RefCounted
## Prototype shot-by-shot golfer simulation. Integer / fixed-point only, seeded MHRng only.
## Mirror of tools/reference/determinism/mh_shotsim.py (keep line-for-line equivalent).
## Game balance is NOT tuned; this exists to prove bit-identical results across platforms.
##
## Units: positions and distances Q16.16 metres; angles brads16; wind Q16.16 m/s; skill int 0..100.

const KIND_FULL: int = 1
const KIND_PUTT_MISS: int = 2
const KIND_PUTT_HOLE: int = 3
const KIND_PENALTY: int = 4
const KIND_PICKUP: int = 5

const PARS: Array = [4, 3, 5, 4, 4, 3, 4, 5, 4]
const MAX_STROKES: int = 12
const SHOT_SECONDS: int = 30
const PUTT_SECONDS: int = 45
const PENALTY_SECONDS: int = 30
const HOLE_TRANSIT_SECONDS: int = 120
const WIND_K: int = 655 ## 0.01 in Q16.16: wind (m/s) * dist (m) * 0.01 = drift (m)

const MODE_WATER: int = 0
const MODE_BUNKER: int = 1
const MODE_GREEN: int = 2


static func _center(tcx: int, tcy: int, pcx: int, pcy: int, cy: int) -> int:
	if cy <= tcy:
		return tcx
	if cy >= pcy:
		return pcx
	return tcx + _tdiv((pcx - tcx) * (cy - tcy), pcy - tcy)


## Integer division truncating toward zero (GDScript int / int already does this; wrapped for clarity).
@warning_ignore("integer_division")
static func _tdiv(a: int, b: int) -> int:
	return a / b


static func _stamp(hole: MHHole, cx0: int, cy0: int, r: int, mode: int) -> void:
	var y0: int = maxi(cy0 - r, 0)
	var y1: int = mini(cy0 + r, hole.h - 1)
	var x0: int = maxi(cx0 - r, 0)
	var x1: int = mini(cx0 + r, MHHole.GRID_W - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var dx: int = cx - cx0
			var dy: int = cy - cy0
			if dx * dx + dy * dy > r * r:
				continue
			var i: int = cy * MHHole.GRID_W + cx
			var cur: int = hole.lies[i]
			if mode == MODE_WATER:
				if cur != MHHole.LIE_OB:
					hole.lies[i] = MHHole.LIE_WATER
			elif mode == MODE_BUNKER:
				if cur == MHHole.LIE_FAIRWAY or cur == MHHole.LIE_ROUGH:
					hole.lies[i] = MHHole.LIE_BUNKER
			else:
				hole.lies[i] = MHHole.LIE_GREEN


@warning_ignore("integer_division")
static func make_hole(course_seed: int, idx: int) -> MHHole:
	var rng: MHRng = MHRng.new(course_seed, 1000 + idx)
	var hole: MHHole = MHHole.new()
	hole.par = PARS[idx % 9]
	var length: int
	if hole.par == 3:
		length = 110 + rng.range_incl(0, 60)
	elif hole.par == 4:
		length = 260 + rng.range_incl(0, 100)
	else:
		length = 400 + rng.range_incl(0, 120)
	var dcx: int = rng.range_incl(-10, 10)
	var tcx: int = 64
	var tcy: int = 3
	var len_cells: int = length / 4
	var pcx: int = tcx + dcx
	var pcy: int = tcy + len_cells
	hole.w = MHHole.GRID_W
	hole.h = pcy + 12
	hole.lies.resize(hole.w * hole.h)
	for cy in range(hole.h):
		var c: int = _center(tcx, tcy, pcx, pcy, cy)
		for cx in range(hole.w):
			var d: int = absi(cx - c)
			var v: int
			if cy > pcy + 8:
				v = MHHole.LIE_OB
			elif d <= 5:
				v = MHHole.LIE_FAIRWAY
			elif d <= 9:
				v = MHHole.LIE_ROUGH
			elif d <= 22:
				v = MHHole.LIE_TREES
			else:
				v = MHHole.LIE_OB
			hole.lies[cy * hole.w + cx] = v
	var nb: int = rng.range_incl(2, 5)
	var bunkers: Array = []
	for _i in range(nb):
		var by: int = tcy + rng.range_incl(len_cells / 3, len_cells)
		var bx: int = _center(tcx, tcy, pcx, pcy, by) + rng.range_incl(-7, 7)
		var br: int = rng.range_incl(1, 3)
		bunkers.append([bx, by, br])
	var wf: int = rng.range_incl(0, 1)
	if wf == 1:
		var wy: int = tcy + rng.range_incl(len_cells / 2, len_cells - 4)
		var wx: int = _center(tcx, tcy, pcx, pcy, wy) + rng.range_incl(-6, 6)
		var wr: int = rng.range_incl(2, 4)
		_stamp(hole, wx, wy, wr, MODE_WATER)
	for b in bunkers:
		_stamp(hole, b[0], b[1], b[2], MODE_BUNKER)
	_stamp(hole, pcx, pcy, 3, MODE_GREEN)
	hole.tee_x = MHFixed.from_int(tcx * 4 + 2)
	hole.tee_y = MHFixed.from_int(tcy * 4 + 2)
	hole.pin_x = MHFixed.from_int(pcx * 4 + 2)
	hole.pin_y = MHFixed.from_int(pcy * 4 + 2)
	return hole


static func _lie_pct(lie: int) -> int:
	if lie == MHHole.LIE_ROUGH:
		return 85
	if lie == MHHole.LIE_BUNKER:
		return 70
	if lie == MHHole.LIE_TREES:
		return 50
	return 100


static func _push(trace: PackedInt64Array, kind: int, x: int, y: int, lie: int, strokes: int) -> void:
	trace.append(kind)
	trace.append(x)
	trace.append(y)
	trace.append(lie)
	trace.append(strokes)


## Returns {"strokes": int, "holed": int (0/1), "time": int (sim seconds), "trace": PackedInt64Array}.
## trace is 5 ints per event: kind, x, y, lie, strokes (empty when want_trace is false).
@warning_ignore("integer_division")
static func simulate_hole(hole: MHHole, skill: int, wind_x: int, wind_y: int, rng: MHRng, want_trace: bool) -> Dictionary:
	var px: int = hole.tee_x
	var py: int = hole.tee_y
	var lie: int = MHHole.LIE_TEE
	var strokes: int = 0
	var holed: int = 0
	var time_s: int = HOLE_TRANSIT_SECONDS
	var trace: PackedInt64Array = PackedInt64Array()
	while true:
		if strokes >= MAX_STROKES:
			if want_trace:
				_push(trace, KIND_PICKUP, px, py, lie, strokes)
			break
		var dx: int = hole.pin_x - px
		var dy: int = hole.pin_y - py
		var d: int = MHFixed.hypot(dx, dy)
		if lie == MHHole.LIE_GREEN:
			strokes += 1
			time_s += PUTT_SECONDS
			var dm: int = MHFixed.trunc_int(d)
			var pct: int
			if dm == 0:
				pct = 99
			else:
				pct = mini(maxi(90 + skill / 10 - dm * 9, 3), 99)
			var roll: int = rng.bounded(100)
			if roll < pct:
				holed = 1
				px = hole.pin_x
				py = hole.pin_y
				if want_trace:
					_push(trace, KIND_PUTT_HOLE, px, py, lie, strokes)
				break
			var f: int = rng.range_incl(6000, 24000)
			var nd: int = maxi(MHFixed.mul(d, f), 19661)
			var ang: int = rng.next_u32() & 0xFFFF
			px = hole.pin_x + MHFixed.mul(nd, MHTrig.cos_brad(ang))
			py = hole.pin_y + MHFixed.mul(nd, MHTrig.sin_brad(ang))
			if want_trace:
				_push(trace, KIND_PUTT_MISS, px, py, lie, strokes)
			continue
		strokes += 1
		time_s += SHOT_SECONDS
		var max_d: int = 150 * 65536 + skill * 85196
		var max_eff: int = max_d * _lie_pct(lie) / 100
		var t: int = mini(d, max_eff)
		var base: int = MHTrig.atan2_brad(dy, dx)
		var cb: int = MHTrig.cos_brad(base)
		var sb: int = MHTrig.sin_brad(base)
		var tries: int = 0
		while tries < 3:
			var al: int = hole.lie_at(px + MHFixed.mul(t, cb), py + MHFixed.mul(t, sb))
			if al != MHHole.LIE_WATER and al != MHHole.LIE_OB:
				break
			t = maxi(t - 25 * 65536, 20 * 65536)
			tries += 1
		var g1: int = rng.gauss_q16()
		var sd: int = 900 - 7 * skill
		var ang_err: int = MHFixed.trunc_int(MHFixed.mul(g1, sd * 65536))
		var angle: int = (base + ang_err) & 0xFFFF
		var g2: int = rng.gauss_q16()
		var derr: int = 8192 - 50 * skill
		var dist: int = t + MHFixed.mul(MHFixed.mul(t, derr), g2)
		dist = maxi(dist, 65536)
		var wfac: int = MHFixed.mul(dist, WIND_K)
		var nx: int = px + MHFixed.mul(dist, MHTrig.cos_brad(angle)) + MHFixed.mul(wind_x, wfac)
		var ny: int = py + MHFixed.mul(dist, MHTrig.sin_brad(angle)) + MHFixed.mul(wind_y, wfac)
		var nl: int = hole.lie_at(nx, ny)
		if nl == MHHole.LIE_WATER or nl == MHHole.LIE_OB:
			strokes += 1
			time_s += PENALTY_SECONDS
			if want_trace:
				_push(trace, KIND_PENALTY, nx, ny, nl, strokes)
		else:
			px = nx
			py = ny
			lie = nl
			if want_trace:
				_push(trace, KIND_FULL, px, py, lie, strokes)
	return {"strokes": strokes, "holed": holed, "time": time_s, "trace": trace}


static func trace_hash_hex(trace: PackedInt64Array) -> String:
	var f: MHHash = MHHash.new()
	for i in range(trace.size()):
		f.add_i64(trace[i])
	return f.hex()
