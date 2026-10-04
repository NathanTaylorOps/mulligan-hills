class_name MHBuildingDefs
extends RefCounted
## Read-only catalogue of the 10 buildings x 5 tiers, loaded from buildings.json (schema_version 2).
## Runtime copy: res://data/buildings.json (docs/ and tests/ are not exported to Android).
## Integer only. JSON numbers arrive as floats from Godot; the loader converts integral floats to int
## and rejects anything else. NOT YET RUN.

const DEFAULT_PATH: String = "res://data/buildings.json"
const SCHEMA_VERSION: int = 2
const TIER_COUNT: int = 5
const BUILDING_COUNT: int = 10
const LEVELS: Array = ["local", "regional", "national", "major"]

var _data: Dictionary = {}
var _ids: Array = []
var _by_id: Dictionary = {}
var _error: String = "not loaded"


## Load the shipped catalogue. Check is_loaded() / error() on the result.
static func load_default() -> MHBuildingDefs:
	var defs: MHBuildingDefs = MHBuildingDefs.new()
	defs.load_path(DEFAULT_PATH)
	return defs


static func from_text(text: String) -> MHBuildingDefs:
	var defs: MHBuildingDefs = MHBuildingDefs.new()
	defs.load_text(text)
	return defs


func load_path(path: String) -> String:
	if not FileAccess.file_exists(path):
		_fail("file missing: " + path)
		return _error
	return load_text(FileAccess.get_file_as_string(path))


