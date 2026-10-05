class_name MHTournamentRules
extends RefCounted
## Pure rules for hosting a tournament: entry checklist, snapshot score, facility points, event prestige, purse.
## Everything is a static function of its arguments (no state, no clock, no RNG). Integer only.
##
## The "view" Dictionary describes the club today (all optional, default 0):
##   "holes"           valid, non-dead holes (MHGateView.holes)
##   "avg_hole_score"  0..100 integer average over all holes (MHGateView.avg_hole_score)
##   "pace_score"      0..100 (rating engine pace score from a sim day)
##   "staff"           staff head count
##   "tiers"           Dictionary building_id -> purchased tier (0 or absent = not built)
@warning_ignore_start("integer_division")


## Entry checklist for a level as an MHGateReport. Row keys: holes, avg_hole_score, pace_score,
## building:<id>, staff, spectators. Row shape [key, met, have, need] (same as the building gates and the UI).
static func entry_report(defs: MHTournamentDefs, level_id: String, view: Dictionary) -> MHGateReport:
	var rep: MHGateReport = MHGateReport.new()
	if not defs.has_level(level_id):
		rep.add("unknown_level", false, 0, 1)
		rep.finish()
		return rep
	var e: Dictionary = defs.entry(level_id)
	var tiers: Dictionary = view.get("tiers", {}) as Dictionary
	var holes: int = int(view.get("holes", 0))
	var avg: int = int(view.get("avg_hole_score", 0))
	var pace: int = int(view.get("pace_score", 0))
	var staff: int = int(view.get("staff", 0))
	rep.add("holes", holes >= int(e["min_holes"]), holes, int(e["min_holes"]))
	rep.add("avg_hole_score", avg >= int(e["min_avg_hole_score"]), avg, int(e["min_avg_hole_score"]))
	rep.add("pace_score", pace >= int(e["min_pace_score"]), pace, int(e["min_pace_score"]))
	for b: Variant in (e["buildings"] as Array):
		var bd: Dictionary = b
		var bid: String = str(bd["building"])
		var have_t: int = int(tiers.get(bid, 0))
		rep.add("building:" + bid, have_t >= int(bd["min_tier"]), have_t, int(bd["min_tier"]))
	rep.add("staff", staff >= int(e["min_staff"]), staff, int(e["min_staff"]))
	var cap: int = defs.spectator_capacity(int(tiers.get("clubhouse", 0)))
	rep.add("spectators", cap >= int(e["min_spectator_capacity"]), cap, int(e["min_spectator_capacity"]))
	rep.finish()
	return rep


## Highest level (by rank) whose entry checklist is fully met. "" when none.
static func highest_eligible_level(defs: MHTournamentDefs, view: Dictionary) -> String:
	var best: String = ""
	for lid: Variant in defs.level_ids():
		if entry_report(defs, str(lid), view).met:
			best = str(lid)
	return best


## Snapshot score (0..100) from the club's recent daily course scores, oldest first (spec 11, adapted to days).
## Takes the last snapshot_window_days values. Fewer than sustained_min_days values gives 0 (not enough history).
## Result = min(latest, lower median of the window), so a last-day makeover cannot raise it.
static func snapshot_score(defs: MHTournamentDefs, daily_scores: Array) -> int:
	var p: Dictionary = defs.prestige_params()
	var window: int = int(p["snapshot_window_days"])
	var need: int = int(p["sustained_min_days"])
	var n: int = daily_scores.size()
	if n < need:
		return 0
	var start: int = maxi(0, n - window)
	var vals: Array = []
	for i: int in range(start, n):
		vals.append(clampi(int(daily_scores[i]), 0, 100))
	var sorted_vals: Array = _sorted_ints(vals)
	var med: int = int(sorted_vals[(sorted_vals.size() - 1) / 2])
	return mini(med, int(vals[vals.size() - 1]))


## Facilities part of prestige in permille: each facility building counts its tier up to the cap (4).
static func facility_permille(defs: MHTournamentDefs, tiers: Dictionary) -> int:
	var p: Dictionary = defs.prestige_params()
	var cap: int = int(p["facility_tier_cap"])
	var blds: Array = p["facility_buildings"]
	if blds.is_empty():
		return 0
	var sum: int = 0
	for b: Variant in blds:
		sum += mini(cap, maxi(0, int(tiers.get(str(b), 0))))
	return sum * 1000 / (blds.size() * cap)


## Number of holes whose fairness (0..100) is under the "unfair" line.
static func unfair_holes(defs: MHTournamentDefs, fairness: Array) -> int:
	var below: int = int(defs.evaluation()["unfair_fairness_below"])
	var n: int = 0
	for f: Variant in fairness:
		if int(f) < below:
			n += 1
	return n


## Field satisfaction in permille: 1000 minus the condition penalty minus the unfair-hole penalty, clamped 0..1000.
static func satisfaction_permille(defs: MHTournamentDefs, condition: Dictionary, unfair_count: int) -> int:
	var pen: int = int(condition.get("satisfaction_penalty_pm", 0))
	pen += unfair_count * int(defs.evaluation()["unfair_satisfaction_penalty_pm"])
	return clampi(1000 - pen, 0, 1000)


## Event prestige 0..1000 from the weights in the data: course (snapshot score), pace, facilities, satisfaction.
## Tier 5 buildings never count (facility_permille caps at tier 4).
static func event_prestige_permille(defs: MHTournamentDefs, snapshot: int, pace_score: int, tiers: Dictionary, satisfaction_pm: int) -> int:
	var w: Dictionary = defs.prestige_params()["weights_permille"]
	var total: int = 0
	total += int(w["course_score"]) * clampi(snapshot, 0, 100) * 10
	total += int(w["pace"]) * clampi(pace_score, 0, 100) * 10
	total += int(w["facilities"]) * facility_permille(defs, tiers)
	total += int(w["field_satisfaction"]) * clampi(satisfaction_pm, 0, 1000)
	return clampi(total / 1000, 0, 1000)


## Club prestige points a SUCCESSFUL event awards: prestige_base scaled by the event prestige (permille).
static func prestige_points_awarded(defs: MHTournamentDefs, level_id: String, event_prestige_pm: int) -> int:
	return defs.level_int(level_id, "prestige_base") * clampi(event_prestige_pm, 0, 1000) / 1000


## Purse (whole dollars) per finishing place, index 0 = winner. The purse is paid out of the host cost, not on top
## of it. Each place gets floor(purse x permille / 1000); the rounding remainder goes to first place so the table
## always sums to the purse exactly.
static func purse_table(defs: MHTournamentDefs, level_id: String) -> Array:
	var pu: Dictionary = defs.purse()
	var total: int = defs.level_int(level_id, "host_cost") * int(pu["pct_of_host_cost"]) / 100
	var out: Array = []
	var paid: int = 0
	for pm: Variant in (pu["places_permille"] as Array):
		var amt: int = total * int(pm) / 1000
		out.append(amt)
		paid += amt
	if not out.is_empty():
		out[0] = int(out[0]) + (total - paid)
	return out


## Refund (whole dollars) when an event is cancelled while it is still being prepared.
static func cancel_refund(defs: MHTournamentDefs, level_id: String) -> int:
	return defs.level_int(level_id, "host_cost") * defs.cancel_refund_pct() / 100


## Ascending copy of an int Array (insertion sort, no Callable, deterministic).
static func _sorted_ints(vals: Array) -> Array:
	var out: Array = []
	for v: Variant in vals:
		var x: int = int(v)
		var pos: int = out.size()
		while pos > 0 and int(out[pos - 1]) > x:
			pos -= 1
		out.insert(pos, x)
	return out
