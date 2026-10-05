class_name MHFakeGameStateView
extends MHGameStateView
## Sample data for the UI gallery and the adapter contract tests. Numbers are PLACEHOLDERS shaped like a
## player about 12 days in: 7 holes, 3 buildings at tier 1, the 6-hole start plot, a few tokens.
## The `sample_*` methods change the sample for demos and tests; they are not part of the adapter contract.
## Daily challenge, tournaments, achievements, club level and the tournament event come from the REAL modules
## through MHProgressBridge (progression.json, achievements.json, tournaments.json, daily_challenges.json) fed with
## sample inputs, so the gallery shows the same rows the live game will. sample_handle_intent runs the two
## intents (tournament_host, daily_play) against that bridge.

const SAMPLE_INCOME_BASE: Dictionary = {
	"clubhouse": 900, "pro_shop": 500, "driving_range": 600, "restaurant": 700, "pool_spa": 650,
	"cart_barn": 300, "maintenance": 250, "lodging": 800, "homes": 1000, "landmark": 1200,
}
## Added daily income multiplier per tier (percent of the tier 1 base), placeholder.
const SAMPLE_TIER_PCT: Array = [100, 200, 320, 500, 800]
## Sample UTC day number and a time of day (10:00 UTC) for the daily challenge.
const SAMPLE_UTC_DAY: int = 20730
const SAMPLE_UNIX: int = SAMPLE_UTC_DAY * 86400 + 36000
const SAMPLE_PACE: int = 55
const SAMPLE_STAFF: int = 2
const SAMPLE_DAILY_SCORES: Array = [40, 41, 43, 44, 44, 45, 46, 46, 47, 46, 46, 47, 46, 46]

var _defs: MHBuildingDefs
var _land: MHLandModel
var _gate: MHGateView = MHGateView.new()
var _demo: bool = true
var _cash: int = 18450
var _day: int = 11
var _minute: int = 215
var _speed: int = 1
var _paused: bool = false
var _earned: int = 7
var _paid: int = 0
var _members: int = 22
var _scores: Array = [58, 47, 52, 39, 61, 44, 22]
var _recovery_active: bool = false
var _undo: bool = true
var _redo: bool = false
var _bridge: MHProgressBridge
var _tournament_ready: bool = false


func _init() -> void:
	_defs = MHBuildingDefs.load_default()
	if _defs.is_loaded():
		_land = MHLandModel.create(_defs)
	_gate.tiers = {"clubhouse": 1, "pro_shop": 1, "cart_barn": 1}
	_gate.demo = _demo
	_rebuild_gate()
	_bridge = MHProgressBridge.create()
	_seed_progress()
	_sync_bridge()


func _rebuild_gate() -> void:
	var dead_below: int = 25
	if _defs != null and _defs.is_loaded():
		dead_below = _defs.dead_hole_score_below()
	_gate.set_from_hole_scores(_scores, dead_below)
	_gate.members = _members
	_gate.demo = _demo
	if _land != null:
		_land.fill_view(_gate)


## Club numbers the tournament entry checklist reads (see MHTournamentRules).
func _club_view() -> Dictionary:
	if _tournament_ready:
		return {
			"holes": 18, "avg_hole_score": 60, "pace_score": 80, "staff": 20,
			"tiers": {"clubhouse": 4, "cart_barn": 4, "maintenance": 4, "restaurant": 4, "pro_shop": 2},
		}
	return {
		"holes": _gate.holes, "avg_hole_score": _gate.avg_hole_score, "pace_score": SAMPLE_PACE,
		"staff": SAMPLE_STAFF, "tiers": _gate.tiers.duplicate(),
	}


func _sync_bridge() -> void:
	_bridge.update_inputs(_day, SAMPLE_UNIX, _cash, _club_view(), SAMPLE_DAILY_SCORES, {}, club_name())


## A little history: a three day streak ending yesterday, yesterday's challenge done, one attempt today, and stats
## from the sample course.
@warning_ignore("integer_division")
func _seed_progress() -> void:
	if not _bridge.is_ready():
		return
	for d: int in range(SAMPLE_UTC_DAY - 3, SAMPLE_UTC_DAY):
		_bridge.progression.record_active_day(d)
	_bridge.daily.record_attempt(SAMPLE_UTC_DAY - 1, true, 700, 800)
	_bridge.daily.record_attempt(SAMPLE_UTC_DAY, false, 480, 640)
	_bridge.progression.record_active_day(SAMPLE_UTC_DAY)
	var best: int = 0
	for s: Variant in _scores:
		best = maxi(best, int(s))
	var snapshot: Dictionary = {
		"holes_max": _scores.size(), "best_hole_score": best, "best_course_score": course_score_x10() / 10,
		"members_max": _members, "reputation_max": 140, "lifetime_earned": 64200, "days_played": _day,
		"tutorial_done": true,
	}
	if _land != null:
		snapshot["parcels_max"] = _land.owned_count()
	_bridge.observe_club(snapshot, _gate.tiers)


