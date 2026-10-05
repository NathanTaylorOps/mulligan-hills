class_name MHTournamentSim
extends RefCounted
## Deterministic tournament outcome. Pure functions of (data, event seed, course facts); every random draw comes
## from MHRng (PCG32) seeded with the event seed, never from randi/randf and never from the clock.
## Event seed = MHRMath.tournament_seed(save_secret, event_id, slot_id) = H32(secret, event_id, slot, 0x7E).
##
## Draw order (stable, tests pin golden results):
##   stream 1 : condition draw, exactly one rng.bounded(total_weight) over the conditions in FILE order.
##   stream 2 : field. First one range_incl(skill_min, skill_max) per player (player 0..F-1), then for each player
##              in order and each hole in order one gauss_q16().
## A field player's round: expected_x10 = floor((mid_skill - skill) x slope_x100 / 100) + total_yards x 10 / divisor
## + condition.strokes_x10 (tenths of a stroke over par for the whole round); per hole base_x100 = floor(expected_x10
## x 10 / holes); noise_x100 = floor(gauss_q16 x hole_sd_x100 / 37837) (sd of gauss_q16 is about 37837); strokes over
## par on a hole = clamp(round_half_away((base + noise) / 100), min_over_hole, max_over_hole).
## Ranking: total strokes, then last 9, 6, 3 and 1 holes (countback), then lowest H32(event_seed, player_id).
@warning_ignore_start("integer_division")

const STREAM_CONDITION: int = 1
const STREAM_FIELD: int = 2
const GAUSS_SD_Q16: int = 37837


## Unique id of one hosting, used as the event_id input of the event seed. Same day and level give the same id.
static func event_id(level_id: String, start_day: int) -> int:
	return start_day * 4 + MHTournamentDefs.level_rank(level_id) - 1


static func event_seed(save_secret: int, evt_id: int, slot_id: int) -> int:
	return MHRMath.tournament_seed(save_secret, evt_id, slot_id)


## One weighted condition (copy of the data row) drawn from the event seed.
static func draw_condition(defs: MHTournamentDefs, evt_seed: int) -> Dictionary:
	var conds: Array = defs.conditions()
	var total: int = 0
	for c: Variant in conds:
		total += int((c as Dictionary)["weight"])
	var rng: MHRng = MHRng.new(evt_seed, STREAM_CONDITION)
	var r: int = rng.bounded(total)
	var run: int = 0
	for c2: Variant in conds:
		run += int((c2 as Dictionary)["weight"])
		if r < run:
			return (c2 as Dictionary).duplicate(true)
	return (conds[conds.size() - 1] as Dictionary).duplicate(true)


## Pars of the event course: the given pars when 1..18 valid values, otherwise the first min_holes default pars.
static func pars_for(defs: MHTournamentDefs, level_id: String, pars: Array) -> Array:
	var ok: bool = not pars.is_empty() and pars.size() <= 18
	for p: Variant in pars:
		if int(p) < 3 or int(p) > 5:
			ok = false
	if ok:
		var out: Array = []
		for p2: Variant in pars:
			out.append(int(p2))
		return out
	var defaults: Array = defs.default_pars()
	var n: int = mini(int(defs.entry(level_id)["min_holes"]), defaults.size())
	return defaults.slice(0, n)


## Simulates the field. Returns {"order": [player ids best first], "skills": [...], "totals": [...] (strokes),
## "strokes": [[per hole]...], "par_total", "n_holes", "winner", "winner_over_par"}.
static func run_field(defs: MHTournamentDefs, level_id: String, evt_seed: int, pars: Array, total_yards: int, condition: Dictionary) -> Dictionary:
	var ld: Dictionary = defs.level_data(level_id)
	var sc: Dictionary = defs.scoring()
	var fd: Dictionary = ld["field"]
	var field_size: int = int(ld["field_size"])
	var n: int = pars.size()
	var rng: MHRng = MHRng.new(evt_seed, STREAM_FIELD)
	var skills: Array = []
	for _p: int in range(field_size):
		skills.append(rng.range_incl(int(fd["skill_min"]), int(fd["skill_max"])))
	var diff_x10: int = maxi(0, total_yards) * 10 / int(sc["difficulty_divisor"])
	var cond_x10: int = int(condition.get("strokes_x10", 0))
	var par_total: int = 0
	for pr: Variant in pars:
		par_total += int(pr)
	var strokes: Array = []
	var totals: Array = []
	for pidx: int in range(field_size):
		var round_x10: int = MHRMath.fdiv((int(sc["mid_skill_pm"]) - int(skills[pidx])) * int(sc["slope_x100"]), 100) + diff_x10 + cond_x10
		var base_x100: int = MHRMath.fdiv(round_x10 * 10, n)
		var row: Array = []
		var tot: int = 0
		for h: int in range(n):
			var g: int = rng.gauss_q16()
			var noise_x100: int = MHRMath.fdiv(g * int(sc["hole_sd_x100"]), GAUSS_SD_Q16)
			var over: int = clampi(MHRMath.rdiv(base_x100 + noise_x100, 100), int(sc["min_over_hole"]), int(sc["max_over_hole"]))
			var s: int = int(pars[h]) + over
			row.append(s)
			tot += s
		strokes.append(row)
		totals.append(tot)
	var order: Array = []
	for pj: int in range(field_size):
		var pos: int = order.size()
		while pos > 0 and _better(pj, int(order[pos - 1]), strokes, totals, evt_seed):
			pos -= 1
		order.insert(pos, pj)
	var winner: int = int(order[0])
	return {
		"order": order,
		"skills": skills,
		"totals": totals,
		"strokes": strokes,
		"par_total": par_total,
		"n_holes": n,
		"winner": winner,
		"winner_over_par": int(totals[winner]) - par_total,
	}


