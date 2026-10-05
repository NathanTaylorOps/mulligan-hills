class_name MHRSim
extends RefCounted
## Golfer simulation MHSIM-1.0.0 (docs/spec/rating/golfer-sim.md). Mirror of the sim half of
## tools/reference/rating/rating_core.py. Integer only; every random value is a pure function of
## (hole_seed, golfer, shot, channel). The Phase 0 MHShotSim is a separate benchmark sim and is not used.
## One instance simulates one hole under one weather condition. Not re-entrant, not thread safe.
@warning_ignore_start("integer_division")

const CY: int = 100

var hole: MHRHole
var wx: int = 0
var wy: int = 0
var rain: int = 0
var cache: Dictionary = {}          # key -> [costs PackedInt32Array, pens PackedInt32Array, here int]
# land() results (members avoid allocation in the hot loop)
var r_x: int = 0
var r_y: int = 0
var r_lie: int = 0
var r_pen: int = 0
var r_kind: int = 0                 # 1 water penalty, 2 out of bounds penalty
var r_tree: bool = false
var r_walk: int = 0
# candidate lattice (28 aim points) and distance to green from the position it was built for
var cand_x: PackedInt32Array = PackedInt32Array()
var cand_y: PackedInt32Array = PackedInt32Array()
var cand_dg: int = 0
# per golfer records, gid order
var n_golfers: int = 0
var rec_gid: PackedInt32Array = PackedInt32Array()
var rec_band: PackedInt32Array = PackedInt32Array()
var rec_skill: PackedInt32Array = PackedInt32Array()
var rec_strokes: PackedInt32Array = PackedInt32Array()
var rec_flags: PackedInt32Array = PackedInt32Array()
var rec_time: PackedInt32Array = PackedInt32Array()
var rec_fx: PackedInt32Array = PackedInt32Array()
var rec_fy: PackedInt32Array = PackedInt32Array()


func _init(h: MHRHole, wind_x: int, wind_y: int, rain_level: int) -> void:
	hole = h
	wx = wind_x
	wy = wind_y
	rain = rain_level


static func es_here(lie: int, dist_cy: int, skill: int) -> int:
	var v: int = 0
	if lie == MHRHole.LIE_GREEN:
		v = MHRMath.interp(MHRParams.es_green, dist_cy * 3 / CY)
	else:
		v = MHRMath.interp(MHRParams.es_fw, dist_cy / CY) + MHRParams.lie_add[lie]
	return MHRMath.rdiv(v * (1350 - skill * 350 / 1000), 1000)


static func carry_max(club: int, skill: int, lie: int) -> int:
	return MHRParams.club_base[club] * CY * (600 + skill * 400 / 1000) / 1000 * MHRParams.lie_carry[lie] / 1000


static func pick_club(desired: int, skill: int, lie: int) -> int:
	for i in range(11, -1, -1):
		if carry_max(i, skill, lie) >= desired:
			return i
	return 0


static func pick_club_longest(skill: int, lie: int) -> int:
	for i in range(12):
		if carry_max(i, skill, lie) > 0:
			return i
	return 0


static func spread_pm(skill: int) -> int:
	return 130 - skill * 90 / 1000


static func depth_pm(skill: int) -> int:
	return 25 + (1000 - skill) * 35 / 1000


static func mishit_pm(skill: int) -> int:
	return 30 + (1000 - skill) * 200 / 1000


static func style_of(gid: int) -> int:
	var r: int = MHRMath.h32b(0xC0FFEE, gid) % 100
	if r < 25:
		return 0
	if r < 75:
		return 1
	return 2


static func putt_count(d_cy: int, skill: int, roll: int) -> int:
	var ft: int = d_cy * 3 / CY
	var base: int = 25
	var pb: PackedInt32Array = MHRParams.putt_base
	for i in range(pb.size() / 2):
		if ft <= pb[i * 2]:
			base = pb[i * 2 + 1]
			break
	var p1: int = base * (500 + skill / 2) / 1000
	var p3: int = mini(600, ft * 6 * (1100 - skill) / 1000)
	if roll < p1:
		return 1
	if roll >= 1000 - p3:
		return 3
	return 2


