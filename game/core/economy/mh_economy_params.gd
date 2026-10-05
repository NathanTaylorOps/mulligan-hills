class_name MHEconomyParams
extends RefCounted
## Tuned economy constants, loaded from res://data/economy_params.json (written by tools/reference/economy/gen_golden.py).
## Integer only. JSON numbers arrive as floats from Godot; integral floats become int, anything else is an error.
## All values are PLACEHOLDERS from the economy simulation (docs/phase1/economy.md), to be re-tuned on closed-test data.
## Money is integer CENTS unless a name ends in _dollars. NOT YET RUN.

const DEFAULT_PATH: String = "res://data/economy_params.json"
const BUILDINGS: int = 10
const TIERS: int = 5
const HOURS_PER_DAY: int = 11
const MAX_HOLES: int = 18

const REQUIRED_CORE: Array = [
	"start_cash_cents", "fee_min_cents", "fee_max_cents", "fee_start_cents", "start_holes", "start_parcels",
	"start_rating", "wtp_base_per_hole_cents", "wtp_per_rating_per_hole_cents", "arrivals_base_milli",
	"arrivals_per_hole_milli", "tee_groups_per_hour", "tee_group_size_x10", "hole_upkeep_cents",
	"parcel_upkeep_cents", "hole_cost_base_dollars", "hole_cost_growth_permille", "member_dues_cents",
	"member_join_rate_permille", "member_rating_floor", "member_rating_span", "bankrupt_arrears_days_x10",
	"bankrupt_min_arrears_cents", "loan_upkeep_days", "loan_min_cents", "loan_max_cents", "loan_fee_permille",
	"loan_repay_share_permille", "loan_max_taken", "loan_rep_penalty_permille", "rep_floor_permille",
	"rep_recover_per_day_permille", "recovery_token_cost", "recovery_holiday_days", "tournament_cost_cents",
	"tournament_regional_cost_cents", "renov_base_dollars", "renov_growth_permille", "renov_max_levels",
	"renov_dem_milli_per_level", "renov_upkeep_cents_per_level", "renov_min_tier",
]

var core: Dictionary = {}
var hour_profile: PackedInt32Array = PackedInt32Array()
var member_cap: PackedInt32Array = PackedInt32Array()
var payback_targets: PackedInt32Array = PackedInt32Array()
var ref_holes: PackedInt32Array = PackedInt32Array()
var ref_rating: PackedInt32Array = PackedInt32Array()
var building_ids: Array = []
## Per-building, per-tier effects, flat arrays of BUILDINGS * TIERS, index = building * TIERS + (tier - 1).
## dem = extra golfers per day x1000, anc = ancillary cents per golfer, flat = cents per day at rating 50,
## cut = permille cut of hole and parcel upkeep.
var eff_dem: PackedInt32Array = PackedInt32Array()
var eff_anc: PackedInt32Array = PackedInt32Array()
var eff_flat: PackedInt32Array = PackedInt32Array()
var eff_cut: PackedInt32Array = PackedInt32Array()
## Net added daily income per building tier in whole dollars (the table the building prices come from).
var added_dollars: PackedInt32Array = PackedInt32Array()
var price_dollars: PackedInt32Array = PackedInt32Array()
var profile_total: int = 0
var _error: String = "not loaded"


static func load_default() -> MHEconomyParams:
	var p: MHEconomyParams = MHEconomyParams.new()
	p.load_path(DEFAULT_PATH)
	return p


static func from_text(text: String) -> MHEconomyParams:
	var p: MHEconomyParams = MHEconomyParams.new()
	p.load_text(text)
	return p


func load_path(path: String) -> String:
	if not FileAccess.file_exists(path):
		_fail("file missing: " + path)
		return _error
	return load_text(FileAccess.get_file_as_string(path))


## Returns "" on success, otherwise a short error message (also kept in error()).
func load_text(text: String) -> String:
	_reset()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("not a JSON object")
		return _error
	var d: Dictionary = parsed
	if not d.has("core") or typeof(d["core"]) != TYPE_DICTIONARY:
		_fail("missing core")
		return _error
	var src_core: Dictionary = d["core"]
	for k: Variant in REQUIRED_CORE:
		var key: String = str(k)
		if not src_core.has(key):
			_fail("missing core key " + key)
			return _error
		var cv: Variant = int_or_null(src_core[key])
		if cv == null:
			_fail("core key not an integer: " + key)
			return _error
		core[key] = int(cv)
	var e: String = ""
	hour_profile = _read_ints(d, "hour_profile", HOURS_PER_DAY)
	member_cap = _read_ints(d, "member_cap", TIERS)
	payback_targets = _read_ints(d, "payback_targets_days", TIERS)
	ref_holes = _read_ints(d, "ref_holes", TIERS)
	ref_rating = _read_ints(d, "ref_rating", TIERS)
	if hour_profile.is_empty() or member_cap.is_empty() or payback_targets.is_empty() or ref_holes.is_empty() or ref_rating.is_empty():
		_fail("bad array in params")
		return _error
	if not d.has("building_ids") or typeof(d["building_ids"]) != TYPE_ARRAY:
		_fail("missing building_ids")
		return _error
	var ids_src: Array = d["building_ids"]
	if ids_src.size() != BUILDINGS:
		_fail("building_ids must have 10 entries")
		return _error
	for v: Variant in ids_src:
		building_ids.append(str(v))
	profile_total = 0
	for v: int in hour_profile:
		profile_total += v
	if profile_total <= 0:
		_fail("hour_profile sums to zero")
		return _error
	if not d.has("effects") or typeof(d["effects"]) != TYPE_DICTIONARY:
		_fail("missing effects")
		return _error
	var effects: Dictionary = d["effects"]
	eff_dem = _read_effect(effects, "dem")
	eff_anc = _read_effect(effects, "anc")
	eff_flat = _read_effect(effects, "flat")
	eff_cut = _read_effect(effects, "cut")
	if eff_dem.is_empty() or eff_anc.is_empty() or eff_flat.is_empty() or eff_cut.is_empty():
		_fail("bad effects table")
		return _error
	added_dollars = _read_table(d, "added_daily_income_dollars")
	price_dollars = _read_table(d, "price_dollars")
	if added_dollars.is_empty() or price_dollars.is_empty():
		_fail("missing price tables")
		return _error
	e = _check_ranges()
	if e != "":
		_fail(e)
		return _error
	_error = ""
	return ""


