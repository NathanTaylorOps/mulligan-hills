class_name MHRatingEngine
extends RefCounted
## Deterministic hole and course rating, MHRATE-1.0.0 (docs/spec/rating/rating-engine.md, golfer-sim.md).
## Integer only. Mirror of tools/reference/rating/rating_eng.py. NOT YET RUN in Godot (see docs/phase1/rating.md).
##
## ctx Dictionary (all optional except the seed source):
##   "hole_seed": int            explicit 32-bit seed (daily challenge, tournament); else derived from the next two
##   "save_secret": int, "rating_epoch": int      seed = H32(save_secret, rating_epoch, slot_id, 0x4D48)
##   "condition": {"wx": int, "wy": int, "rain": int}   default calm {0, 0, 0} (the official condition)
##   "preview": bool             N = 30 estimate, never feeds gates
## hole_def (Dictionary, RHI v1): slot_id, tee [x, y], green [x, y, r], tee_z_mm, green_z_mm, features [...].
## The Phase 0 MHShotSim is a separate benchmark sim and is not used here.
@warning_ignore_start("integer_division")

const RATING_VERSION: String = "MHRATE-1.0.0"
const SIM_VERSION: String = "MHSIM-1.0.0"
const CY: int = 100


static func validate_input(raw: Variant) -> Dictionary:
	return MHRValidate.validate_input(raw)


static func _int_ctx(ctx: Dictionary, key: String, dflt: int) -> int:
	return int(ctx.get(key, dflt))


static func _cond(ctx: Dictionary) -> Vector3i:
	var c: Variant = ctx.get("condition", null)
	if typeof(c) != TYPE_DICTIONARY:
		return Vector3i(0, 0, 0)
	var d: Dictionary = c
	return Vector3i(int(d.get("wx", 0)), int(d.get("wy", 0)), clampi(int(d.get("rain", 0)), 0, 3))


static func seed_for(slot_id: int, ctx: Dictionary) -> int:
	if ctx.has("hole_seed"):
		return int(ctx["hole_seed"]) & MHRMath.M32
	return MHRMath.hole_seed(_int_ctx(ctx, "save_secret", 0), _int_ctx(ctx, "rating_epoch", 0), slot_id)


static func _invalid(h: MHRHole, reasons: Array, par: int, means: Array) -> Dictionary:
	return {"valid": false, "score_pm": 0, "score": 0, "A": 0, "I": 0, "Len": 0, "B": 0, "F": 0, "par": par,
		"L": h.L, "reasons": reasons.duplicate(), "all_reasons": reasons.duplicate(), "means": means,
		"forced_pm": 0, "pickup_pm": 0, "tree_pm": 0, "risk_pm": 0, "comps": 1, "raw_corr": 0, "pace_pm": 0,
		"dead": false, "hash": "", "content_hash": "", "engine_version": RATING_VERSION, "sim_version": SIM_VERSION,
		"params_hash": MHRParams.params_hash}


## Rates one hole. Never raises: invalid input returns valid = false, score_pm = 0 and reason codes.
static func rate_hole(hole_def: Dictionary, ctx: Dictionary) -> Dictionary:
	if not MHRParams.ensure_loaded():
		return {"valid": false, "score_pm": 0, "score": 0, "reasons": ["ENGINE_PARAMS_MISSING"], "all_reasons": []}
	var h: MHRHole = MHRHole.from_def(hole_def)
	return rate_parsed(h, ctx)


## Validates untrusted input first (shared hole code, daily challenge). raw = {schema, engine, hole}.
static func rate_shared(raw: Variant, ctx: Dictionary) -> Dictionary:
	var v: Dictionary = MHRValidate.validate_input(raw)
	if not bool(v["ok"]):
		return {"valid": false, "score_pm": 0, "score": 0, "reasons": [v["code"]], "all_reasons": [v["code"]], "rejected": true}
	return rate_hole((raw as Dictionary)["hole"] as Dictionary, ctx)