## One ball flight. Results in r_x, r_y, r_lie, r_pen, r_kind, r_tree, r_walk.
func land(bx: int, by: int, lie0: int, ax: int, ay: int, skill: int, zl: int, zd: int, mroll: int, msev: int) -> void:
	var u: Vector3i = MHRMath.unit(ax - bx, ay - by)
	var ux: int = u.x
	var uy: int = u.y
	var ci: int = pick_club(u.z, skill, lie0)
	var deff: int = mini(u.z, carry_max(ci, skill, lie0))
	var disp: int = MHRParams.lie_disp[lie0]
	var sgm: int = MHRMath.interp(MHRParams.short_game, deff / CY)
	var sl: int = deff * spread_pm(skill) / 1000 * disp / 1000 * sgm / 1000
	var sd: int = deff * depth_pm(skill) / 1000 * disp / 1000 * sgm / 1000
	var dl: int = MHRMath.fdiv(zl * sl, 1000)
	var dd: int = MHRMath.fdiv(zd * sd, 1000)
	if mroll < mishit_pm(skill) * MHRParams.lie_mishit[lie0] / 1000:
		deff = deff * (500 + msev % 300) / 1000
		dl = dl * 2
	var loft: int = MHRParams.club_loft[ci]
	var wa: int = MHRMath.fdiv(wx * ux + wy * uy, 1024)
	var wc: int = MHRMath.fdiv(wx * (-uy) + wy * ux, 1024)
	var along_shift: int = MHRMath.fdiv(deff * wa * 8 * loft, 1000000)
	var lat_shift: int = MHRMath.fdiv(deff * wc * 6 * loft, 1000000)
	var along: int = maxi(0, deff + dd + along_shift) * (1000 - 40 * rain) / 1000
	var lat: int = dl + lat_shift
	var px: int = -uy
	var py: int = ux
	var tx: int = bx + MHRMath.rdiv(ux * along + px * lat, 1024)
	var ty: int = by + MHRMath.rdiv(uy * along + py * lat, 1024)
	var lie: int = 0
	r_tree = false
	if hole.tree_hit(bx, by, tx, ty, MHRParams.tmax[ci]):
		r_tree = true
		var hx: int = hole.hit_x
		var hy: int = hole.hit_y
		var bu: Vector3i = MHRMath.unit(hx - bx, hy - by)
		var back: int = mini(bu.z, 100)
		tx = hx - MHRMath.fdiv(bu.x * back, 1024)
		ty = hy - MHRMath.fdiv(bu.y * back, 1024)
		lie = hole.lie_at(tx, ty)
		if lie != MHRHole.LIE_GREEN and lie != MHRHole.LIE_WATER and lie != MHRHole.LIE_OB:
			lie = MHRHole.LIE_DEEP
	else:
		lie = hole.lie_at(tx, ty)
	var wdx: int = tx - bx
	var wdy: int = ty - by
	r_walk = MHRMath.isqrt(wdx * wdx + wdy * wdy)
	r_pen = 0
	r_kind = 0
	if lie == MHRHole.LIE_OB:
		r_x = bx
		r_y = by
		r_lie = lie0
		r_pen = 1
		r_kind = 2
		return
	if lie == MHRHole.LIE_WATER:
		r_pen = 1
		r_kind = 1
		var vu: Vector3i = MHRMath.unit(tx - bx, ty - by)
		var step: int = 0
		while step * 200 < vu.z:
			step += 1
			var cx: int = tx - MHRMath.fdiv(vu.x * step * 200, 1024)
			var cyy: int = ty - MHRMath.fdiv(vu.y * step * 200, 1024)
			var l2: int = hole.lie_at(cx, cyy)
			if l2 != MHRHole.LIE_WATER and l2 != MHRHole.LIE_OB:
				r_x = cx
				r_y = cyy
				r_lie = l2
				return
		r_x = bx
		r_y = by
		r_lie = lie0
		return
	r_x = tx
	r_y = ty
	r_lie = lie


