class_name MHRTournament
extends RefCounted
## Tournament sustained score and prestige (rating-engine.md 11), leaderboard tie-break (12), and the small
## advisor triggers that need no simulation (RC009, RC010, RC071 to RC076, RC081).
## Mirror of the tail of tools/reference/rating/rating_eng.py. The field simulation, lock and cooldown rules
## are owned by the calendar and tournament features; only the formulas are here.
@warning_ignore_start("integer_division")


## SS = min(current, median of the last 8 checkpoints); missing checkpoints count as 0.
static func sustained(checkpoints: Array) -> int:
	var last: Array = []
	for i in range(8):
		last.append(0)
	for c in checkpoints:
		last.append(int(c))
	var tail: Array = last.slice(last.size() - 8)
	tail.sort()
	var med: int = (int(tail[3]) + int(tail[4])) / 2
	var cur: int = 0
	if checkpoints.size() > 0:
		cur = int(checkpoints[checkpoints.size() - 1])
	return mini(med, cur)


## tiers: Clubhouse, Restaurant, ProShop, CartBarn, Maintenance (tiers 1 to 4 count).
static func facility_points(tiers: Array) -> int:
	var s: int = 0
	for t in tiers:
		s += mini(4, int(t))
	return mini(200, 10 * s)


static func prestige(sustained_x10: int, pace_pm: int, fac_pts: int, unfair_holes: int, recent_events: int) -> int:
	var course: int = 600 * sustained_x10 / 1000
	var pace: int = 200 * MHRMath.clampi_inc(2000 - pace_pm, 0, 1000) / 1000
	var raw: int = course + pace + mini(200, fac_pts) - 40 * unfair_holes
	return MHRMath.clampi_inc(MHRMath.fdiv(raw * (1000 - 100 * mini(5, recent_events)), 1000), 0, 1000)


static func tournament_codes(ss: int, n_checkpoints: int, snapshot_changed: bool, cooldown_active: bool, unfair_holes: int, mean_pace_pm: int) -> Array:
	var c: Array = []
	if ss < 520:
		c.append("RC071")
	if n_checkpoints < 8:
		c.append("RC072")
	if snapshot_changed:
		c.append("RC073")
	if cooldown_active:
		c.append("RC074")
	if unfair_holes >= 1:
		c.append("RC075")
	if mean_pace_pm > 1300:
		c.append("RC076")
	return c


static func wind_codes(calm_mean_x100: int, wind_mean_x100: int) -> Array:
	if wind_mean_x100 - calm_mean_x100 >= 40:
		return ["RC081"]
	return []


static func stale_codes(stored_engine_version: String) -> Array:
	if stored_engine_version != MHRParams.ENGINE_VERSION:
		return ["RC010"]
	return []


## RC009: indices of holes whose tee or green is within 10 yd of another hole's tee or green.
## origins[i] = [ox, oy] yards; tees_greens[i] = [[tx, ty], [gx, gy]] hole-local yards.
static func near_holes(origins: Array, tees_greens: Array) -> Array:
	var hit: Array = []
	var n: int = origins.size()
	for i in range(n):
		var close: bool = false
		for j in range(n):
			if i == j or close:
				continue
			for a in range(2):
				for b in range(2):
					var ax: int = int(origins[i][0]) + int(tees_greens[i][a][0])
					var ay: int = int(origins[i][1]) + int(tees_greens[i][a][1])
					var bx: int = int(origins[j][0]) + int(tees_greens[j][b][0])
					var by: int = int(origins[j][1]) + int(tees_greens[j][b][1])
					if (ax - bx) * (ax - bx) + (ay - by) * (ay - by) <= 100:
						close = true
		if close:
			hit.append(i)
	return hit


static func _entry_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a["score_pm"]) != int(b["score_pm"]):
		return int(a["score_pm"]) > int(b["score_pm"])
	if int(a["F"]) != int(b["F"]):
		return int(a["F"]) > int(b["F"])
	if int(a["recv_ms"]) != int(b["recv_ms"]):
		return int(a["recv_ms"]) < int(b["recv_ms"])
	return String(a["sub_id"]) < String(b["sub_id"])


## Leaderboard order (spec 12): score desc, fairness desc, server receive time asc, submission id asc.
static func rank(entries: Array) -> Array:
	var copy: Array = entries.duplicate()
	copy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return MHRTournament._entry_less(a, b))
	var out: Array = []
	for e in copy:
		out.append(String((e as Dictionary)["sub_id"]))
	return out