## An attempt that exactly meets today's thresholds (sample only, so the gallery can show a completed challenge).
func _sample_entry(ch: Dictionary) -> Dictionary:
	var axes: Dictionary = {"accuracy": 50, "imagination": 50, "length": 50, "beauty": 50, "fairness": 50}
	var amin: Dictionary = ch.get("axis_min", {}) as Dictionary
	for k: Variant in amin.keys():
		axes[str(k)] = int(amin[k])
	var amax: Dictionary = ch.get("axis_max", {}) as Dictionary
	for k2: Variant in amax.keys():
		axes[str(k2)] = int(amax[k2])
	var length_yd: int = 350
	if ch.has("max_length_yd"):
		length_yd = int(ch["max_length_yd"])
	if ch.has("min_length_yd"):
		length_yd = int(ch["min_length_yd"])
	return {
		"valid": true, "par": int(ch.get("par", 4)), "length_yd": length_yd,
		"score": maxi(int(ch.get("min_score", 0)), int(ch.get("target_score", 0))), "axes": axes,
	}


# ------------------------------------------------------------------ sample controls (not the contract)

func sample_bridge() -> MHProgressBridge:
	return _bridge


## Makes the club meet every tournament entry rule (holes, score, pace, staff, buildings) so Host can be pressed.
func sample_set_tournament_ready(v: bool) -> void:
	_tournament_ready = v
	_sync_bridge()
	changed.emit()


## Runs one UI intent against the real modules. tournament_host takes the host cost from the sample cash;
## daily_play plays one sample attempt that meets the target. Returns the bridge result (handled false for any
## other intent). Emits changed when it handled something.
func sample_handle_intent(id: StringName, args: Dictionary) -> Dictionary:
	var r: Dictionary = _bridge.handle_intent(id, args)
	if not bool(r.get("handled", false)):
		return r
	if id == &"tournament_host" and bool(r["ok"]):
		_cash = maxi(0, _cash - int(r["cost"]))
	elif id == &"daily_play" and bool(r["ok"]):
		var done: Dictionary = _bridge.finish_daily_attempt(_sample_entry(r["challenge"] as Dictionary))
		r["message_key"] = done["message_key"]
		r["message_params"] = done["message_params"]
		r["completed"] = done["completed"]
	_sync_bridge()
	changed.emit()
	return r


func sample_set_cash(v: int) -> void:
	_cash = maxi(0, v)
	_sync_bridge()
	changed.emit()


func sample_set_tokens(earned: int, paid: int) -> void:
	_earned = maxi(0, earned)
	_paid = maxi(0, paid)
	changed.emit()


func sample_set_speed(v: int) -> void:
	_speed = v
	changed.emit()


func sample_set_demo(v: bool) -> void:
	_demo = v
	_rebuild_gate()
	changed.emit()


func sample_set_recovery(v: bool) -> void:
	_recovery_active = v
	changed.emit()


func sample_set_tier(building_id: String, tier: int) -> void:
	_gate.tiers[building_id] = clampi(tier, 0, 5)
	_sync_bridge()
	changed.emit()


func sample_set_scores(scores: Array, members: int) -> void:
	_scores = scores.duplicate()
	_members = members
	_rebuild_gate()
	_sync_bridge()
	changed.emit()


# ------------------------------------------------------------------ contract

func is_demo() -> bool:
	return _demo


func club_name() -> String:
	return "Larkspur Hollow"


func cash() -> int:
	return _cash


func day() -> int:
	return _day


func minute_of_day() -> int:
	return _minute


func speed() -> int:
	return _speed


func is_paused() -> bool:
	return _paused


func tokens_earned() -> int:
	return _earned


func tokens_paid() -> int:
	return _paid


@warning_ignore("integer_division")
func course_score_x10() -> int:
	if _scores.is_empty():
		return 0
	var total: int = 0
	for s: Variant in _scores:
		total += int(s)
	return (total * 10) / _scores.size()


func members() -> int:
	return _members


func income_per_day() -> int:
	return 1840


