class_name MHRCourse
extends RefCounted
## Course roll-up (rating-engine.md 7): duplicate descriptor, duplicate factor, 70/30 mean plus worst third,
## tier gates. Mirror of descriptor / similarity / rollup in tools/reference/rating/rating_eng.py.
@warning_ignore_start("integer_division")

const CY: int = 100


## 72 coverage cells: 6 bins along the tee to green axis x 3 bands of |lateral| (10, 25, 50 yd) x 4 types
## (water, bunker, tree, ob). Mirror invariant. Returns an empty array for an invalid hole.
static func descriptor(h: MHRHole) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not h.valid:
		return out
	var gx: int = h.gx - h.tee_x
	var gy: int = h.gy - h.tee_y
	var L: int = maxi(1, h.L)
	var cells: PackedInt32Array = PackedInt32Array()
	cells.resize(72)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(18)
	for s in range(0, L, 4):
		for lat in range(-50, 51, 4):
			var px: int = h.tee_x + MHRMath.fdiv(gx * s - gy * lat, L)
			var py: int = h.tee_y + MHRMath.fdiv(gy * s + gx * lat, L)
			var a: int = mini(5, s * 6 / L)
			var ab: int = absi(lat)
			var band: int = 0
			if ab > 25:
				band = 2
			elif ab > 10:
				band = 1
			var c: int = a * 3 + band
			counts[c] += 1
			if h.in_water(px, py):
				cells[c * 4] += 1
			if h.in_bunker(px, py):
				cells[c * 4 + 1] += 1
			if h.in_ob_feature(px, py):
				cells[c * 4 + 3] += 1
	for i in range(h.tree_count()):
		var rx: int = h.trees[i * 2] - h.tee_x
		var ry: int = h.trees[i * 2 + 1] - h.tee_y
		var s_yd: int = MHRMath.fdiv(MHRMath.fdiv(rx * gx + ry * gy, L * CY), CY)
		var lat_yd: int = MHRMath.fdiv(MHRMath.fdiv(rx * (-gy) + ry * gx, L * CY), CY)
		if s_yd >= 0 and s_yd < L and absi(lat_yd) <= 50:
			var a2: int = mini(5, s_yd * 6 / L)
			var ab2: int = absi(lat_yd)
			var band2: int = 0
			if ab2 > 25:
				band2 = 2
			elif ab2 > 10:
				band2 = 1
			cells[(a2 * 3 + band2) * 4 + 2] += 1
	for c2 in range(18):
		var tot: int = maxi(1, counts[c2])
		for t in range(4):
			var v: int = cells[c2 * 4 + t]
			if t == 2:
				out.append(mini(1000, v * 1000 / 20))
			else:
				out.append(mini(1000, v * 1000 / tot))
	return out


static func similarity(h1: MHRHole, d1: PackedInt32Array, h2: MHRHole, d2: PackedInt32Array) -> int:
	if d1.size() == 0 or d2.size() == 0:
		return 0
	var sum: int = 0
	for i in range(72):
		sum += absi(d1[i] - d2[i])
	var dc: int = sum / 3
	var dz: int = absi(MHRMath.fdiv(h1.green_z - h1.tee_z, 914) - MHRMath.fdiv(h2.green_z - h2.tee_z, 914))
	return 1000 - mini(1000, dc + 3 * absi(h1.L - h2.L) + 5 * dz + 20 * absi(h1.par - h2.par))


static func dup_factor(s: int) -> int:
	if s <= 700:
		return 1000
	return 1000 - 2 * (s - 700)


static func tier_reached(good: int, x10: int) -> int:
	var t: int = 1
	for tier in range(2, 6):
		if good >= MHRParams.hole_gates[tier - 2] and x10 >= MHRParams.score_gates[tier - 2]:
			t = tier
		else:
			break
	return t


## holes: Array of MHRHole in course order; results: per hole result Dictionaries (valid, score_pm, par, pace_pm used).
static func rollup(holes: Array, results: Array) -> Dictionary:
	var n: int = holes.size()
	if n == 0:
		return {"course_x10": 0, "mean": 0, "low_third": 0, "factors": [], "adj": [], "similar_s": [], "similar_j": [],
			"n_dup": 0, "valid_non_dead": 0, "n": 0, "invalid": 0, "tier": 1, "codes": {"per_hole": [], "course": []}}
	var ds: Array = []
	for h in holes:
		ds.append(descriptor(h as MHRHole))
	var adj: Array = []
	var facs: Array = []
	var sim_s: Array = []
	var sim_j: Array = []
	for i in range(n):
		var f: int = 1000
		var best_s: int = 0
		var best_j: int = -1
		if bool((results[i] as Dictionary)["valid"]):
			for j in range(i):
				if bool((results[j] as Dictionary)["valid"]):
					var sv: int = similarity(holes[i] as MHRHole, ds[i] as PackedInt32Array, holes[j] as MHRHole, ds[j] as PackedInt32Array)
					f = mini(f, dup_factor(sv))
					if sv > best_s:
						best_s = sv
						best_j = j
		facs.append(f)
		sim_s.append(best_s)
		sim_j.append(best_j)
		adj.append(int((results[i] as Dictionary)["score_pm"]) * f / 1000)
	# sort hole indices by (adj, index) ascending: selection by repeated minimum keeps the tie rule explicit
	var used: Array = []
	for i in range(n):
		used.append(false)
	var k: int = (n + 2) / 3
	var low_sum: int = 0
	for _pick in range(k):
		var bi: int = -1
		for i in range(n):
			if not bool(used[i]) and (bi < 0 or int(adj[i]) < int(adj[bi])):
				bi = i
		used[bi] = true
		low_sum += int(adj[bi])
	var total: int = 0
	for i in range(n):
		total += int(adj[i])
	var m_mean: int = total / n
	var w_low: int = low_sum / k
	var base: int = (70 * m_mean + 30 * w_low) / 100
	var pars: Dictionary = {}
	var good: int = 0
	var invalid: int = 0
	var n_dup: int = 0
	for i in range(n):
		var r: Dictionary = results[i]
		if bool(r["valid"]):
			pars[int(r["par"])] = true
			if int(r["score_pm"]) >= 250:
				good += 1
		else:
			invalid += 1
		if int(facs[i]) <= 500:
			n_dup += 1
	var few_pars: bool = n >= 6 and pars.size() < 2
	if few_pars:
		base = base * 920 / 1000
	var x10: int = MHRMath.clampi_inc(base, 0, 1000)
	var ro: Dictionary = {"course_x10": x10, "mean": m_mean, "low_third": w_low, "factors": facs, "adj": adj,
		"similar_s": sim_s, "similar_j": sim_j, "n_dup": n_dup, "valid_non_dead": good, "n": n, "invalid": invalid,
		"tier": tier_reached(good, x10)}
	ro["codes"] = MHRAdvisor.course_codes(ro, results, few_pars)
	return ro
