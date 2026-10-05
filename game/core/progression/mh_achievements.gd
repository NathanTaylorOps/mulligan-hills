class_name MHAchievements
extends RefCounted
## Achievement catalogue (res://data/achievements.json, at least 40 entries). Unlock conditions are DATA: an
## achievement unlocks when ALL its conditions hold against the MHProgressStats values. Because the stats are
## high-water marks nothing is ever lost. Pure logic, no state: the unlocked ids live in MHProgression (and in
## save.schema.json progress.achievements). Points feed club prestige.

const DEFAULT_PATH: String = "res://data/achievements.json"
const CATEGORIES: Array = ["design", "buildings", "growth", "tournaments", "commissions", "daily", "misc"]
const TIERS: Array = ["bronze", "silver", "gold", "platinum"]
const OPS: Array = ["gte", "lte", "eq"]
const MIN_COUNT: int = 40

var load_error: String = ""

var _list: Array = []
var _ids: PackedStringArray = PackedStringArray()
var _loaded: bool = false


func is_loaded() -> bool:
	return _loaded


func load_from_file(path: String = DEFAULT_PATH) -> bool:
	var r: Dictionary = MHDataJson.load_file(path)
	if not bool(r["ok"]):
		return _fail(str(r["error"]))
	return load_from_dict(r["value"] as Dictionary)


func load_from_text(text: String) -> bool:
	var r: Dictionary = MHDataJson.parse_text(text)
	if not bool(r["ok"]):
		return _fail(str(r["error"]))
	return load_from_dict(r["value"] as Dictionary)


func load_from_dict(d: Dictionary) -> bool:
	_loaded = false
	load_error = ""
	_list = []
	_ids = PackedStringArray()
	if str(d.get("schema", "")) != "mh.achievements" or int(d.get("schema_version", 0)) != 1:
		return _fail("wrong schema or schema_version")
	var av: Variant = d.get("achievements", null)
	if typeof(av) != TYPE_ARRAY or (av as Array).size() < MIN_COUNT or (av as Array).size() > 200:
		return _fail("achievements must have 40 to 200 entries")
	var seen: PackedStringArray = PackedStringArray()
	for a: Variant in (av as Array):
		var msg: String = _check_one(a, seen)
		if not msg.is_empty():
			return _fail(msg)
	_list = (av as Array).duplicate(true)
	_ids = seen
	_loaded = true
	return true


func _fail(msg: String) -> bool:
	load_error = msg
	_loaded = false
	return false


func _check_one(a: Variant, seen: PackedStringArray) -> String:
	if typeof(a) != TYPE_DICTIONARY:
		return "achievement is not an object"
	var ad: Dictionary = a
	var aid: String = str(ad.get("id", ""))
	if aid.is_empty() or seen.has(aid):
		return "missing or duplicate achievement id: " + aid
	seen.append(aid)
	if not CATEGORIES.has(str(ad.get("category", ""))):
		return aid + ": bad category"
	if not TIERS.has(str(ad.get("tier", ""))):
		return aid + ": bad tier"
	if not MHDataJson.is_int_in(ad.get("points", null), 0, 1000):
		return aid + ": bad points"
	if typeof(ad.get("hidden", null)) != TYPE_BOOL:
		return aid + ": hidden must be a boolean"
	if str(ad.get("name_key", "")).is_empty() or str(ad.get("desc_key", "")).is_empty():
		return aid + ": text keys missing"
	var conds: Variant = ad.get("all", null)
	if typeof(conds) != TYPE_ARRAY or (conds as Array).is_empty() or (conds as Array).size() > 6:
		return aid + ": all must have 1 to 6 conditions"
	for c: Variant in (conds as Array):
		if typeof(c) != TYPE_DICTIONARY:
			return aid + ": condition is not an object"
		var cd: Dictionary = c
		if not MHProgressStats.STAT_KEYS.has(str(cd.get("stat", ""))):
			return aid + ": unknown stat " + str(cd.get("stat", ""))
		if not OPS.has(str(cd.get("op", ""))):
			return aid + ": unknown op"
		if not MHDataJson.is_int_in(cd.get("value", null), 0, 1000000000):
			return aid + ": bad value"
	return ""


func count() -> int:
	return _list.size()


func all_ids() -> PackedStringArray:
	return _ids.duplicate()


func has_id(achievement_id: String) -> bool:
	return _ids.has(achievement_id)


func get_def(achievement_id: String) -> Dictionary:
	var i: int = _ids.find(achievement_id)
	if i < 0:
		return {}
	return (_list[i] as Dictionary).duplicate(true)


func points_of(achievement_id: String) -> int:
	var i: int = _ids.find(achievement_id)
	if i < 0:
		return 0
	return int((_list[i] as Dictionary)["points"])


## Sum of points over the given unlocked ids (unknown ids count 0).
func total_points(unlocked: Array) -> int:
	var sum: int = 0
	for u: Variant in unlocked:
		sum += points_of(str(u))
	return sum


static func condition_met(cond: Dictionary, stats: MHProgressStats) -> bool:
	var have: int = stats.value_of(str(cond["stat"]))
	var need: int = int(cond["value"])
	var op: String = str(cond["op"])
	if op == "gte":
		return have >= need
	if op == "lte":
		return have <= need
	return have == need


func is_met(achievement_id: String, stats: MHProgressStats) -> bool:
	var i: int = _ids.find(achievement_id)
	if i < 0:
		return false
	for c: Variant in ((_list[i] as Dictionary)["all"] as Array):
		if not condition_met(c as Dictionary, stats):
			return false
	return true


## Ids whose conditions hold and that are not in `unlocked`, in file order.
func newly_unlocked(stats: MHProgressStats, unlocked: Array) -> Array:
	var out: Array = []
	for i: int in range(_list.size()):
		var aid: String = _ids[i]
		if unlocked.has(aid):
			continue
		if is_met(aid, stats):
			out.append(aid)
	return out


## UI rows in file order: {id, category, tier, points, hidden, earned, progress, target}. progress and target add
## up the conditions (progress counts each gte condition as min(have, need)); a met achievement shows progress =
## target. Hidden achievements still return their numbers: the screen decides what to show.
func progress_rows(stats: MHProgressStats, unlocked: Array) -> Array:
	var rows: Array = []
	for i: int in range(_list.size()):
		var ad: Dictionary = _list[i]
		var aid: String = _ids[i]
		var earned: bool = unlocked.has(aid)
		var prog: int = 0
		var target: int = 0
		for c: Variant in (ad["all"] as Array):
			var cd: Dictionary = c
			var need: int = int(cd["value"])
			target += need
			if str(cd["op"]) == "gte":
				prog += mini(stats.value_of(str(cd["stat"])), need)
			elif condition_met(cd, stats):
				prog += need
		if earned:
			prog = target
		rows.append({
			"id": aid,
			"category": str(ad["category"]),
			"tier": str(ad["tier"]),
			"points": int(ad["points"]),
			"hidden": bool(ad["hidden"]),
			"earned": earned,
			"progress": prog,
			"target": target,
		})
	return rows