## Returns "" on success, otherwise a short error message (also kept in error()).
func load_text(text: String) -> String:
	_data = {}
	_ids = []
	_by_id = {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("not a JSON object")
		return _error
	var errs: Array = []
	var norm: Variant = _norm(parsed, "", errs)
	if not errs.is_empty():
		_fail(str(errs[0]))
		return _error
	var d: Dictionary = norm
	var verr: String = _validate(d)
	if verr != "":
		_fail(verr)
		return _error
	_data = d
	var blist: Array = d["buildings"]
	for b: Variant in blist:
		var bd: Dictionary = b
		var id: String = str(bd["id"])
		_ids.append(id)
		_by_id[id] = bd
	_error = ""
	return ""


func is_loaded() -> bool:
	return _error == ""


func error() -> String:
	return _error


func _fail(msg: String) -> void:
	_error = msg
	_data = {}
	_ids = []
	_by_id = {}


# Integral floats become int; non-integral or huge numbers are reported (never clamped).
static func _norm(v: Variant, path: String, errs: Array) -> Variant:
	var t: int = typeof(v)
	if t == TYPE_FLOAT:
		var f: float = v
		var i: int = int(f)
		if float(i) != f or i > 9007199254740992 or i < -9007199254740992:
			errs.append("non-integer number at " + path)
			return 0
		return i
	if t == TYPE_DICTIONARY:
		var src: Dictionary = v
		var out: Dictionary = {}
		for k: Variant in src.keys():
			out[k] = _norm(src[k], path + "/" + str(k), errs)
		return out
	if t == TYPE_ARRAY:
		var arr: Array = v
		var out_a: Array = []
		for idx: int in range(arr.size()):
			out_a.append(_norm(arr[idx], path + "[" + str(idx) + "]", errs))
		return out_a
	return v


static func _validate(d: Dictionary) -> String:
	if str(d.get("schema", "")) != "mh.buildings":
		return "schema is not mh.buildings"
	if int(d.get("schema_version", 0)) != SCHEMA_VERSION:
		return "unsupported schema_version"
	for key: String in ["hole_cap", "hole_rules", "demo", "land", "buildings"]:
		if not d.has(key):
			return "missing key " + key
	var land: Dictionary = d["land"]
	for key2: String in ["max_parcels", "start_parcels", "holes_per_two_golf_parcels", "home_slots_per_homes_parcel", "heavy_extra_parcels", "parcel_base_cost", "parcel_growth_pct", "grid", "parcels"]:
		if not land.has(key2):
			return "land missing " + key2
	var plist: Array = land["parcels"]
	if plist.size() != int(land["max_parcels"]):
		return "land parcels size != max_parcels"
	for pi: int in range(plist.size()):
		var p: Dictionary = plist[pi]
		if int(p.get("id", -1)) != pi:
			return "land parcel ids must be 0..n-1 in order"
		if not (str(p.get("kind", "")) in ["golf", "facility", "homes"]):
			return "bad parcel kind"
	var blist: Array = d["buildings"]
	if blist.size() != BUILDING_COUNT:
		return "need exactly 10 buildings"
	var seen: Dictionary = {}
	for b: Variant in blist:
		var bd: Dictionary = b
		var id: String = str(bd.get("id", ""))
		if id == "" or seen.has(id):
			return "missing or duplicate building id"
		seen[id] = true
		if not (str(bd.get("land_class", "")) in ["light", "heavy"]):
			return id + ": bad land_class"
		if not bd.has("demo_max_tier"):
			return id + ": missing demo_max_tier"
		var tiers: Array = bd.get("tiers", [])
		if tiers.size() != TIER_COUNT:
			return id + ": need exactly 5 tiers"
		for ti: int in range(TIER_COUNT):
			var t: Dictionary = tiers[ti]
			if int(t.get("tier", 0)) != ti + 1:
				return id + ": tier numbers must run 1..5"
			if int(t.get("target_payback_days", 0)) < 1:
				return id + ": target_payback_days must be >= 1"
			if not t.has("upkeep_per_day") or not t.has("requires"):
				return id + ": tier missing fields"
			var r: Dictionary = t["requires"]
			for rk: String in ["min_holes", "min_avg_hole_score", "min_parcels_owned", "min_members", "specific", "any_others", "hosted_tournament"]:
				if not r.has(rk):
					return id + ": requires missing " + rk
	# specific links must name known buildings, and the graph must not deadlock.
	for b2: Variant in blist:
		var bd2: Dictionary = b2
		for t2: Variant in bd2["tiers"]:
			var td: Dictionary = t2
			var rq: Dictionary = td["requires"]
			var spec: Array = rq["specific"]
			for s: Variant in spec:
				var sd: Dictionary = s
				if not seen.has(str(sd.get("building", ""))):
					return str(bd2["id"]) + ": prerequisite names unknown building"
				var mt: int = int(sd.get("min_tier", 0))
				if mt < 1 or mt > TIER_COUNT:
					return str(bd2["id"]) + ": prerequisite min_tier out of range"
			var lvl: Variant = rq["hosted_tournament"]
			if lvl != null:
				var ld: Dictionary = lvl
				if not (str(ld.get("min_level", "")) in LEVELS):
					return str(bd2["id"]) + ": bad hosted tournament level"
	return _deadlock_check(blist)


# Fixed point: buy the lowest next tier whose building prerequisites are met (course gates ignored).
static func _deadlock_check(blist: Array) -> String:
	var have: Dictionary = {}
	for b: Variant in blist:
		var bd: Dictionary = b
		have[str(bd["id"])] = 0
	var progress: bool = true
	while progress:
		progress = false
		for b2: Variant in blist:
			var bd2: Dictionary = b2
			var id: String = str(bd2["id"])
			var nxt: int = int(have[id]) + 1
			if nxt > TIER_COUNT:
				continue
			var tiers: Array = bd2["tiers"]
			var td: Dictionary = tiers[nxt - 1]
			var rq: Dictionary = td["requires"]
			var ok: bool = true
			var spec: Array = rq["specific"]
			for s: Variant in spec:
				var sd: Dictionary = s
				if int(have[str(sd["building"])]) < int(sd["min_tier"]):
					ok = false
			var ao: Variant = rq["any_others"]
			if ok and ao != null:
				var aod: Dictionary = ao
				var n: int = 0
				for other: String in have.keys():
					if other != id and int(have[other]) >= int(aod["min_tier"]):
						n += 1
				if n < int(aod["count"]):
					ok = false
			if ok:
				have[id] = nxt
				progress = true
	for id2: String in have.keys():
		if int(have[id2]) != TIER_COUNT:
			return "prerequisite deadlock or cycle at " + id2
	return ""


# ---------------------------------------------------------------- accessors

func ids() -> Array:
	return _ids.duplicate()


func has_building(id: String) -> bool:
	return _by_id.has(id)


func land_class(id: String) -> String:
	if not _by_id.has(id):
		return ""
	var b: Dictionary = _by_id[id]
	return str(b["land_class"])


func is_heavy(id: String) -> bool:
	return land_class(id) == "heavy"


## Optional extra parcel kind a building needs ("" if none). Homes need a "homes" parcel.
func needs_parcel_kind(id: String) -> String:
	if not _by_id.has(id):
		return ""
	var b: Dictionary = _by_id[id]
	return str(b.get("needs_parcel_kind", ""))


func demo_max_tier(id: String) -> int:
	if not _by_id.has(id):
		return 0
	var b: Dictionary = _by_id[id]
	return int(b["demo_max_tier"])


func demo_max_holes() -> int:
	var d: Dictionary = _data["demo"]
	return int(d["max_holes"])


func hole_cap() -> int:
	return int(_data["hole_cap"])


## Holes scoring below this are dead and do not count toward hole-count gates (DEC-048).
func dead_hole_score_below() -> int:
	var d: Dictionary = _data["hole_rules"]
	return int(d["dead_hole_score_below"])


func home_slots_max() -> int:
	var b: Dictionary = _by_id.get("homes", {})
	var hs: Dictionary = b.get("home_slots", {})
	return int(hs.get("max_slots", 0))


func land_config() -> Dictionary:
	var d: Dictionary = _data["land"]
	return d.duplicate(true)


func tier_data(id: String, tier: int) -> Dictionary:
	if not _by_id.has(id) or tier < 1 or tier > TIER_COUNT:
		return {}
	var b: Dictionary = _by_id[id]
	var tiers: Array = b["tiers"]
	var t: Dictionary = tiers[tier - 1]
	return t


## The requires block of one tier (copy). Empty dictionary for an unknown id or tier.
func tier_requires(id: String, tier: int) -> Dictionary:
	var t: Dictionary = tier_data(id, tier)
	if t.is_empty():
		return {}
	var r: Dictionary = t["requires"]
	return r.duplicate(true)


func target_payback_days(id: String, tier: int) -> int:
	var t: Dictionary = tier_data(id, tier)
	return int(t.get("target_payback_days", 0))


func upkeep_per_day(id: String, tier: int) -> int:
	var t: Dictionary = tier_data(id, tier)
	return int(t.get("upkeep_per_day", 0))


## DEC-050: price = target payback days x added daily income (whole dollars, integer).
## The economy supplies added_daily_income; there is no fixed cost in the data.
func price_for(id: String, tier: int, added_daily_income: int) -> int:
	return target_payback_days(id, tier) * maxi(added_daily_income, 0)


func tier3_spec_ids(id: String) -> Array:
	if not _by_id.has(id):
		return []
	var b: Dictionary = _by_id[id]
	var out: Array = []
	var specs: Array = b["tier3_specs"]
	for s: Variant in specs:
		var sd: Dictionary = s
		out.append(str(sd["id"]))
	return out


## Rank of a tournament level: 0 = none, 1 = local .. 4 = major.
static func level_rank(level: String) -> int:
	var i: int = LEVELS.find(level)
	return i + 1
