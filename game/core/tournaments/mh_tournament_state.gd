class_name MHTournamentState
extends RefCounted
## Tournament calendar state of one save: highest levels hosted, cooldown, and the one event that may be running.
## Pure logic. The caller owns cash, reputation and the clock: this class never touches them, it returns the
## amounts (host cost, refund) and the caller applies them. Days are the game day counter (MHGameClock.day()).
##
## Life of an event (days are inclusive of start_day):
##   start()   day D     status "preparing", host cost taken by the caller, snapshot score stored, course locked
##   advance() day D+prep_days   status "running"
##   ready     day D+prep_days+duration_days   evaluate with MHTournamentSim.evaluate then call finish()
##   finish()  status "done" (success) or "failed"; cooldown starts that day; acknowledge() clears the record.
## cancel() is allowed only while preparing and refunds cancel_refund_pct of the host cost.
## Save shape (save.schema.json progress.tournaments) is to_save_block()/from_save_block(): hosted_levels,
## cooldown_until_day, optional active, and the two counters the achievements read (hosted_count, attempted_count;
## optional in the schema, so a save written before they existed still loads). to_dict() adds only "v".

const SAVE_VERSION: int = 1
const STATUSES: Array = ["preparing", "running", "done", "failed"]

var hosted_levels: Array = []
var cooldown_until_day: int = 0
## {} or {"level", "start_day", "snapshot_score", "status"}
var active: Dictionary = {}
var hosted_count: int = 0
var attempted_count: int = 0
## Result of the last finish() in this session (not saved).
var last_result: Dictionary = {}


func is_active() -> bool:
	return not active.is_empty()


## The course is locked (no geometry edits to the snapshot holes) while an event is being prepared or run.
func course_locked() -> bool:
	if active.is_empty():
		return false
	var st: String = str(active["status"])
	return st == "preparing" or st == "running"


func in_cooldown(day: int) -> bool:
	return day < cooldown_until_day


func cooldown_days_left(day: int) -> int:
	return maxi(0, cooldown_until_day - day)


## Highest level hosted so far ("" when none). Feeds MHGateView.hosted_level (the tier 5 building gate).
func highest_hosted_level() -> String:
	var best: int = 0
	for l: Variant in hosted_levels:
		best = maxi(best, MHTournamentDefs.level_rank(str(l)))
	return MHTournamentDefs.level_from_rank(best)


## True when a hosted event of at least min_level exists (the tier 5 gate test).
func has_hosted_at_least(min_level: String) -> bool:
	var need: int = MHTournamentDefs.level_rank(min_level)
	if need < 1:
		return false
	return MHTournamentDefs.level_rank(highest_hosted_level()) >= need


func has_hosted(level_id: String) -> bool:
	return hosted_levels.has(level_id)


## "locked" (entry not met, or another event is busy), "cooldown", "active" (this level is the running event),
## or "available". Matches the status strings of MHGameStateView.tournaments().
func status_for(defs: MHTournamentDefs, level_id: String, day: int, view: Dictionary) -> String:
	if is_active():
		if str(active["level"]) == level_id:
			return "active"
		return "locked"
	if not MHTournamentRules.entry_report(defs, level_id, view).met:
		return "locked"
	if in_cooldown(day):
		return "cooldown"
	return "available"


## {"ok": bool, "reason": String}. Reasons in check order: unknown_level, disabled (remote kill switch is off, see
## MHKillSwitch.is_on), busy, cooldown, locked, cash. The kill switch stops NEW events only: a running
## event still resolves and levels already hosted still count for the tier 5 gate.
func can_start(defs: MHTournamentDefs, level_id: String, day: int, view: Dictionary, cash: int, feature_on: bool) -> Dictionary:
	if not defs.has_level(level_id):
		return {"ok": false, "reason": "unknown_level"}
	if not feature_on:
		return {"ok": false, "reason": "disabled"}
	if is_active():
		return {"ok": false, "reason": "busy"}
	if in_cooldown(day):
		return {"ok": false, "reason": "cooldown"}
	if not MHTournamentRules.entry_report(defs, level_id, view).met:
		return {"ok": false, "reason": "locked"}
	if cash < defs.level_int(level_id, "host_cost"):
		return {"ok": false, "reason": "cash"}
	return {"ok": true, "reason": ""}


