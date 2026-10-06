class_name MHStaffDefs
extends RefCounted
## Staff data (res://data/staff.json, schema docs/spec/data/staff.schema.json, spec docs/spec/staff.md).
## Loads, validates structure and exposes read-only accessors. Integer only. Money in this file is integer CENTS.
## All numbers are PLACEHOLDERS tuned with tools/reference/staff/staff_sim.py. NOT YET RUN.

const DEFAULT_PATH: String = "res://data/staff.json"
const NPARCELS: int = 16
const KIND_GROUNDS: String = "grounds"
const KIND_PEST: String = "pest"
const KIND_STATION: String = "station"
const ROLE_KINDS: Array = ["grounds", "pest", "station"]
const LEGACY_GROUPS: Array = ["greenkeepers", "marshals", "pro_shop_staff", "caterers"]
const PARCEL_KINDS: Array = ["golf", "facility", "homes"]
const BUILDING_IDS: Array = [
	"clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn", "maintenance", "lodging", "homes",
	"landmark",
]
## Every key of "params" (all ints, 0..1000000).
const PARAM_KEYS: Array = [
	"max_employees", "max_areas_per_employee", "auto_assign_span", "tenure_gate_days", "hire_cost_days",
	"hire_reserve_days", "cond_start", "cond_untended_floor", "cond_hard_floor", "pest_start", "keeper_work",
	"ranger_control", "pest_growth_base", "pest_growth_cond_div", "pest_natural_cap", "pest_decline_above_cap",
	"pest_damage_div", "incident_chance_div", "incident_max_per_day", "handled_min_control", "handled_damage_pct",
	"sighting_chance_permille", "sighting_ranger_bonus_permille", "sighting_max_pest", "sighting_min_cond",
	"personal_pass_gain", "personal_daily_cap", "personal_patrol_gain", "personal_patrol_cap", "demand_min",
	"demand_max", "cond_neutral", "cond_k_permille", "pest_k_permille", "service_neutral", "service_k_permille",
	"sat_cond_floor", "sat_pen_max", "sat_pen_span", "overlay_beauty_k", "overlay_fairness_k",
]

var load_error: String = ""

var _data: Dictionary = {}
var _params: Dictionary = {}
var _roles: Dictionary = {}
var _role_ids: Array = []
var _grades: Array = []
var _decay: Dictionary = {}
var _service_rec: Array = []
var _incidents: Array = []
var _sightings: Array = []
var _cols: int = 4
var _rows: int = 4
var _loaded: bool = false


static func load_default() -> MHStaffDefs:
	var d: MHStaffDefs = MHStaffDefs.new()
	d.load_from_file(DEFAULT_PATH)
	return d


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


## d must already be normalized (all numbers ints). Structural validation only; the full schema check runs in CI.
func load_from_dict(d: Dictionary) -> bool:
	_loaded = false
	load_error = ""
	_data = {}
	_params = {}
	_roles = {}
	_role_ids = []
	_grades = []
	_decay = {}
	_service_rec = []
	_incidents = []
	_sightings = []
	if str(d.get("schema", "")) != "mh.staff" or int(d.get("schema_version", 0)) != 1:
		return _fail("wrong schema or schema_version")
	var msg: String = _check_grid(d.get("grid", null))
	if msg.is_empty():
		msg = _check_grades(d.get("grades", null))
	if msg.is_empty():
		msg = _check_params(d.get("params", null))
	if msg.is_empty():
		msg = _check_decay(d.get("decay_by_parcel_kind", null))
	if msg.is_empty():
		msg = _check_roles(d.get("roles", null))
	if msg.is_empty():
		msg = _check_kinds(d.get("incident_kinds", null), true)
	if msg.is_empty():
		msg = _check_kinds(d.get("sighting_kinds", null), false)
	if not msg.is_empty():
		return _fail(msg)
	_data = d
	_loaded = true
	return true


func _fail(msg: String) -> bool:
	load_error = msg
	_loaded = false
	return false


func _check_grid(v: Variant) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "grid missing"
	var g: Dictionary = v
	if not MHDataJson.is_int_in(g.get("cols", null), 1, 16) or not MHDataJson.is_int_in(g.get("rows", null), 1, 16):
		return "bad grid"
	if int(g["cols"]) * int(g["rows"]) != NPARCELS:
		return "grid must hold 16 parcels"
	_cols = int(g["cols"])
	_rows = int(g["rows"])
	return ""