## True when player a finishes ahead of player b (countback then hash, never a coin flip).
static func _better(a: int, b: int, strokes: Array, totals: Array, evt_seed: int) -> bool:
	if int(totals[a]) != int(totals[b]):
		return int(totals[a]) < int(totals[b])
	for last_n: int in [9, 6, 3, 1]:
		var sa: int = _tail_sum(strokes[a] as Array, last_n)
		var sb: int = _tail_sum(strokes[b] as Array, last_n)
		if sa != sb:
			return sa < sb
	var ha: int = MHRMath.h32b(evt_seed, a)
	var hb: int = MHRMath.h32b(evt_seed, b)
	if ha != hb:
		return ha < hb
	return a < b


static func _tail_sum(row: Array, count: int) -> int:
	var s: int = 0
	var start: int = maxi(0, row.size() - count)
	for i: int in range(start, row.size()):
		s += int(row[i])
	return s


## Full outcome of one event. ctx (all required unless noted):
##   "event_seed" int, "snapshot_score" 0..100 (stored when the event was started), "pace_score" 0..100,
##   "fairness" Array of 0..100 per hole, "maintenance_tier" int, "tiers" Dictionary building -> tier,
##   "pars" Array (optional, defaults used when missing), "total_yards" int (course length).
## Result keys: level, success, failed_triggers (Array of String), condition_id, unfair_holes, satisfaction_pm,
## event_prestige_pm, cash_delta, entry_income, ticket_income, reputation_delta, prestige_points (club prestige
## awarded), cooldown_days, winner, winner_over_par, order, totals, purse (Array of dollars per place), pars.
## Only triggers listed in the level's failure.triggers can fail an event.
static func evaluate(defs: MHTournamentDefs, level_id: String, ctx: Dictionary) -> Dictionary:
	var ld: Dictionary = defs.level_data(level_id)
	if ld.is_empty():
		return {}
	var ev: Dictionary = defs.evaluation()
	var e: Dictionary = ld["entry"]
	var evt_seed: int = int(ctx.get("event_seed", 0))
	var snapshot: int = int(ctx.get("snapshot_score", 0))
	var pace: int = int(ctx.get("pace_score", 0))
	var tiers: Dictionary = ctx.get("tiers", {}) as Dictionary
	var fairness: Array = ctx.get("fairness", []) as Array
	var pars: Array = pars_for(defs, level_id, ctx.get("pars", []) as Array)
	var cond: Dictionary = draw_condition(defs, evt_seed)
	var unfair: int = MHTournamentRules.unfair_holes(defs, fairness)
	var wanted: Array = (ld["failure"] as Dictionary)["triggers"]
	var failed: Array = []
	if wanted.has("slow_pace") and pace < int(e["min_pace_score"]) - int(ev["pace_fail_margin"]):
		failed.append("slow_pace")
	if wanted.has("unfair_hole") and unfair >= int(ev["unfair_holes_to_fail"]):
		failed.append("unfair_hole")
	if wanted.has("bad_conditions") and int(ctx.get("maintenance_tier", 0)) < int(cond["min_maintenance_tier"]):
		failed.append("bad_conditions")
	if wanted.has("low_snapshot_score") and snapshot < int(e["min_avg_hole_score"]) - int(ev["score_fail_margin"]):
		failed.append("low_snapshot_score")
	var sat: int = MHTournamentRules.satisfaction_permille(defs, cond, unfair)
	var prestige_pm: int = MHTournamentRules.event_prestige_permille(defs, snapshot, pace, tiers, sat)
	var field: Dictionary = run_field(defs, level_id, evt_seed, pars, int(ctx.get("total_yards", 0)), cond)
	var success: bool = failed.is_empty()
	var rw: Dictionary = ld["reward"]
	var fl: Dictionary = ld["failure"]
	var rv: Dictionary = ld["revenue"]
	var spectators: int = defs.spectator_capacity(int(tiers.get("clubhouse", 0)))
	var entry_income: int = 0
	var ticket_income: int = 0
	if success:
		entry_income = int(rv["entry_fee"]) * int(ld["field_size"])
		ticket_income = (int(rv["ticket_price"]) * spectators * int(rv["attendance_pct"]) / 100) * int(ld["duration_days"])
	var cash_delta: int = -int(fl["cash_loss"])
	if success:
		cash_delta = int(rw["cash"]) + entry_income + ticket_income
	var rep_delta: int = int(rw["reputation"]) if success else -int(fl["reputation_loss"])
	var pts: int = MHTournamentRules.prestige_points_awarded(defs, level_id, prestige_pm) if success else 0
	var cd: int = int(ld["cooldown_days"])
	if not success:
		cd += int(fl["cooldown_extra_days"])
	return {
		"level": level_id,
		"success": success,
		"failed_triggers": failed,
		"condition_id": str(cond["id"]),
		"unfair_holes": unfair,
		"satisfaction_pm": sat,
		"event_prestige_pm": prestige_pm,
		"cash_delta": cash_delta,
		"entry_income": entry_income,
		"ticket_income": ticket_income,
		"reputation_delta": rep_delta,
		"prestige_points": pts,
		"cooldown_days": cd,
		"winner": int(field["winner"]),
		"winner_over_par": int(field["winner_over_par"]),
		"order": field["order"],
		"totals": field["totals"],
		"purse": MHTournamentRules.purse_table(defs, level_id),
		"pars": pars,
	}
