class_name MHTournamentDefs
extends RefCounted
## Tournament ladder data (res://data/tournaments.json, schema docs/spec/data/tournaments.schema.json).
## Loads, validates structure and exposes read-only accessors. Integer only. Money in this file is WHOLE DOLLARS
## (the economy keeps cents: multiply by 100 when applying). All numbers are PLACEHOLDERS (DEC-023 style).
## Building requirements are capped at tier 4 here as well as in the schema, so a tier-5 building can never be a
## prerequisite of the tournament that unlocks tier 5 (DEC-027).

const DEFAULT_PATH: String = "res://data/tournaments.json"
const LEVELS: Array = ["local", "regional", "national", "major"]
const TRIGGERS: Array = ["slow_pace", "unfair_hole", "bad_conditions", "low_snapshot_score"]
const BUILDING_IDS: Array = [
	"clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn", "maintenance", "lodging", "homes",
	"landmark",
]

var load_error: String = ""

var _data: Dictionary = {}
var _levels: Dictionary = {}
var _loaded: bool = false


## 1 = local .. 4 = major, 0 for "" or an unknown id.
static func level_rank(level_id: String) -> int:
	var i: int = LEVELS.find(level_id)
	return i + 1


static func level_from_rank(rank_no: int) -> String:
	if rank_no < 1 or rank_no > LEVELS.size():
		return ""
	return str(LEVELS[rank_no - 1])


func is_loaded() -> bool:
	return _loaded


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	var r: Dictionary = MHDataJson.load_file(path)
	if not bool(r["ok"]):
		_fail(str(r["error"]))
		return false
	return load_from_dict(r["value"] as Dictionary)


func load_from_text(text: String) -> bool:
	var r: Dictionary = MHDataJson.parse_text(text)
	if not bool(r["ok"]):
		_fail(str(r["error"]))
		return false
	return load_from_dict(r["value"] as Dictionary)


## d must already be normalized (all numbers ints). Structural validation only; the full schema check runs in CI.
func load_from_dict(d: Dictionary) -> bool:
	_loaded = false
	load_error = ""
	_data = {}
	_levels = {}
	if str(d.get("schema", "")) != "mh.tournaments" or int(d.get("schema_version", 0)) != 1:
		return _fail("wrong schema or schema_version")
	if not MHDataJson.is_int_array(d.get("spectator_capacity_by_clubhouse_tier", null), 5, 0, 100000):
		return _fail("bad spectator_capacity_by_clubhouse_tier")
	var msg: String = _check_prestige(d.get("prestige", null))
	if msg.is_empty():
		msg = _check_levels(d.get("levels", null))
	if msg.is_empty():
		msg = _check_conditions(d.get("conditions", null))
	if msg.is_empty():
		msg = _check_tail(d)
	if not msg.is_empty():
		return _fail(msg)
	_data = d
	for lv: Variant in (d["levels"] as Array):
		var ld: Dictionary = lv
		_levels[str(ld["level"])] = ld
	_loaded = true
	return true


func _fail(msg: String) -> bool:
	load_error = msg
	_loaded = false
	return false


func _check_prestige(v: Variant) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "prestige missing"
	var p: Dictionary = v
	if not MHDataJson.is_int_in(p.get("snapshot_window_days", null), 1, 60):
		return "bad snapshot_window_days"
	if not MHDataJson.is_int_in(p.get("sustained_min_days", null), 1, 60):
		return "bad sustained_min_days"
	if int(p["sustained_min_days"]) > int(p["snapshot_window_days"]):
		return "sustained_min_days above snapshot_window_days"
	if int(p.get("facility_tier_cap", 0)) != 4:
		return "facility_tier_cap must be 4"
	if typeof(p.get("weights_permille", null)) != TYPE_DICTIONARY:
		return "weights_permille missing"
	var w: Dictionary = p["weights_permille"]
	var total: int = 0
	for k: String in ["course_score", "pace", "facilities", "field_satisfaction"]:
		if not MHDataJson.is_int_in(w.get(k, null), 0, 1000):
			return "bad weight " + k
		total += int(w[k])
	if total != 1000:
		return "prestige weights must sum to 1000"
	var fb: Variant = p.get("facility_buildings", null)
	if typeof(fb) != TYPE_ARRAY or (fb as Array).is_empty():
		return "facility_buildings missing"
	for b: Variant in (fb as Array):
		if not BUILDING_IDS.has(str(b)):
			return "unknown facility building " + str(b)
	return ""