func _check_grades(v: Variant) -> String:
	if typeof(v) != TYPE_ARRAY:
		return "grades missing"
	var arr: Array = v
	if arr.size() < 1 or arr.size() > 5:
		return "grades must have 1 to 5 entries"
	var last_tenure: int = -1
	for g: Variant in arr:
		if typeof(g) != TYPE_DICTIONARY:
			return "bad grade"
		var gd: Dictionary = g
		if typeof(gd.get("id", null)) != TYPE_STRING or typeof(gd.get("name_key", null)) != TYPE_STRING:
			return "bad grade id"
		if not MHDataJson.is_int_in(gd.get("min_tenure_days", null), 0, 100000):
			return "bad grade tenure"
		if not MHDataJson.is_int_in(gd.get("wage_permille", null), 100, 10000) or not MHDataJson.is_int_in(gd.get("work_permille", null), 100, 10000):
			return "bad grade permille"
		if int(gd["min_tenure_days"]) <= last_tenure:
			return "grade tenures must rise"
		last_tenure = int(gd["min_tenure_days"])
	if int((arr[0] as Dictionary)["min_tenure_days"]) != 0:
		return "first grade must start at tenure 0"
	_grades = arr.duplicate(true)
	return ""


func _check_params(v: Variant) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "params missing"
	var p: Dictionary = v
	for k: Variant in PARAM_KEYS:
		if not MHDataJson.is_int_in(p.get(str(k), null), 0, 1000000):
			return "bad param " + str(k)
	if not MHDataJson.is_int_array(p.get("service_rec_by_tier", null), 5, 1, 100):
		return "bad service_rec_by_tier"
	if int(p["max_employees"]) < 1 or int(p["max_employees"]) > 200:
		return "max_employees out of range"
	if int(p["max_areas_per_employee"]) < 1 or int(p["max_areas_per_employee"]) > NPARCELS:
		return "max_areas_per_employee out of range"
	if int(p["cond_start"]) > 1000 or int(p["cond_untended_floor"]) > 1000 or int(p["cond_hard_floor"]) > int(p["cond_untended_floor"]):
		return "condition limits out of order"
	if int(p["pest_natural_cap"]) > 1000 or int(p["pest_start"]) > 1000:
		return "pest limits out of range"
	for k2: String in ["pest_growth_cond_div", "pest_damage_div", "incident_chance_div", "sat_pen_span"]:
		if int(p[k2]) < 1:
			return "divisor must be at least 1: " + k2
	if int(p["demand_min"]) > 1000 or int(p["demand_max"]) < 1000:
		return "demand_min/demand_max must bracket 1000"
	if int(p["handled_damage_pct"]) > 100:
		return "handled_damage_pct above 100"
	_params = p.duplicate(true)
	_service_rec = (p["service_rec_by_tier"] as Array).duplicate()
	return ""


func _check_decay(v: Variant) -> String:
	if typeof(v) != TYPE_DICTIONARY:
		return "decay_by_parcel_kind missing"
	var dd: Dictionary = v
	for k: Variant in PARCEL_KINDS:
		if not MHDataJson.is_int_in(dd.get(str(k), null), 0, 1000):
			return "bad decay for " + str(k)
	_decay = dd.duplicate(true)
	return ""


func _check_roles(v: Variant) -> String:
	if typeof(v) != TYPE_ARRAY:
		return "roles missing"
	var arr: Array = v
	if arr.is_empty() or arr.size() > 32:
		return "roles must have 1 to 32 entries"
	for r: Variant in arr:
		if typeof(r) != TYPE_DICTIONARY:
			return "bad role"
		var rd: Dictionary = r
		var rid: String = str(rd.get("id", ""))
		if rid.is_empty() or _roles.has(rid):
			return "missing or duplicate role id"
		if typeof(rd.get("name_key", null)) != TYPE_STRING:
			return "bad role name_key " + rid
		if not BUILDING_IDS.has(str(rd.get("building", ""))):
			return "unknown building for role " + rid
		if not ROLE_KINDS.has(str(rd.get("kind", ""))):
			return "unknown kind for role " + rid
		if not LEGACY_GROUPS.has(str(rd.get("legacy", ""))):
			return "unknown legacy group for role " + rid
		if not MHDataJson.is_int_in(rd.get("daily_wage_cents", null), 1, 1000000):
			return "bad wage for role " + rid
		if not MHDataJson.is_int_array(rd.get("caps_by_tier", null), 5, 0, 100):
			return "bad caps_by_tier for role " + rid
		var prev: int = 0
		for c: Variant in (rd["caps_by_tier"] as Array):
			if int(c) < prev:
				return "caps_by_tier must not fall: " + rid
			prev = int(c)
		if not MHDataJson.is_int_in(rd.get("pace_each", null), 0, 100) or not MHDataJson.is_int_in(rd.get("pace_max", null), 0, 100):
			return "bad pace for role " + rid
		_roles[rid] = rd
		_role_ids.append(rid)
	return ""


