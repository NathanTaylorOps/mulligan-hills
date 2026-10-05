class_name MHFakeGameStateView
extends MHGameStateView
## Sample data for the UI gallery and the adapter contract tests. Numbers are PLACEHOLDERS shaped like a
## player about 12 days in: 7 holes, 3 buildings at tier 1, the 6-hole start plot, a few tokens.
## The `sample_*` methods change the sample for demos and tests; they are not part of the adapter contract.

const SAMPLE_INCOME_BASE: Dictionary = {
	"clubhouse": 900, "pro_shop": 500, "driving_range": 600, "restaurant": 700, "pool_spa": 650,
	"cart_barn": 300, "maintenance": 250, "lodging": 800, "homes": 1000, "landmark": 1200,
}
## Added daily income multiplier per tier (percent of the tier 1 base), placeholder.
const SAMPLE_TIER_PCT: Array = [100, 200, 320, 500, 800]

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


func _init() -> void:
	_defs = MHBuildingDefs.load_default()
	if _defs.is_loaded():
		_land = MHLandModel.create(_defs)
	_gate.tiers = {"clubhouse": 1, "pro_shop": 1, "cart_barn": 1}
	_gate.demo = _demo
	_rebuild_gate()


func _rebuild_gate() -> void:
	var dead_below: int = 25
	if _defs != null and _defs.is_loaded():
		dead_below = _defs.dead_hole_score_below()
	_gate.set_from_hole_scores(_scores, dead_below)
	_gate.members = _members
	_gate.demo = _demo
	if _land != null:
		_land.fill_view(_gate)


# ------------------------------------------------------------------ sample controls (not the contract)

func sample_set_cash(v: int) -> void:
	_cash = maxi(0, v)
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
	changed.emit()


func sample_set_scores(scores: Array, members: int) -> void:
	_scores = scores.duplicate()
	_members = members
	_rebuild_gate()
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
	return {
		"enabled": true,
		"title_key": "challenge.strategic_par4.title",
		"desc_key": "challenge.strategic_par4.desc",
		"attempts_left": 2, "attempts_total": 3,
		"target_score": 55, "best_score": 48, "streak_days": 3, "ends_in_minutes": 380,
		"board": [
			{"name": "Marlow Pines", "score": 71},
			{"name": "Quillon Ridge", "score": 66},
			{"name": "Larkspur Hollow", "score": 48},
			{"name": "Tern Point", "score": 44},
		],
	}


func tournaments() -> Array:
	var out: Array = []
	var levels: Array = ["local", "regional", "national", "major"]
	var costs: Array = [10000, 40000, 150000, 600000]
	var rewards: Array = [15000, 60000, 220000, 900000]
	var holes_need: Array = [10, 14, 18, 18]
	var score_need: Array = [30, 42, 52, 62]
	for i: int in range(levels.size()):
		var rows: Array = []
		rows.append(["holes", _gate.holes >= int(holes_need[i]), _gate.holes, int(holes_need[i])])
		rows.append(["avg_hole_score", _gate.avg_hole_score >= int(score_need[i]), _gate.avg_hole_score, int(score_need[i])])
		if i == 0:
			rows.append(["building:clubhouse", _gate.tier_of("clubhouse") >= 3, _gate.tier_of("clubhouse"), 3])
			rows.append(["building:cart_barn", _gate.tier_of("cart_barn") >= 2, _gate.tier_of("cart_barn"), 2])
			rows.append(["building:maintenance", _gate.tier_of("maintenance") >= 2, _gate.tier_of("maintenance"), 2])
		out.append({
			"level": str(levels[i]), "status": "locked",
			"host_cost": int(costs[i]), "reward_cash": int(rewards[i]), "reward_reputation": 50 * (i + 1),
			"cooldown_days": 0, "rows": rows,
		})
	return out


func achievements() -> Array:
	var out: Array = []
	out.append({"id": "first_hole", "category": "design", "tier": "bronze", "points": 5, "hidden": false, "earned": true, "progress": 1, "target": 1})
	out.append({"id": "nine_holes", "category": "design", "tier": "bronze", "points": 10, "hidden": false, "earned": false, "progress": 7, "target": 9})
	out.append({"id": "good_hole", "category": "design", "tier": "bronze", "points": 5, "hidden": false, "earned": true, "progress": 61, "target": 50})
	out.append({"id": "great_hole", "category": "design", "tier": "bronze", "points": 10, "hidden": false, "earned": false, "progress": 61, "target": 70})
	out.append({"id": "first_building", "category": "buildings", "tier": "bronze", "points": 5, "hidden": false, "earned": true, "progress": 1, "target": 1})
	out.append({"id": "five_buildings", "category": "buildings", "tier": "bronze", "points": 10, "hidden": false, "earned": false, "progress": 3, "target": 5})
	out.append({"id": "more_land", "category": "growth", "tier": "bronze", "points": 5, "hidden": false, "earned": false, "progress": 5, "target": 6})
	out.append({"id": "fifty_members", "category": "growth", "tier": "silver", "points": 25, "hidden": false, "earned": false, "progress": 22, "target": 50})
	out.append({"id": "first_tournament", "category": "tournaments", "tier": "silver", "points": 25, "hidden": false, "earned": false, "progress": 0, "target": 1})
	out.append({"id": "first_challenge", "category": "daily", "tier": "bronze", "points": 5, "hidden": false, "earned": true, "progress": 1, "target": 1})
	out.append({"id": "streak_seven", "category": "daily", "tier": "bronze", "points": 10, "hidden": false, "earned": false, "progress": 3, "target": 7})
	out.append({"id": "card_player", "category": "misc", "tier": "bronze", "points": 5, "hidden": true, "earned": false, "progress": 0, "target": 1})
	return out


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