static func rate_parsed(h: MHRHole, ctx: Dictionary) -> Dictionary:
	if not MHRParams.ensure_loaded():
		return {"valid": false, "score_pm": 0, "score": 0, "reasons": ["ENGINE_PARAMS_MISSING"], "all_reasons": []}
	if not h.valid:
		return _invalid(h, h.reasons, 0, [0, 0, 0, 0, 0, 0])
	var seed_v: int = seed_for(h.slot, ctx)
	var cond: Vector3i = _cond(ctx)
	var preview: bool = bool(ctx.get("preview", false))
	var counts: PackedInt32Array = MHRParams.preview_counts if preview else MHRParams.band_counts
	var sim: MHRSim = MHRSim.new(h, cond.x, cond.y, cond.z)
	sim.simulate(seed_v, counts)
	var n: int = sim.n_golfers
	var par: int = h.par
	var bm: Array = []
	var band_n: Array = [0, 0, 0, 0, 0, 0]
	var band_sum: Array = [0, 0, 0, 0, 0, 0]
	for g in range(n):
		var b: int = sim.rec_band[g]
		band_n[b] = int(band_n[b]) + 1
		band_sum[b] = int(band_sum[b]) + sim.rec_strokes[g]
	for b2 in range(6):
		bm.append(MHRMath.rdiv(int(band_sum[b2]) * 100, int(band_n[b2])))
	var a_pick: int = 0
	for g in range(n):
		if sim.rec_band[g] == 0 and (sim.rec_flags[g] & 4) != 0:
			a_pick += 1
	if a_pick == int(band_n[0]):
		var inv_r: Dictionary = _invalid(h, ["RC007"], par, bm)
		inv_r["hash"] = sim.sim_hash(seed_v)
		return inv_r
	# Accuracy (5.1)
	var sk_sum: int = 0
	var st_sum: int = 0
	for g in range(n):
		sk_sum += sim.rec_skill[g]
		st_sum += sim.rec_strokes[g]
	var sxy: int = 0
	var sxx: int = 0
	for g in range(n):
		var ds: int = sim.rec_skill[g] * n - sk_sum
		sxy += ds * (sim.rec_strokes[g] * n - st_sum)
		sxx += ds * ds
	var spread: int = 0
	if sxx != 0:
		spread = maxi(0, MHRMath.rdiv(-sxy * 100 * 530, sxx))
	var t_par: int = MHRParams.acc_target[par]
	var acc: int = 0
	if spread <= t_par:
		acc = 1000 * spread / t_par
	else:
		acc = maxi(400, 1000 - (spread - t_par) * 600 / t_par)
	var inversions: int = 0
	for i in range(5):
		if int(bm[i + 1]) < int(bm[i]) - 15:
			inversions += 1
	acc = MHRMath.clampi_inc(acc - mini(300, 100 * inversions), 0, 1000)
	# Fairness (5.2)
	var n_forced: int = 0
	var n_pick: int = 0
	var n_tree: int = 0
	var n_risk: int = 0
	for g in range(n):
		var fl: int = sim.rec_flags[g]
		if (fl & 1) != 0:
			n_forced += 1
		if (fl & 4) != 0:
			n_pick += 1
		if (fl & 8) != 0:
			n_tree += 1
		if (fl & 16) != 0:
			n_risk += 1
	var forced_pm: int = n_forced * 1000 / n
	var pickup_pm: int = n_pick * 1000 / n
	var tree_pm: int = n_tree * 1000 / n
	var risk_pm: int = n_risk * 1000 / n
	var over: int = maxi(0, int(bm[2]) - (par * 100 + 180))
	var fair: int = MHRMath.clampi_inc(1000 - mini(700, 2 * forced_pm) - mini(200, 2 * pickup_pm) - mini(100, tree_pm) - mini(250, 2 * over), 0, 1000)
	# Imagination (5.3)
	var raw_corr: int = corridor_runs(h)
	var comps: int = maxi(1, raw_corr)
	var oc: int = 0
	if comps == 2:
		oc = 800
	elif comps >= 3:
		oc = 1000
	var rr: int = 0
	if oc > 0:
		if risk_pm < 150:
			rr = 300 + 700 * risk_pm / 150
		elif risk_pm <= 500:
			rr = 1000
		elif risk_pm <= 750:
			rr = 1000 - (risk_pm - 500) * 700 / 250
		else:
			rr = maxi(0, 300 - (risk_pm - 750) * 300 / 250)
	var bend: int = 0
	if par > 3:
		var xs: PackedInt32Array = PackedInt32Array()
		var ys: PackedInt32Array = PackedInt32Array()
		for g in range(n):
			if sim.rec_band[g] == 2:
				xs.append(sim.rec_fx[g])
				ys.append(sim.rec_fy[g])
		xs.sort()
		ys.sort()
		var mid: int = (xs.size() - 1) / 2
		var mx: int = xs[mid]
		var my: int = ys[mid]
		var ax: int = mx - h.tee_x
		var ay: int = my - h.tee_y
		var bx: int = h.gx - mx
		var by: int = h.gy - my
		var la: int = MHRMath.isqrt(ax * ax + ay * ay)
		var lb: int = MHRMath.isqrt(bx * bx + by * by)
		if la > 0 and lb > 0:
			bend = absi(ax * by - ay * bx) * 1000 / (la * lb)
	var bend_s: int = mini(1000, maxi(0, bend - 60) * 1000 / 240)
	var elev: int = mini(1000, h.elev_mm() * 1000 / 5486)
	var shape: int = (600 * bend_s + 400 * elev) / 1000
	var imag: int = (450 * oc + 350 * rr + 200 * shape) / 1000
	imag = imag * mini(1000, 2 * fair) / 1000
	var len_ax: int = MHRMath.interp(MHRParams.length_table, h.L)
	var pq: int = (acc + imag + len_ax + fair) / 4
	var bp: Dictionary = beauty_parts(h)
	var beau: int = mini(int(bp["braw"]), pq + 300)
	var base: int = (MHRParams.w_a * acc + MHRParams.w_i * imag + MHRParams.w_l * len_ax + MHRParams.w_b * beau) / 1000
	var m: int = 400 + 600 * fair / 1000
	var c_n: int = 0
	var c_t: int = 0
	for g in range(n):
		if sim.rec_band[g] == 2:
			c_n += 1
			c_t += sim.rec_time[g]
	var pace: int = c_t * 1000 / (c_n * MHRParams.pace_std[par])
	var pace_pen: int = MHRMath.clampi_inc(MHRMath.fdiv(pace - 1150, 4), 0, 80)
	var score: int = MHRMath.clampi_inc(base * m / 1000 - pace_pen, 0, 1000)
	var res: Dictionary = {"valid": true, "score_pm": score, "score": MHRMath.rdiv(score, 10), "A": acc, "I": imag,
		"Len": len_ax, "B": beau, "F": fair, "par": par, "L": h.L, "means": bm, "forced_pm": forced_pm,
		"pickup_pm": pickup_pm, "tree_pm": tree_pm, "risk_pm": risk_pm, "raw_corr": raw_corr, "comps": comps,
		"pace_pm": pace, "pace_pen": pace_pen, "spread": spread, "T_par": t_par, "inversions": inversions,
		"over": over, "bend_s": bend_s, "elev": elev, "Oc": oc, "R": rr, "shape": shape, "PQ": pq,
		"B_raw": int(bp["braw"]), "n_tree": int(bp["n_tree"]), "raw_trees": h.tree_count(), "wat": int(bp["wat"]),
		"cats": int(bp["cats"]), "stacked": bool(bp["stacked"]), "dead": score < 250, "hash": sim.sim_hash(seed_v),
		"content_hash": h.content_hash(), "hole_seed": seed_v, "rating_epoch": _int_ctx(ctx, "rating_epoch", 0),
		"engine_version": RATING_VERSION, "sim_version": SIM_VERSION, "params_hash": MHRParams.params_hash,
		"preview": preview, "golfers": n}
	res["all_reasons"] = MHRAdvisor.hole_codes(res)
	res["reasons"] = MHRAdvisor.top_codes(res["all_reasons"] as Array)
	if bool(ctx.get("want_records", false)):
		res["records"] = {"gid": sim.rec_gid, "band": sim.rec_band, "skill": sim.rec_skill, "strokes": sim.rec_strokes,
			"flags": sim.rec_flags, "time_s": sim.rec_time, "fx": sim.rec_fx, "fy": sim.rec_fy}
	return res