func _check_levels(v: Variant) -> String:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != LEVELS.size():
		return "levels must have 4 entries"
	var arr: Array = v
	for i: int in range(arr.size()):
		if typeof(arr[i]) != TYPE_DICTIONARY:
			return "level is not an object"
		var ld: Dictionary = arr[i]
		if str(ld.get("level", "")) != str(LEVELS[i]):
			return "levels must be in order local, regional, national, major"
		var lid: String = str(LEVELS[i])
		for k: String in ["field_size", "duration_days", "prep_days", "cooldown_days", "host_cost", "prestige_base"]:
			if not MHDataJson.is_int_in(ld.get(k, null), 0, 100000000):
				return lid + ": bad " + k
		if int(ld["field_size"]) < 4 or int(ld["field_size"]) > 64:
			return lid + ": field_size out of range"
		if int(ld["duration_days"]) < 1 or int(ld["cooldown_days"]) < 1:
			return lid + ": duration and cooldown must be at least 1 day"
		var msg: String = _check_entry(lid, ld.get("entry", null))
		if not msg.is_empty():
			return msg
		for blk: String in ["reward", "revenue", "failure", "field"]:
			if typeof(ld.get(blk, null)) != TYPE_DICTIONARY:
				return lid + ": missing " + blk
		var rw: Dictionary = ld["reward"]
		if not MHDataJson.is_int_in(rw.get("cash", null), 0, 100000000) or not MHDataJson.is_int_in(rw.get("reputation", null), 0, 100000):
			return lid + ": bad reward"
		var rv: Dictionary = ld["revenue"]
		if not MHDataJson.is_int_in(rv.get("entry_fee", null), 0, 1000000) or not MHDataJson.is_int_in(rv.get("ticket_price", null), 0, 100000):
			return lid + ": bad revenue"
		if not MHDataJson.is_int_in(rv.get("attendance_pct", null), 0, 100):
			return lid + ": bad revenue.attendance_pct"
		var fl: Dictionary = ld["failure"]
		for k2: String in ["reputation_loss", "cash_loss", "cooldown_extra_days"]:
			if not MHDataJson.is_int_in(fl.get(k2, null), 0, 100000000):
				return lid + ": bad failure." + k2
		if typeof(fl.get("triggers", null)) != TYPE_ARRAY or (fl["triggers"] as Array).is_empty():
			return lid + ": failure.triggers missing"
		for t: Variant in (fl["triggers"] as Array):
			if not TRIGGERS.has(str(t)):
				return lid + ": unknown trigger " + str(t)
		var fd: Dictionary = ld["field"]
		if not MHDataJson.is_int_in(fd.get("skill_min", null), 0, 1000) or not MHDataJson.is_int_in(fd.get("skill_max", null), 0, 1000):
			return lid + ": bad field skills"
		if int(fd["skill_min"]) > int(fd["skill_max"]):
			return lid + ": skill_min above skill_max"
	return ""


func _check_entry(lid: String, v: Variant) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return lid + ": entry missing"
	var e: Dictionary = v
	for k: String in ["min_holes", "min_avg_hole_score", "min_pace_score", "min_staff", "min_spectator_capacity"]:
		if not MHDataJson.is_int_in(e.get(k, null), 0, 100000):
			return lid + ": bad entry." + k
	if int(e["min_holes"]) < 1 or int(e["min_holes"]) > 18:
		return lid + ": entry.min_holes out of range"
	if typeof(e.get("buildings", null)) != TYPE_ARRAY:
		return lid + ": entry.buildings missing"
	for b: Variant in (e["buildings"] as Array):
		if typeof(b) != TYPE_DICTIONARY:
			return lid + ": building requirement is not an object"
		var bd: Dictionary = b
		if not BUILDING_IDS.has(str(bd.get("building", ""))):
			return lid + ": unknown building " + str(bd.get("building", ""))
		if not MHDataJson.is_int_in(bd.get("min_tier", null), 1, 4):
			return lid + ": building min_tier must be 1 to 4 (tier 5 can never be a tournament prerequisite)"
	return ""


func _check_conditions(v: Variant) -> String:
	if typeof(v) != TYPE_ARRAY or (v as Array).is_empty() or (v as Array).size() > 8:
		return "conditions missing"
	var seen: Array = []
	for c: Variant in (v as Array):
		if typeof(c) != TYPE_DICTIONARY:
			return "condition is not an object"
		var cd: Dictionary = c
		var cid: String = str(cd.get("id", ""))
		if cid.is_empty() or seen.has(cid):
			return "missing or duplicate condition id"
		seen.append(cid)
		if not MHDataJson.is_int_in(cd.get("weight", null), 1, 1000):
			return cid + ": bad weight"
		if not MHDataJson.is_int_in(cd.get("min_maintenance_tier", null), 1, 4):
			return cid + ": bad min_maintenance_tier"
		if not MHDataJson.is_int_in(cd.get("strokes_x10", null), 0, 200):
			return cid + ": bad strokes_x10"
		if not MHDataJson.is_int_in(cd.get("satisfaction_penalty_pm", null), 0, 1000):
			return cid + ": bad satisfaction_penalty_pm"
	return ""