func upkeep_per_day() -> int:
	return 300


func hole_scores() -> Array:
	return _scores.duplicate()


func hole_rating(hole_no: int) -> Dictionary:
	if hole_no < 1 or hole_no > _scores.size():
		return {}
	var score: int = int(_scores[hole_no - 1])
	var pars: Array = [4, 3, 5, 4, 4, 3, 4]
	var lengths: Array = [372, 148, 521, 405, 388, 176, 340]
	var par: int = int(pars[(hole_no - 1) % pars.size()])
	var len_yd: int = int(lengths[(hole_no - 1) % lengths.size()])
	var pm: int = score * 10
	var reasons: Array = []
	var dead: bool = score < 25
	if dead:
		reasons.append({"code": 31, "severity": MHAdvisor.SEV_SEVERE, "a": 0, "b": 0})
		reasons.append({"code": 41, "severity": MHAdvisor.SEV_WARN, "a": 0, "b": 0})
	elif score < 40:
		reasons.append({"code": 32, "severity": MHAdvisor.SEV_WARN, "a": 0, "b": 0})
		reasons.append({"code": 41, "severity": MHAdvisor.SEV_WARN, "a": 0, "b": 0})
		reasons.append({"code": 48, "severity": MHAdvisor.SEV_INFO, "a": 0, "b": 0})
		reasons.append({"code": 47, "severity": MHAdvisor.SEV_INFO, "a": 0, "b": 0})
	elif score >= 60:
		reasons.append({"code": 33, "severity": MHAdvisor.SEV_PRAISE, "a": 0, "b": 0})
		reasons.append({"code": 42, "severity": MHAdvisor.SEV_INFO, "a": 0, "b": 0})
	else:
		reasons.append({"code": 42, "severity": MHAdvisor.SEV_INFO, "a": 0, "b": 0})
		reasons.append({"code": 51, "severity": MHAdvisor.SEV_WARN, "a": 0, "b": 0})
	return {
		"hole_no": hole_no, "par": par, "length_yd": len_yd, "valid": true, "dead": dead,
		"score_pm": pm,
		"accuracy_pm": clampi(pm + 60, 0, 1000),
		"imagination_pm": clampi(pm - 120, 0, 1000),
		"length_pm": clampi(pm + 140, 0, 1000),
		"beauty_pm": clampi(pm + 20, 0, 1000),
		"fairness_pm": clampi(pm + 300, 0, 1000),
		"reasons": reasons,
	}


func building_defs() -> MHBuildingDefs:
	return _defs


func gate_view() -> MHGateView:
	var copy: MHGateView = MHGateView.new()
	copy.holes = _gate.holes
	copy.avg_hole_score = _gate.avg_hole_score
	copy.parcels_owned = _gate.parcels_owned
	copy.parcels_by_kind = _gate.parcels_by_kind.duplicate()
	copy.members = _gate.members
	copy.hosted_level = _gate.hosted_level
	copy.tiers = _gate.tiers.duplicate()
	copy.demo = _gate.demo
	return copy


@warning_ignore("integer_division")
func added_daily_income(building_id: String, tier: int) -> int:
	if tier < 1 or tier > SAMPLE_TIER_PCT.size():
		return 0
	var base: int = int(SAMPLE_INCOME_BASE.get(building_id, 0))
	return base * int(SAMPLE_TIER_PCT[tier - 1]) / 100


func land() -> MHLandModel:
	return _land


func daily_challenge() -> Dictionary:
	return _bridge.daily_row()


func tournaments() -> Array:
	return _bridge.tournament_rows()


func tournament_event() -> Dictionary:
	return _bridge.tournament_event()


func achievements() -> Array:
	return _bridge.achievement_rows()


func club_level() -> int:
	return _bridge.club_level()


func club_points() -> int:
	return _bridge.club_points()


func points_for_next_level() -> int:
	return _bridge.points_for_next_level()


func level_title_key() -> String:
	return _bridge.level_title_key()


func recovery_offer() -> Dictionary:
	return {
		"active": _recovery_active, "shortfall": 1260, "loan_amount": 5000,
		"reputation_penalty": 15, "token_cost": 5,
	}


func store_products() -> Array:
	return [
		{"id": "tokens_small", "tokens": 20, "price_text": "$0.99"},
		{"id": "tokens_medium", "tokens": 60, "price_text": "$2.49"},
		{"id": "tokens_large", "tokens": 150, "price_text": "$4.99"},
	]


func can_undo() -> bool:
	return _undo


func can_redo() -> bool:
	return _redo