func is_loaded() -> bool:
	return _error == ""


func error() -> String:
	return _error


## Core constant by name (0 for an unknown name; REQUIRED_CORE guarantees the known ones exist).
func c(key: String) -> int:
	return int(core.get(key, 0))


func building_index(id: String) -> int:
	return building_ids.find(id)


func _reset() -> void:
	core = {}
	hour_profile = PackedInt32Array()
	member_cap = PackedInt32Array()
	payback_targets = PackedInt32Array()
	ref_holes = PackedInt32Array()
	ref_rating = PackedInt32Array()
	building_ids = []
	eff_dem = PackedInt32Array()
	eff_anc = PackedInt32Array()
	eff_flat = PackedInt32Array()
	eff_cut = PackedInt32Array()
	added_dollars = PackedInt32Array()
	price_dollars = PackedInt32Array()
	profile_total = 0


func _fail(msg: String) -> void:
	_error = msg
	_reset()


## Integral float or int becomes int; anything else gives null.
static func int_or_null(v: Variant) -> Variant:
	var t: int = typeof(v)
	if t == TYPE_INT:
		return v
	if t == TYPE_FLOAT:
		var f: float = v
		var i: int = int(f)
		if float(i) != f or i > 9007199254740992 or i < -9007199254740992:
			return null
		return i
	return null


static func _read_ints(d: Dictionary, key: String, want: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not d.has(key) or typeof(d[key]) != TYPE_ARRAY:
		return out
	var arr: Array = d[key]
	if arr.size() != want:
		return out
	for v: Variant in arr:
		var iv: Variant = int_or_null(v)
		if iv == null:
			return PackedInt32Array()
		out.append(int(iv))
	return out


func _read_effect(effects: Dictionary, key: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(BUILDINGS * TIERS)
	for b: int in range(BUILDINGS):
		var id: String = str(building_ids[b])
		if not effects.has(id) or typeof(effects[id]) != TYPE_DICTIONARY:
			return PackedInt32Array()
		var per: Dictionary = effects[id]
		if not per.has(key):
			continue
		var arr_v: Variant = per[key]
		if typeof(arr_v) != TYPE_ARRAY:
			return PackedInt32Array()
		var arr: Array = arr_v
		if arr.size() != TIERS:
			return PackedInt32Array()
		for t: int in range(TIERS):
			var iv: Variant = int_or_null(arr[t])
			if iv == null:
				return PackedInt32Array()
			out[b * TIERS + t] = int(iv)
	return out


func _read_table(d: Dictionary, key: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if not d.has(key) or typeof(d[key]) != TYPE_DICTIONARY:
		return out
	var tbl: Dictionary = d[key]
	out.resize(BUILDINGS * TIERS)
	for b: int in range(BUILDINGS):
		var id: String = str(building_ids[b])
		if not tbl.has(id) or typeof(tbl[id]) != TYPE_ARRAY:
			return PackedInt32Array()
		var arr: Array = tbl[id]
		if arr.size() != TIERS:
			return PackedInt32Array()
		for t: int in range(TIERS):
			var iv: Variant = int_or_null(arr[t])
			if iv == null:
				return PackedInt32Array()
			out[b * TIERS + t] = int(iv)
	return out


func _check_ranges() -> String:
	if c("fee_min_cents") < 1 or c("fee_max_cents") < c("fee_min_cents"):
		return "bad fee range"
	if c("member_rating_span") < 1:
		return "member_rating_span must be positive"
	if c("hole_cost_growth_permille") < 1000:
		return "hole_cost_growth_permille below 1000"
	if c("tee_groups_per_hour") < 1 or c("tee_group_size_x10") < 10:
		return "bad tee capacity"
	if c("renov_growth_permille") < 1000:
		return "renov_growth_permille below 1000"
	if c("renov_max_levels") < 0 or c("renov_max_levels") > 100:
		return "renov_max_levels outside 0..100"
	if c("renov_base_dollars") < 0 or c("renov_dem_milli_per_level") < 0 or c("renov_upkeep_cents_per_level") < 0:
		return "negative renovation constant"
	if c("renov_min_tier") < 1 or c("renov_min_tier") > TIERS:
		return "renov_min_tier outside 1..5"
	for v: int in hour_profile:
		if v < 0:
			return "negative hour_profile entry"
	for v: int in eff_cut:
		if v < 0 or v > 900:
			return "cut effect outside 0..900"
	for v: int in eff_dem:
		if v < 0:
			return "negative demand effect"
	return ""