## Fills cand_x / cand_y (28 aim points, index fi * 7 + (j + 3)) and cand_dg.
func candidates(px_: int, py_: int, lie: int, skill: int) -> void:
	var u: Vector3i = MHRMath.unit(hole.gx - px_, hole.gy - py_)
	var dg: int = u.z
	cand_dg = dg
	var dm: int = carry_max(pick_club_longest(skill, lie), skill, lie)
	var base: int = mini(dm, dg)
	var sp: int = MHRMath.clampi_inc(dg / 16, 300, 1000)
	var qx: int = -u.y
	var qy: int = u.x
	cand_x.resize(28)
	cand_y.resize(28)
	var k: int = 0
	for fi in range(4):
		var dd: int = base * MHRParams.fracs[fi] / 1000
		for j in range(-3, 4):
			cand_x[k] = px_ + MHRMath.fdiv(u.x * dd + qx * j * sp, 1024)
			cand_y[k] = py_ + MHRMath.fdiv(u.y * dd + qy * j * sp, 1024)
			k += 1


## Cost table for the cell centre (px_, py_): [costs, pens, here]. Deterministic, no RNG.
func plan_table(px_: int, py_: int, lie: int, skill: int) -> Array:
	candidates(px_, py_, lie, skill)
	var here: int = es_here(lie, cand_dg, skill)
	var costs: PackedInt32Array = PackedInt32Array()
	var pens_l: PackedInt32Array = PackedInt32Array()
	var ps: PackedInt32Array = MHRParams.plan_samples
	for c in range(28):
		var ax: int = cand_x[c]
		var ay: int = cand_y[c]
		var tot: int = 0
		var pens: int = 0
		for s in range(8):
			land(px_, py_, lie, ax, ay, skill, ps[s * 2], ps[s * 2 + 1], 999, 0)
			var ddx: int = r_x - hole.gx
			var ddy: int = r_y - hole.gy
			var dist2: int = MHRMath.isqrt(ddx * ddx + ddy * ddy)
			tot += 100 + es_here(r_lie, dist2, skill) + r_pen * 100
			pens += r_pen
		costs.append(MHRMath.rdiv(tot, 8))
		pens_l.append(pens)
	return [costs, pens_l, here]