func _check_kinds(v: Variant, incident: bool) -> String:
	if typeof(v) != TYPE_ARRAY or (v as Array).is_empty():
		return "kind list missing"
	var seen: Array = []
	for k: Variant in (v as Array):
		if typeof(k) != TYPE_DICTIONARY:
			return "bad kind entry"
		var kd: Dictionary = k
		var kid: String = str(kd.get("id", ""))
		if kid.is_empty() or seen.has(kid) or typeof(kd.get("name_key", null)) != TYPE_STRING:
			return "bad kind id"
		seen.append(kid)
		if incident:
			if not MHDataJson.is_int_in(kd.get("cond_damage", null), 0, 1000) or not MHDataJson.is_int_in(kd.get("pest_add", null), 0, 1000):
				return "bad incident numbers " + kid
	if incident:
		_incidents = (v as Array).duplicate(true)
	else:
		_sightings = (v as Array).duplicate(true)
	return ""


# ------------------------------------------------------------------ accessors
func grid_cols() -> int:
	return _cols


func grid_rows() -> int:
	return _rows


func param(key: String) -> int:
	return int(_params.get(key, 0))


func service_rec(tier: int) -> int:
	return int(_service_rec[clampi(tier, 1, 5) - 1])


func decay(kind: String) -> int:
	return int(_decay.get(kind, 0))


func role_ids() -> Array:
	return _role_ids.duplicate()


func has_role(role_id: String) -> bool:
	return _roles.has(role_id)


func role_index(role_id: String) -> int:
	return _role_ids.find(role_id)


func role(role_id: String) -> Dictionary:
	if not _roles.has(role_id):
		return {}
	return (_roles[role_id] as Dictionary).duplicate(true)


func role_kind(role_id: String) -> String:
	if not _roles.has(role_id):
		return ""
	return str((_roles[role_id] as Dictionary)["kind"])


func role_building(role_id: String) -> String:
	if not _roles.has(role_id):
		return ""
	return str((_roles[role_id] as Dictionary)["building"])


func role_legacy(role_id: String) -> String:
	if not _roles.has(role_id):
		return ""
	return str((_roles[role_id] as Dictionary)["legacy"])


func role_int(role_id: String, key: String) -> int:
	if not _roles.has(role_id):
		return 0
	return int((_roles[role_id] as Dictionary).get(key, 0))


## Employee cap of a role at the given tier of its building (0 when the building is not built).
func cap(role_id: String, building_tier: int) -> int:
	if building_tier <= 0 or not _roles.has(role_id):
		return 0
	var caps: Array = (_roles[role_id] as Dictionary)["caps_by_tier"]
	return int(caps[clampi(building_tier, 1, 5) - 1])


func grade_count() -> int:
	return _grades.size()


func grade_of(tenure: int) -> int:
	var g: int = 0
	for i: int in range(_grades.size()):
		if tenure >= int((_grades[i] as Dictionary)["min_tenure_days"]):
			g = i
	return g


func grade_id(grade_index: int) -> String:
	return str((_grades[clampi(grade_index, 0, _grades.size() - 1)] as Dictionary)["id"])


## Daily wage in cents of an employee with this tenure.
func wage(role_id: String, tenure: int) -> int:
	if not _roles.has(role_id):
		return 0
	var base: int = int((_roles[role_id] as Dictionary)["daily_wage_cents"])
	var wp: int = int((_grades[grade_of(tenure)] as Dictionary)["wage_permille"])
	return MHStaffMath.idiv(base * wp, 1000)


func work_permille(tenure: int) -> int:
	return int((_grades[grade_of(tenure)] as Dictionary)["work_permille"])


## One-off hiring cost in cents (hire_cost_days of a trainee's wage).
func hire_cost(role_id: String) -> int:
	if not _roles.has(role_id):
		return 0
	return int((_roles[role_id] as Dictionary)["daily_wage_cents"]) * param("hire_cost_days")


func incident_kinds() -> Array:
	return _incidents.duplicate(true)


func sighting_kinds() -> Array:
	return _sightings.duplicate(true)


func incident_kind_count() -> int:
	return _incidents.size()


func sighting_kind_count() -> int:
	return _sightings.size()


func incident_kind_at(i: int) -> Dictionary:
	return (_incidents[i] as Dictionary).duplicate(true)


func sighting_id_at(i: int) -> String:
	return str((_sightings[i] as Dictionary)["id"])