## Starts an event if can_start allows. Returns {"ok", "reason", "cost" (dollars the caller must take),
## "event_id"}. snapshot_score comes from MHTournamentRules.snapshot_score.
func start(defs: MHTournamentDefs, level_id: String, day: int, view: Dictionary, cash: int, feature_on: bool, snapshot_score: int) -> Dictionary:
	var chk: Dictionary = can_start(defs, level_id, day, view, cash, feature_on)
	if not bool(chk["ok"]):
		return {"ok": false, "reason": str(chk["reason"]), "cost": 0, "event_id": -1}
	active = {
		"level": level_id,
		"start_day": day,
		"snapshot_score": clampi(snapshot_score, 0, 100),
		"status": "preparing",
	}
	return {"ok": true, "reason": "", "cost": defs.level_int(level_id, "host_cost"), "event_id": event_id()}


## Id for the event seed (MHTournamentSim.event_id), -1 when nothing is active.
func event_id() -> int:
	if active.is_empty():
		return -1
	return MHTournamentSim.event_id(str(active["level"]), int(active["start_day"]))


## First day on which the running event can be resolved. -1 when nothing is active.
func resolve_day(defs: MHTournamentDefs) -> int:
	if active.is_empty():
		return -1
	var lid: String = str(active["level"])
	return int(active["start_day"]) + defs.level_int(lid, "prep_days") + defs.level_int(lid, "duration_days")


## Moves preparing to running when the prep days are over. Returns true when the event is ready to resolve
## (resolve_day reached and not yet finished).
func advance(defs: MHTournamentDefs, day: int) -> bool:
	if active.is_empty():
		return false
	var st: String = str(active["status"])
	if st != "preparing" and st != "running":
		return false
	var lid: String = str(active["level"])
	if st == "preparing" and day >= int(active["start_day"]) + defs.level_int(lid, "prep_days"):
		active["status"] = "running"
	return day >= resolve_day(defs)


## Cancels an event that is still being prepared (before its first event day). Returns {"ok", "refund"} with the
## refund in dollars for the caller to pay back. No cooldown is applied (open question, see docs).
func cancel(defs: MHTournamentDefs, day: int) -> Dictionary:
	if active.is_empty() or str(active["status"]) != "preparing":
		return {"ok": false, "refund": 0}
	var lid: String = str(active["level"])
	if day >= int(active["start_day"]) + defs.level_int(lid, "prep_days"):
		return {"ok": false, "refund": 0}
	var refund: int = MHTournamentRules.cancel_refund(defs, lid)
	active = {}
	return {"ok": true, "refund": refund}


## Records the outcome of MHTournamentSim.evaluate. Only valid once ready (day >= resolve_day). The caller applies
## result["cash_delta"], ["reputation_delta"] and ["prestige_points"]. Returns false when not ready.
func finish(defs: MHTournamentDefs, day: int, result: Dictionary) -> bool:
	if active.is_empty():
		return false
	var st: String = str(active["status"])
	if st != "preparing" and st != "running":
		return false
	if day < resolve_day(defs):
		return false
	if str(result.get("level", "")) != str(active["level"]):
		return false
	var ok: bool = bool(result.get("success", false))
	active["status"] = "done" if ok else "failed"
	attempted_count += 1
	if ok:
		hosted_count += 1
		var lid: String = str(active["level"])
		if not hosted_levels.has(lid):
			hosted_levels.append(lid)
			_sort_levels()
	cooldown_until_day = day + int(result.get("cooldown_days", 0))
	last_result = result.duplicate(true)
	return true


## Clears a finished (done or failed) record so the next event can start.
func acknowledge() -> void:
	if active.is_empty():
		return
	var st: String = str(active["status"])
	if st == "done" or st == "failed":
		active = {}


func _sort_levels() -> void:
	var sorted_levels: Array = []
	for r: int in range(1, MHTournamentDefs.LEVELS.size() + 1):
		var lid: String = MHTournamentDefs.level_from_rank(r)
		if hosted_levels.has(lid):
			sorted_levels.append(lid)
	hosted_levels = sorted_levels