## Largest number of separate playable corridors (>= 12 yd) over 4 slices (5.3 part 1).
static func corridor_runs(h: MHRHole) -> int:
	var best: int = 0
	var gx: int = h.gx - h.tee_x
	var gy: int = h.gy - h.tee_y
	var L: int = maxi(1, h.L)
	for pct in [25, 40, 55, 70]:
		var s: int = L * int(pct) / 100
		var runs: int = 0
		var run: int = 0
		for lat in range(-60, 62, 2):
			var px: int = h.tee_x + MHRMath.fdiv(gx * s - gy * lat, L)
			var py: int = h.tee_y + MHRMath.fdiv(gy * s + gx * lat, L)
			var lie: int = h.lie_at(px, py)
			var blocked: bool = lie == MHRHole.LIE_WATER or lie == MHRHole.LIE_OB or lie == MHRHole.LIE_BUNKER or lie == MHRHole.LIE_DEEP
			if not blocked and h.tree_hit(px, py, px, py, 1000):
				blocked = true
			if blocked:
				if run >= 6:
					runs += 1
				run = 0
			else:
				run += 1
		if run >= 6:
			runs += 1
		best = maxi(best, runs)
	return best


## Beauty parts (5.5). Returns pol, tr, wat, var, rel, n_tree (counted), wa, cats, stacked, braw.
static func beauty_parts(h: MHRHole) -> Dictionary:
	var gx: int = h.gx - h.tee_x
	var gy: int = h.gy - h.tee_y
	var lc: int = MHRMath.isqrt(gx * gx + gy * gy)
	var pol: int = 100
	var n: int = 0
	var ok: int = 0
	for yy in range(0, h.L, 10):
		var xx: int = h.tee_x + MHRMath.fdiv(gx * yy * CY, maxi(1, h.L * CY))
		n += 1
		var lie: int = h.lie_at(xx, h.tee_y + yy * CY)
		if lie == MHRHole.LIE_FAIRWAY or lie == MHRHole.LIE_GREEN or lie == MHRHole.LIE_FRINGE:
			ok += 1
	if n > 0 and ok * 100 >= 60 * n:
		pol += 50
	var cells: Dictionary = {}
	var stacked: bool = false
	for i in range(h.tree_count()):
		var tx: int = h.trees[i * 2]
		var ty: int = h.trees[i * 2 + 1]
		var rel: int = MHRMath.fdiv((tx - h.tee_x) * gy - (ty - h.tee_y) * gx, maxi(1, lc))
		if absi(rel) <= 60 * CY and ty >= -1000 and ty <= h.L * CY + 3000:
			var key: int = (MHRMath.fdiv(tx, 300) + 4096) * 8192 + (MHRMath.fdiv(ty, 300) + 4096)
			if cells.has(key):
				stacked = true
			cells[key] = true
	var nt: int = mini(60, cells.size())
	var tr: int = 120 * nt / (nt + 25)
	var wa: int = 0
	for xi in range(-60, 61, 4):
		for yi in range(0, h.L + 1, 4):
			if h.in_water(xi * CY + h.tee_x, yi * CY + h.tee_y):
				wa += 16
	var wat: int = 120 * wa / (wa + 800)
	var cats: int = 0
	if nt >= 3:
		cats += 1
	if h.rock_count >= 1:
		cats += 1
	if h.flower_count >= 3:
		cats += 1
	if wa >= 200:
		cats += 1
	if h.has_bunker():
		cats += 1
	var rel2: int = mini(100, h.elev_mm() * 100 / 5486)
	var braw: int = mini(700, pol + tr + wat + 25 * cats + rel2)
	return {"pol": pol, "tr": tr, "wat": wat, "var": 25 * cats, "rel": rel2, "n_tree": nt, "wa": wa, "cats": cats,
		"stacked": stacked, "braw": braw}


## Rolls rated holes up into a course score. holes: Array of MHRHole; results: per hole rate results.
static func rollup_course(holes: Array, results: Array) -> Dictionary:
	return MHRCourse.rollup(holes, results)


## Rates every hole in course order and rolls up. The seed of each hole uses its own slot_id.
## Returns {"course": rollup Dictionary, "holes": [hole results]}.
static func rate_course(hole_defs: Array, ctx: Dictionary) -> Dictionary:
	var holes: Array = []
	var results: Array = []
	for d in hole_defs:
		var h: MHRHole = MHRHole.from_def(d as Dictionary)
		holes.append(h)
		results.append(rate_parsed(h, ctx))
	return {"course": MHRCourse.rollup(holes, results), "holes": results}


## Advisor rows for a rated hole: [{code, severity}], at most 3, highest severity first.
static func explain(rating: Dictionary) -> Array:
	var rows: Array = []
	for c in (rating.get("reasons", []) as Array):
		rows.append({"code": String(c), "severity": MHRAdvisor.severity(String(c))})
	return rows