## Simulates every golfer. counts = golfers per band (120 official, 30 preview).
func simulate(seed_v: int, counts: PackedInt32Array) -> void:
	var cap: int = hole.par + 4
	n_golfers = 0
	for b in range(6):
		n_golfers += counts[b]
	rec_gid.resize(n_golfers)
	rec_band.resize(n_golfers)
	rec_skill.resize(n_golfers)
	rec_strokes.resize(n_golfers)
	rec_flags.resize(n_golfers)
	rec_time.resize(n_golfers)
	rec_fx.resize(n_golfers)
	rec_fy.resize(n_golfers)
	var z: PackedInt32Array = MHRParams.z256
	var gid: int = 0
	for band in range(6):
		var lo: int = MHRParams.band_lo[band]
		var hi: int = MHRParams.band_hi[band]
		var n: int = counts[band]
		var bmid: int = (lo + hi) / 2
		for nid in range(n):
			var skill: int = lo + (hi - lo) * (2 * nid + 1) / (2 * n)
			var style: int = style_of(gid)
			var amp: int = (1000 - skill) * 30 / 1000
			var x: int = hole.tee_x
			var y: int = hole.tee_y
			var lie: int = MHRHole.LIE_TEE
			var strokes: int = 0
			var shot: int = 1
			var flags: int = 0
			var walk: int = 0
			var tsec: int = 0
			var have_first: bool = false
			var first_x: int = 0
			var first_y: int = 0
			while true:
				if lie == MHRHole.LIE_GREEN:
					var gdx: int = x - hole.gx
					var gdy: int = y - hole.gy
					var np: int = putt_count(MHRMath.isqrt(gdx * gdx + gdy * gdy), skill, MHRMath.h32d(seed_v, nid, shot, 4) % 1000)
					strokes += np
					tsec += 25 * np
					if strokes > cap:
						strokes = cap
						flags |= 4
					break
				var fx: int = MHRMath.fdiv(x, 400)
				var fy: int = MHRMath.fdiv(y, 400)
				var key: int = (((fx + 2048) * 4096 + (fy + 2048)) * 8 + lie) * 8 + band
				if not cache.has(key):
					cache[key] = plan_table(fx * 400 + 200, fy * 400 + 200, lie, bmid)
				var entry: Array = cache[key]
				var costs: PackedInt32Array = entry[0]
				var pens_l: PackedInt32Array = entry[1]
				var here: int = entry[2]
				candidates(x, y, lie, bmid)
				var best_adj: int = 0
				var idx: int = 0
				for i in range(28):
					var nz: int = MHRMath.rdiv(amp * ((MHRMath.h32d(seed_v, gid, shot, 10 + i) & 1023) - 512), 512)
					var adj: int = costs[i] + MHRParams.style_w[style] * pens_l[i] + nz
					if i == 0 or adj < best_adj:
						best_adj = adj
						idx = i
				var pens: int = pens_l[idx]
				var safe: bool = false
				for i in range(28):
					if pens_l[i] <= 1 and costs[i] <= here + 160:
						safe = true
						break
				if pens >= 2 and safe:
					flags |= 16
				var zl: int = z[MHRMath.h32d(seed_v, nid, shot, 0) & 255]
				var zd: int = z[MHRMath.h32d(seed_v, nid, shot, 1) & 255]
				var mroll: int = MHRMath.h32d(seed_v, nid, shot, 2) % 1000
				var msev: int = MHRMath.h32d(seed_v, nid, shot, 3)
				land(x, y, lie, cand_x[idx], cand_y[idx], skill, zl, zd, mroll, msev)
				strokes += 1 + r_pen
				walk += r_walk
				tsec += 40
				if lie == MHRHole.LIE_BUNKER:
					tsec += 30
				if r_kind == 1:
					tsec += 90
				elif r_kind == 2:
					tsec += 150
				if r_tree:
					flags |= 8
				if r_pen > 0:
					if pens >= 2 and safe:
						flags |= 2
					elif pens >= 2:
						flags |= 1
					else:
						flags |= 32
				if not have_first:
					have_first = true
					first_x = r_x
					first_y = r_y
				x = r_x
				y = r_y
				lie = r_lie
				if lie == MHRHole.LIE_TEE:
					lie = MHRHole.LIE_FAIRWAY
				shot += 1
				if strokes >= cap or shot > 40:
					strokes = cap
					flags |= 4
					break
			tsec += walk * 6 / 1000
			rec_gid[gid] = gid
			rec_band[gid] = band
			rec_skill[gid] = skill
			rec_strokes[gid] = strokes
			rec_flags[gid] = flags
			rec_time[gid] = tsec
			rec_fx[gid] = first_x
			rec_fy[gid] = first_y
			gid += 1


## MH-HASH64 of the sim result record (spec golfer-sim.md section 13).
func sim_hash(seed_v: int) -> String:
	var b: PackedByteArray = PackedByteArray()
	MHRMath.push_ascii(b, MHRParams.ENGINE_VERSION + "|" + MHRParams.SIM_VERSION + "|")
	MHRMath.push_i32(b, seed_v)
	MHRMath.push_i32(b, n_golfers)
	for g in range(n_golfers):
		MHRMath.push_i32(b, rec_gid[g])
		MHRMath.push_i32(b, rec_strokes[g])
		MHRMath.push_i32(b, rec_flags[g])
		MHRMath.push_i32(b, rec_time[g])
		MHRMath.push_i32(b, rec_fx[g])
		MHRMath.push_i32(b, rec_fy[g])
	return MHRMath.hash64(b)