# ------------------------------------------------------------------ persistence

## Exactly the shape of save.schema.json progress.tournaments.
func to_save_block() -> Dictionary:
	var out: Dictionary = {
		"hosted_levels": hosted_levels.duplicate(),
		"cooldown_until_day": cooldown_until_day,
		"hosted_count": hosted_count,
		"attempted_count": attempted_count,
	}
	if not active.is_empty():
		out["active"] = active.duplicate()
	return out


## Replaces hosted_levels, cooldown, active and the counters from a save block. When the block has no counters (a
## save written before they existed) the current counters are kept. Either way the counters are raised to what the
## block implies (hosted_count >= number of levels, attempted_count >= hosted_count).
## Returns false and changes nothing when the block is invalid.
func from_save_block(block: Dictionary) -> bool:
	var errs: Array = []
	var norm: Variant = MHDataJson.normalize(block, errs, "$")
	if not errs.is_empty() or typeof(norm) != TYPE_DICTIONARY:
		return false
	var b: Dictionary = norm
	var lv: Variant = b.get("hosted_levels", null)
	if typeof(lv) != TYPE_ARRAY or (lv as Array).size() > 4:
		return false
	var levels: Array = []
	for l: Variant in (lv as Array):
		if MHTournamentDefs.level_rank(str(l)) < 1 or levels.has(str(l)):
			return false
		levels.append(str(l))
	if not MHDataJson.is_int_in(b.get("cooldown_until_day", null), 0, 1000000):
		return false
	var new_hosted: int = hosted_count
	var new_attempted: int = attempted_count
	if b.has("hosted_count"):
		if not MHDataJson.is_int_in(b["hosted_count"], 0, 1000000):
			return false
		new_hosted = int(b["hosted_count"])
	if b.has("attempted_count"):
		if not MHDataJson.is_int_in(b["attempted_count"], 0, 1000000):
			return false
		new_attempted = int(b["attempted_count"])
	var act: Dictionary = {}
	if b.has("active"):
		var av: Variant = b["active"]
		if typeof(av) != TYPE_DICTIONARY:
			return false
		var a: Dictionary = av
		if MHTournamentDefs.level_rank(str(a.get("level", ""))) < 1:
			return false
		if not MHDataJson.is_int_in(a.get("start_day", null), 0, 1000000):
			return false
		if not MHDataJson.is_int_in(a.get("snapshot_score", null), 0, 100):
			return false
		if not STATUSES.has(str(a.get("status", ""))):
			return false
		act = {
			"level": str(a["level"]),
			"start_day": int(a["start_day"]),
			"snapshot_score": int(a["snapshot_score"]),
			"status": str(a["status"]),
		}
	hosted_levels = levels
	_sort_levels()
	cooldown_until_day = int(b["cooldown_until_day"])
	active = act
	hosted_count = maxi(new_hosted, hosted_levels.size())
	attempted_count = maxi(new_attempted, hosted_count)
	return true


## Full state: the save block plus a version tag.
func to_dict() -> Dictionary:
	var d: Dictionary = to_save_block()
	d["v"] = SAVE_VERSION
	return d


func from_dict(d: Dictionary) -> bool:
	var errs: Array = []
	var norm: Variant = MHDataJson.normalize(d, errs, "$")
	if not errs.is_empty() or typeof(norm) != TYPE_DICTIONARY:
		return false
	var nd: Dictionary = norm
	if int(nd.get("v", 0)) != SAVE_VERSION:
		return false
	if not MHDataJson.is_int_in(nd.get("hosted_count", null), 0, 1000000) or not MHDataJson.is_int_in(nd.get("attempted_count", null), 0, 1000000):
		return false
	var saved_hosted: int = hosted_count
	var saved_attempted: int = attempted_count
	hosted_count = 0
	attempted_count = 0
	if not from_save_block(nd):
		hosted_count = saved_hosted
		attempted_count = saved_attempted
		return false
	hosted_count = maxi(int(nd["hosted_count"]), hosted_levels.size())
	attempted_count = maxi(int(nd["attempted_count"]), hosted_count)
	return true