func _check_tail(d: Dictionary) -> String:
	if typeof(d.get("evaluation", null)) != TYPE_DICTIONARY:
		return "evaluation missing"
	var ev: Dictionary = d["evaluation"]
	for k: String in ["pace_fail_margin", "score_fail_margin", "unfair_fairness_below", "unfair_holes_to_fail", "unfair_satisfaction_penalty_pm"]:
		if not MHDataJson.is_int_in(ev.get(k, null), 0, 1000):
			return "bad evaluation." + k
	if int(ev["unfair_holes_to_fail"]) < 1:
		return "unfair_holes_to_fail must be at least 1"
	if typeof(d.get("scoring", null)) != TYPE_DICTIONARY:
		return "scoring missing"
	var sc: Dictionary = d["scoring"]
	for k2: String in ["mid_skill_pm", "slope_x100", "difficulty_divisor", "hole_sd_x100"]:
		if not MHDataJson.is_int_in(sc.get(k2, null), 0, 1000000):
			return "bad scoring." + k2
	if int(sc["difficulty_divisor"]) < 1:
		return "difficulty_divisor must be positive"
	if not MHDataJson.is_int_in(sc.get("min_over_hole", null), -3, 0) or not MHDataJson.is_int_in(sc.get("max_over_hole", null), 1, 10):
		return "bad min_over_hole or max_over_hole"
	if typeof(d.get("purse", null)) != TYPE_DICTIONARY:
		return "purse missing"
	var pu: Dictionary = d["purse"]
	if not MHDataJson.is_int_in(pu.get("pct_of_host_cost", null), 0, 100):
		return "bad purse.pct_of_host_cost"
	var pl: Variant = pu.get("places_permille", null)
	if not MHDataJson.is_int_array(pl, -1, 0, 1000) or (pl as Array).is_empty() or (pl as Array).size() > 20:
		return "bad purse.places_permille"
	var tot: int = 0
	for x: Variant in (pl as Array):
		tot += int(x)
	if tot != 1000:
		return "purse.places_permille must sum to 1000"
	if not MHDataJson.is_int_in(d.get("cancel_refund_pct", null), 0, 100):
		return "bad cancel_refund_pct"
	var dp: Variant = d.get("default_pars", null)
	if not MHDataJson.is_int_array(dp, -1, 3, 5) or (dp as Array).is_empty() or (dp as Array).size() > 18:
		return "bad default_pars"
	return ""


# ------------------------------------------------------------------ accessors (copies where a caller could mutate)

func level_ids() -> Array:
	return LEVELS.duplicate()


func has_level(level_id: String) -> bool:
	return _levels.has(level_id)


## Copy of one level row ({} for an unknown level).
func level_data(level_id: String) -> Dictionary:
	if not _levels.has(level_id):
		return {}
	return (_levels[level_id] as Dictionary).duplicate(true)


func entry(level_id: String) -> Dictionary:
	if not _levels.has(level_id):
		return {}
	return ((_levels[level_id] as Dictionary)["entry"] as Dictionary).duplicate(true)


func level_int(level_id: String, key: String) -> int:
	if not _levels.has(level_id):
		return 0
	return int((_levels[level_id] as Dictionary).get(key, 0))


func prestige_params() -> Dictionary:
	return (_data["prestige"] as Dictionary).duplicate(true)


func scoring() -> Dictionary:
	return (_data["scoring"] as Dictionary).duplicate(true)


func evaluation() -> Dictionary:
	return (_data["evaluation"] as Dictionary).duplicate(true)


func purse() -> Dictionary:
	return (_data["purse"] as Dictionary).duplicate(true)


func conditions() -> Array:
	return (_data["conditions"] as Array).duplicate(true)


func condition_by_id(condition_id: String) -> Dictionary:
	for c: Variant in (_data["conditions"] as Array):
		var cd: Dictionary = c
		if str(cd["id"]) == condition_id:
			return cd.duplicate(true)
	return {}


func cancel_refund_pct() -> int:
	return int(_data["cancel_refund_pct"])


func default_pars() -> Array:
	return (_data["default_pars"] as Array).duplicate()


## Spectator capacity of a Clubhouse tier (grandstands are a Clubhouse feature, DEC-027). Tier 0 or less gives 0,
## tiers above 5 count as 5.
func spectator_capacity(clubhouse_tier: int) -> int:
	if clubhouse_tier < 1:
		return 0
	var caps: Array = _data["spectator_capacity_by_clubhouse_tier"]
	return int(caps[mini(clubhouse_tier, caps.size()) - 1])
