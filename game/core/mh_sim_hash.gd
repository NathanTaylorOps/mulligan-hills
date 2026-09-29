class_name MHSimHash
extends RefCounted
## Runs N golfers x M holes and hashes the complete result (FNV-1a 64 over every result and trace int).
## Mirror of run_sim_hash in tools/reference/determinism/mh_shotsim.py. Iteration order is plain
## for-loops over ints; no Dictionary iteration influences results.


static func golfer_skill(g: int) -> int:
	return 10 + (g * 37) % 90


static func wind_x_for_hole(h: int) -> int:
	return ((h * 5 + 3) % 11 - 5) * 65536


static func wind_y_for_hole(h: int) -> int:
	return ((h * 7 + 1) % 9 - 4) * 65536


## Returns {"hash": String (empty when want_hash is false), "total_strokes": int, "max_time": int}.
## max_time = the longest golfer round in simulated seconds (golfers play concurrently).
static func run(course_seed: int, base_seed: int, n_golfers: int, n_holes: int, want_hash: bool) -> Dictionary:
	var holes: Array = []
	for i in range(n_holes):
		holes.append(MHShotSim.make_hole(course_seed, i))
	return run_with_holes(holes, base_seed, n_golfers, want_hash)


static func run_with_holes(holes: Array, base_seed: int, n_golfers: int, want_hash: bool) -> Dictionary:
	var f: MHHash = MHHash.new()
	var total_strokes: int = 0
	var max_time: int = 0
	var n_holes: int = holes.size()
	for g in range(n_golfers):
		var skill: int = golfer_skill(g)
		var gtime: int = 0
		for hi in range(n_holes):
			var rng: MHRng = MHRng.new(base_seed + g, g * 256 + hi)
			var res: Dictionary = MHShotSim.simulate_hole(holes[hi], skill, wind_x_for_hole(hi), wind_y_for_hole(hi), rng, want_hash)
			var strokes: int = res["strokes"]
			var tm: int = res["time"]
			total_strokes += strokes
			gtime += tm
			if want_hash:
				var trace: PackedInt64Array = res["trace"]
				f.add_i64(g)
				f.add_i64(hi)
				f.add_i64(strokes)
				f.add_i64(res["holed"])
				f.add_i64(tm)
				f.add_i64(trace.size())
				for k in range(trace.size()):
					f.add_i64(trace[k])
		if gtime > max_time:
			max_time = gtime
	return {"hash": f.hex() if want_hash else "", "total_strokes": total_strokes, "max_time": max_time}
