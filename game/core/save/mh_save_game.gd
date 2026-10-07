class_name MHSaveGame
extends RefCounted
## The versioned save document (docs/spec/data/save.schema.json) as a plain Dictionary plus static helpers.
##
## Rules enforced here:
##  - Integers only. JSON parsing yields float64 for every number, so normalize() converts integral floats to int
##    and rejects fractional, NaN, infinite or |v| > 2^53 values. Money is stored in the economy module's smallest
##    whole unit (cents), ratios in permille; this module only guarantees "whole number, in range".
##  - 64-bit values (RNG state) travel as 16 character lowercase hex strings (u64_hex / hex_u64).
##  - canonical_json(): keys sorted, no whitespace, integers printed without ".0". The file on disk IS the canonical
##    serialisation of the sealed document, so save -> load -> save is byte identical.
##  - checksum: sha256 (hex) of canonical_json(document without its "checksum" key).
##  - No entitlement, receipt or unlock data is ever accepted (validate() rejects it).
##  - Ironman is cut (DEC-058): the legacy "ironman" key is optional and must be false when present; slot_kind
##    "ironman" is rejected. New saves leave the key out (strip_legacy_keys removes it from an old document).
##  - Compatibility: every field added after the first v1 files is OPTIONAL (world.minute_of_day, progress.playtime_s,
##    progress.stats, progress.streak, progress.daily, progress.tournaments.hosted_count / attempted_count), so a
##    plain v1 save stays valid and readable without a migration step. Read them with the *_of accessors below,
##    which default a missing value. See SAVE_MIGRATION.md "Additive optional fields".

const SCHEMA_ID: String = "mh.save"
const SAVE_VERSION: int = 1
## Highest min_reader_version this build can read. Bump when a save change is not readable by older apps.
const READER_VERSION: int = 5
const MAX_SLOTS: int = 5
const MAX_INT: int = 9007199254740991
const MAX_FILE_BYTES: int = 16777216
const MAX_DEPTH: int = 48

## Keys a save may carry. "ironman" is legacy (always false, optional).
const TOP_KEYS: Array = [
	"schema", "save_version", "min_reader_version", "written_by", "slot", "slot_kind", "revision",
	"saved_at_unix", "install_id", "mode", "ironman", "checksum", "world", "club", "buildings", "land",
	"course", "sim", "ratings", "progress", "runtime",
]
## Keys every save must carry (TOP_KEYS without the legacy "ironman").
const REQUIRED_TOP_KEYS: Array = [
	"schema", "save_version", "min_reader_version", "written_by", "slot", "slot_kind", "revision",
	"saved_at_unix", "install_id", "mode", "checksum", "world", "club", "buildings", "land",
	"course", "sim", "ratings", "progress",
]
## The game day has 660 game minutes (MHGameClock.MINUTES_PER_DAY, DEC-052), so minute_of_day is 0..659.
const MAX_MINUTE_OF_DAY: int = 659
const MAX_COUNTER: int = 1000000
const MAX_STAT: int = 1000000000
const MAX_STAT_KEYS: int = 64
const MAX_DAILY_HISTORY: int = 30
const MAX_DAILY_BOARD: int = 90
const MAX_STREAK_CLAIMED: int = 64
const FORBIDDEN_KEYS: Array = [
	"unlocked", "entitlement", "entitlements", "receipt", "receipts", "purchase_token", "token", "is_full_version",
	"full_version", "premium",
]
const SLOT_KINDS: Array = ["autosave", "manual", "backup"]
const MODES: Array = ["relaxed", "standard", "tycoon", "sandbox"]
const SEASONS: Array = ["spring", "summer", "autumn", "winter"]
const PLATFORMS: Array = ["android", "ios", "desktop", "test"]
const BUILDING_IDS: Array = [
	"clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn", "maintenance", "lodging",
	"homes", "landmark",
]
const TAG_PATTERN: String = "^[A-Z0-9][A-Za-z0-9._-]{0,31}$"
const ID_PATTERN: String = "^[a-z][a-z0-9_]{1,39}$"

## Optional hook set by the course module: Callable(course: Dictionary) -> Array of error Strings.
static var course_validator: Callable = Callable()


# ---------------------------------------------------------------- numbers

## Deep copy with every integral float turned into int. Fails on fractional/NaN/inf/huge numbers,
## non-String dictionary keys, unsupported types and nesting deeper than MAX_DEPTH.
static func normalize(v: Variant, path: String = "$", depth: int = 0) -> MHSaveResult:
	if depth > MAX_DEPTH:
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "nesting too deep at " + path)
	var t: int = typeof(v)
	if t == TYPE_NIL or t == TYPE_BOOL or t == TYPE_INT or t == TYPE_STRING:
		if t == TYPE_INT:
			var iv: int = v
			if iv > MAX_INT or iv < -MAX_INT:
				return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "integer beyond 2^53 at " + path)
		return MHSaveResult.success(v)
	if t == TYPE_FLOAT:
		var f: float = v
		if is_nan(f) or is_inf(f):
			return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "NaN or infinity at " + path)
		if f != floor(f):
			return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "non-integral number at " + path)
		if absf(f) > float(MAX_INT):
			return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "number beyond 2^53 at " + path)
		return MHSaveResult.success(int(f))
	if t == TYPE_ARRAY:
		var src_a: Array = v
		var out_a: Array = []
		for i in range(src_a.size()):
			var ra: MHSaveResult = normalize(src_a[i], path + "[" + str(i) + "]", depth + 1)
			if not ra.is_ok():
				return ra
			out_a.append(ra.value)
		return MHSaveResult.success(out_a)
	if t == TYPE_DICTIONARY:
		var src_d: Dictionary = v
		var out_d: Dictionary = {}
		for k in src_d.keys():
			if typeof(k) != TYPE_STRING:
				return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "non-string key at " + path)
			var rd: MHSaveResult = normalize(src_d[k], path + "." + String(k), depth + 1)
			if not rd.is_ok():
				return rd
			out_d[k] = rd.value
		return MHSaveResult.success(out_d)
	return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "unsupported value type at " + path)


## 64-bit int -> 16 char lowercase hex (two's complement).
static func u64_hex(v: int) -> String:
	return MHHash.hex32((v >> 32) & 0xFFFFFFFF) + MHHash.hex32(v & 0xFFFFFFFF)


## 16 char hex -> int (two's complement). Returns 0 and sets ok[0] = false for malformed input.
static func hex_u64(s: String, ok: Array = []) -> int:
	var good: bool = _matches("^[0-9a-f]{16}$", s)
	if ok.size() > 0:
		ok[0] = good
	if not good:
		return 0
	var hi: int = s.substr(0, 8).hex_to_int()
	var lo: int = s.substr(8, 8).hex_to_int()
	return ((hi & 0xFFFFFFFF) << 32) | (lo & 0xFFFFFFFF)


# ---------------------------------------------------------------- canonical form and checksum

static func canonical_json(v: Variant) -> String:
	var t: int = typeof(v)
	if t == TYPE_NIL:
		return "null"
	if t == TYPE_BOOL:
		return "true" if bool(v) else "false"
	if t == TYPE_INT:
		return str(v)
	if t == TYPE_FLOAT:
		var f: float = v
		if f == floor(f) and absf(f) <= float(MAX_INT):
			return str(int(f))
		return JSON.stringify(v)
	if t == TYPE_STRING:
		return JSON.stringify(v)
	if t == TYPE_ARRAY:
		var a: Array = v
		var parts_a: PackedStringArray = PackedStringArray()
		for item in a:
			parts_a.append(canonical_json(item))
		return "[" + ",".join(parts_a) + "]"
	if t == TYPE_DICTIONARY:
		var d: Dictionary = v
		var keys: Array = d.keys()
		keys.sort()
		var parts_d: PackedStringArray = PackedStringArray()
		for k in keys:
			parts_d.append(JSON.stringify(String(k)) + ":" + canonical_json(d[k]))
		return "{" + ",".join(parts_d) + "}"
	return "null"


static func compute_checksum(d: Dictionary) -> String:
	var copy: Dictionary = d.duplicate(false)
	copy.erase("checksum")
	return canonical_json(copy).sha256_text()


## Writes (or rewrites) d["checksum"] for the current content.
static func seal(d: Dictionary) -> void:
	d["checksum"] = {"alg": "sha256", "value": compute_checksum(d)}


static func checksum_ok(d: Dictionary) -> bool:
	var c: Variant = d.get("checksum", null)
	if typeof(c) != TYPE_DICTIONARY:
		return false
	var cd: Dictionary = c
	if cd.get("alg", "") != "sha256":
		return false
	return String(cd.get("value", "")) == compute_checksum(d)


static func to_bytes(d: Dictionary) -> PackedByteArray:
	return canonical_json(d).to_utf8_buffer()


## Loader steps 1 to 4 of SAVE_MIGRATION.md: parse, schema tag, min_reader_version, checksum.
## value = normalized Dictionary (still at the file's own save_version).
static func parse_bytes(bytes: PackedByteArray) -> MHSaveResult:
	if bytes.size() == 0:
		return MHSaveResult.failure(MHSaveResult.Code.PARSE_ERROR, "empty file")
	if bytes.size() > MAX_FILE_BYTES:
		return MHSaveResult.failure(MHSaveResult.Code.PARSE_ERROR, "file too large")
	var text: String = bytes.get_string_from_utf8()
	var json := JSON.new()
	var perr: int = json.parse(text)
	if perr != OK:
		return MHSaveResult.failure(MHSaveResult.Code.PARSE_ERROR, "JSON parse failed: " + json.get_error_message())
	if typeof(json.data) != TYPE_DICTIONARY:
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "top level is not an object")
	var nr: MHSaveResult = normalize(json.data)
	if not nr.is_ok():
		return nr
	var d: Dictionary = nr.value
	if d.get("schema", "") != SCHEMA_ID:
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "schema tag is not " + SCHEMA_ID)
	var mrv: Variant = d.get("min_reader_version", 1)
	if typeof(mrv) != TYPE_INT:
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "min_reader_version is not an integer")
	var mrv_i: int = mrv
	if mrv_i > READER_VERSION:
		return MHSaveResult.failure(MHSaveResult.Code.NEEDS_APP_UPDATE, "save needs a newer app (reader version %d)" % mrv_i)
	if not checksum_ok(d):
		return MHSaveResult.failure(MHSaveResult.Code.CHECKSUM_MISMATCH, "checksum mismatch (file damaged)")
	return MHSaveResult.success(d)


static func bytes_parse_ok(bytes: PackedByteArray) -> bool:
	return parse_bytes(bytes).is_ok()


# ---------------------------------------------------------------- validation

static func _matches(pattern: String, s: Variant) -> bool:
	if typeof(s) != TYPE_STRING:
		return false
	var re: RegEx = RegEx.create_from_string(pattern)
	if re == null or not re.is_valid():
		return false
	return re.search(String(s)) != null


static func _int_in(d: Dictionary, key: String, lo: int, hi: int, path: String, errs: Array, required: bool = true) -> void:
	if not d.has(key):
		if required:
			errs.append(path + "." + key + " missing")
		return
	var v: Variant = d[key]
	if typeof(v) != TYPE_INT:
		errs.append(path + "." + key + " is not an integer")
		return
	var i: int = v
	if i < lo or i > hi:
		errs.append(path + "." + key + " out of range")


static func _dict_at(d: Dictionary, key: String, path: String, errs: Array, required: bool = true) -> Dictionary:
	if not d.has(key):
		if required:
			errs.append(path + "." + key + " missing")
		return {}
	if typeof(d[key]) != TYPE_DICTIONARY:
		errs.append(path + "." + key + " is not an object")
		return {}
	return d[key]


static func _array_at(d: Dictionary, key: String, max_items: int, path: String, errs: Array, required: bool = true) -> Array:
	if not d.has(key):
		if required:
			errs.append(path + "." + key + " missing")
		return []
	if typeof(d[key]) != TYPE_ARRAY:
		errs.append(path + "." + key + " is not an array")
		return []
	var a: Array = d[key]
	if a.size() > max_items:
		errs.append(path + "." + key + " has too many items")
	return a


static func _only_keys(d: Dictionary, allowed: Array, path: String, errs: Array) -> void:
	for k in d.keys():
		if not allowed.has(k):
			errs.append(path + " has unknown key " + String(k))


static func _enum_in(d: Dictionary, key: String, allowed: Array, path: String, errs: Array) -> void:
	if not d.has(key):
		errs.append(path + "." + key + " missing")
	elif not allowed.has(d[key]):
		errs.append(path + "." + key + " has an unsupported value")


## Structural validation of the parts the save system owns (top level, world, club, buildings, land, sim,
## ratings, progress, terrain reference). The embedded course is validated by the course module through
## course_validator. This is NOT a full JSON Schema validator: CI runs docs/spec/data/validate.py for that.
## strict = false (file newer than this app but readable) skips the unknown-key checks.
## Returns an Array of error Strings; empty means valid.
static func validate(d: Dictionary, strict: bool = true) -> Array:
	var errs: Array = []
	for k in d.keys():
		if FORBIDDEN_KEYS.has(k):
			errs.append("entitlement data is never stored in a save: " + String(k))
		elif strict and not TOP_KEYS.has(k):
			errs.append("unknown top-level key " + String(k))
	for k2 in REQUIRED_TOP_KEYS:
		if not d.has(k2):
			errs.append("missing top-level key " + String(k2))
	if not errs.is_empty():
		return errs
	if typeof(d["schema"]) != TYPE_STRING or String(d["schema"]) != SCHEMA_ID:
		errs.append("schema tag wrong")
	_int_in(d, "save_version", 1, 1000, "$", errs)
	_int_in(d, "min_reader_version", 1, 1000, "$", errs)
	_int_in(d, "slot", 0, MAX_SLOTS - 1, "$", errs)
	_int_in(d, "revision", 0, MAX_INT, "$", errs)
	_int_in(d, "saved_at_unix", 0, MAX_INT, "$", errs)
	_enum_in(d, "slot_kind", SLOT_KINDS, "$", errs)
	_enum_in(d, "mode", MODES, "$", errs)
	if d.has("ironman") and (typeof(d["ironman"]) != TYPE_BOOL or bool(d["ironman"])):
		errs.append("ironman must be false (ironman was cut in DEC-058)")
	if not _matches("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", d["install_id"]):
		errs.append("install_id malformed")
	var cs: Dictionary = _dict_at(d, "checksum", "$", errs)
	if not cs.is_empty():
		if cs.get("alg", "") != "sha256" or not _matches("^[0-9a-f]{64}$", cs.get("value", null)):
			errs.append("checksum object malformed")
	var wb: Dictionary = _dict_at(d, "written_by", "$", errs)
	if not wb.is_empty():
		if not _matches("^[0-9]+\\.[0-9]+\\.[0-9]+$", wb.get("app_version", null)):
			errs.append("written_by.app_version malformed")
		if not _matches(TAG_PATTERN, wb.get("sim_version", null)):
			errs.append("written_by.sim_version malformed")
		if not _matches(TAG_PATTERN, wb.get("rating_version", null)):
			errs.append("written_by.rating_version malformed")
		_enum_in(wb, "platform", PLATFORMS, "$.written_by", errs)
	var world: Dictionary = _dict_at(d, "world", "$", errs)
	if not world.is_empty():
		_int_in(world, "day", 0, 1000000, "$.world", errs)
		_enum_in(world, "season", SEASONS, "$.world", errs)
		_int_in(world, "minute_of_day", 0, MAX_MINUTE_OF_DAY, "$.world", errs, false)
		if strict:
			_only_keys(world, ["day", "season", "minute_of_day"], "$.world", errs)
	_validate_club(d, strict, errs)
	_validate_buildings(d, errs)
	var land: Dictionary = _dict_at(d, "land", "$", errs)
	if not land.is_empty():
		var ids: Array = _array_at(land, "owned_parcel_ids", 16, "$.land", errs)
		var seen: Dictionary = {}
		for p in ids:
			if typeof(p) != TYPE_INT or int(p) < 0 or int(p) > 15:
				errs.append("$.land.owned_parcel_ids has a bad id")
			elif seen.has(p):
				errs.append("$.land.owned_parcel_ids has a duplicate")
			else:
				seen[p] = true
	_validate_course_ref(d, errs)
	_validate_sim(d, strict, errs)
	_validate_ratings(d, errs)
	_validate_progress(d, errs)
	_validate_runtime(d, errs)
	return errs


static func _validate_club(d: Dictionary, strict: bool, errs: Array) -> void:
	var club: Dictionary = _dict_at(d, "club", "$", errs)
	if club.is_empty():
		return
	_int_in(club, "name_preset_id", 0, 9999, "$.club", errs)
	_int_in(club, "cash", -1000000000, MAX_INT, "$.club", errs)
	_int_in(club, "lifetime_earned", 0, MAX_INT, "$.club", errs)
	_int_in(club, "green_fee", 0, 10000, "$.club", errs)
	_int_in(club, "members", 0, 100000, "$.club", errs)
	_int_in(club, "reputation", 0, 100000, "$.club", errs)
	_int_in(club, "prestige", 0, 1000000, "$.club", errs)
	var staff: Dictionary = _dict_at(club, "staff", "$.club", errs)
	for sk in ["greenkeepers", "marshals", "pro_shop_staff", "caterers"]:
		_int_in(staff, sk, 0, 200, "$.club.staff", errs)
	if club.has("design_style"):
		var ds: Dictionary = _dict_at(club, "design_style", "$.club", errs, false)
		if ds.has("style_id") and not _matches(ID_PATTERN, ds["style_id"]):
			errs.append("$.club.design_style.style_id malformed")
		_int_in(ds, "points", 0, 1000000, "$.club.design_style", errs, false)
	if club.has("staff_roster"):
		_validate_staff_roster(club, errs)
	if strict:
		_only_keys(club, ["name_preset_id", "cash", "lifetime_earned", "green_fee", "members", "reputation",
			"prestige", "design_style", "staff", "staff_roster"], "$.club", errs)


## club.staff_roster is optional (a save without it means no employees; save_version stays 1). Structure only here:
## MHStaff.from_save_block does the full check when the staff module loads it.
static func _validate_staff_roster(club: Dictionary, errs: Array) -> void:
	var sr: Dictionary = _dict_at(club, "staff_roster", "$.club", errs, false)
	if typeof(club["staff_roster"]) != TYPE_DICTIONARY:
		return
	_int_in(sr, "v", 1, 1, "$.club.staff_roster", errs)
	_int_in(sr, "next_serial", 1, 1000000000, "$.club.staff_roster", errs)
	_int_in(sr, "last_day", -1, 1000000, "$.club.staff_roster", errs)
	_array_at(sr, "employees", 120, "$.club.staff_roster", errs)
	for key in ["condition", "pest", "personal_work", "personal_pest"]:
		var arr: Array = _array_at(sr, key, 16, "$.club.staff_roster", errs)
		if arr.size() != 16:
			errs.append("$.club.staff_roster." + key + " must have 16 entries")
	_dict_at(sr, "stats", "$.club.staff_roster", errs)


static func _validate_buildings(d: Dictionary, errs: Array) -> void:
	var arr: Array = _array_at(d, "buildings", 10, "$", errs)
	for i in range(arr.size()):
		if typeof(arr[i]) != TYPE_DICTIONARY:
			errs.append("$.buildings[%d] is not an object" % i)
			continue
		var b: Dictionary = arr[i]
		var bp: String = "$.buildings[%d]" % i
		_enum_in(b, "id", BUILDING_IDS, bp, errs)
		_int_in(b, "tier", 0, 5, bp, errs)
		_int_in(b, "built_day", 0, 1000000, bp, errs, false)
		if b.has("spec") and not [null, "a", "b"].has(b["spec"]):
			errs.append(bp + ".spec bad")


static func _validate_course_ref(d: Dictionary, errs: Array) -> void:
	var course: Dictionary = _dict_at(d, "course", "$", errs)
	if typeof(course.get("schema_version", 1)) == TYPE_INT and int(course.get("schema_version", 1)) == 2 and typeof(d.get("min_reader_version", null)) == TYPE_INT and int(d["min_reader_version"]) < 3:
		errs.append("primitive course requires reader version 3")
	if course.is_empty():
		return
	if course.has("terrain"):
		var terrain: Dictionary = _dict_at(course, "terrain", "$.course", errs, false)
		if not terrain.is_empty():
			if not is_safe_blob_name(terrain.get("file", null)):
				errs.append("$.course.terrain.file is not a plain .mhts file name")
			if not _matches("^[0-9a-f]{8,64}$", terrain.get("content_hash", null)):
				errs.append("$.course.terrain.content_hash malformed")
	if course_validator.is_valid():
		var extra: Variant = course_validator.call(course)
		if typeof(extra) == TYPE_ARRAY:
			for e in extra:
				errs.append("course: " + str(e))


static func is_safe_blob_name(name: Variant) -> bool:
	if typeof(name) != TYPE_STRING:
		return false
	return _matches("^[A-Za-z0-9_][A-Za-z0-9_.-]{0,62}\\.mhts$", name) and not String(name).contains("..")


static func _validate_sim(d: Dictionary, strict: bool, errs: Array) -> void:
	var sim: Dictionary = _dict_at(d, "sim", "$", errs)
	if sim.is_empty():
		return
	_int_in(sim, "rating_epoch", 0, 1000000, "$.sim", errs)
	_int_in(sim, "golfer_serial", 0, MAX_INT, "$.sim", errs)
	if not _matches("^[0-9a-f]{16}$", sim.get("rng_seed", null)):
		errs.append("$.sim.rng_seed must be 16 hex chars")
	if not _matches("^[0-9a-f]{16}$", sim.get("rng_inc", null)):
		errs.append("$.sim.rng_inc must be 16 hex chars")
	var regs: Array = _array_at(sim, "regulars", 200, "$.sim", errs, false)
	for i in range(regs.size()):
		if typeof(regs[i]) != TYPE_DICTIONARY:
			errs.append("$.sim.regulars[%d] is not an object" % i)
			continue
		var r: Dictionary = regs[i]
		_int_in(r, "regular_id", 0, 999, "$.sim.regulars", errs)
		_int_in(r, "visits", 0, 1000000, "$.sim.regulars", errs)
		_int_in(r, "affinity", -100, 100, "$.sim.regulars", errs)
		_int_in(r, "met_day", 0, 1000000, "$.sim.regulars", errs, false)
	if strict:
		_only_keys(sim, ["rating_epoch", "rng_seed", "rng_inc", "golfer_serial", "regulars"], "$.sim", errs)


static func _validate_ratings(d: Dictionary, errs: Array) -> void:
	var rt: Dictionary = _dict_at(d, "ratings", "$", errs)
	if rt.is_empty():
		return
	if not _matches(TAG_PATTERN, rt.get("rating_version", null)):
		errs.append("$.ratings.rating_version malformed")
	_int_in(rt, "computed_day", 0, 1000000, "$.ratings", errs)
	_int_in(rt, "course_score", 0, 100, "$.ratings", errs)
	var holes: Array = _array_at(rt, "holes", 18, "$.ratings", errs)
	for i in range(holes.size()):
		if typeof(holes[i]) != TYPE_DICTIONARY:
			errs.append("$.ratings.holes[%d] is not an object" % i)
			continue
		var h: Dictionary = holes[i]
		_int_in(h, "hole_no", 1, 18, "$.ratings.holes", errs)
		_int_in(h, "score", 0, 100, "$.ratings.holes", errs)
		var axes: Dictionary = _dict_at(h, "axes", "$.ratings.holes", errs)
		for ax in ["accuracy", "imagination", "length", "beauty", "fairness"]:
			_int_in(axes, ax, 0, 100, "$.ratings.holes.axes", errs)
	var snaps: Array = _array_at(rt, "daily_snapshots", 30, "$.ratings", errs, false)
	for s in snaps:
		if typeof(s) != TYPE_DICTIONARY:
			errs.append("$.ratings.daily_snapshots has a non-object")
			continue
		var sd: Dictionary = s
		_int_in(sd, "day", 0, 1000000, "$.ratings.daily_snapshots", errs)
		_int_in(sd, "course_score", 0, 100, "$.ratings.daily_snapshots", errs)
		_int_in(sd, "pace_score", 0, 100, "$.ratings.daily_snapshots", errs)


static func _validate_progress(d: Dictionary, errs: Array) -> void:
	var pr: Dictionary = _dict_at(d, "progress", "$", errs)
	if pr.is_empty():
		return
	_int_in(pr, "tutorial_step", 0, 100, "$.progress", errs)
	for key in ["achievements", "flags"]:
		var items: Array = _array_at(pr, key, 200, "$.progress", errs, key == "achievements")
		for it in items:
			if not _matches(ID_PATTERN, it):
				errs.append("$.progress." + key + " has a malformed id")
	if pr.has("tutorial_done") and typeof(pr["tutorial_done"]) != TYPE_BOOL:
		errs.append("$.progress.tutorial_done is not a boolean")
	var tn: Dictionary = _dict_at(pr, "tournaments", "$.progress", errs)
	if not tn.is_empty():
		_array_at(tn, "hosted_levels", 4, "$.progress.tournaments", errs)
		_int_in(tn, "cooldown_until_day", 0, 1000000, "$.progress.tournaments", errs)
		_int_in(tn, "hosted_count", 0, MAX_COUNTER, "$.progress.tournaments", errs, false)
		_int_in(tn, "attempted_count", 0, MAX_COUNTER, "$.progress.tournaments", errs, false)
	_array_at(pr, "commissions", 20, "$.progress", errs, false)
	_array_at(pr, "card_history", 300, "$.progress", errs, false)
	_array_at(pr, "purchased_tiers", 50, "$.progress", errs, false)
	_int_in(pr, "playtime_s", 0, MAX_INT, "$.progress", errs, false)
	_validate_stats(pr, errs)
	_validate_streak(pr, errs)
	_validate_daily(pr, errs)


## progress.stats: {stat name: int 0..1e9}. Unknown names are not an error here (MHProgressStats drops them on load,
## so a save from a newer build that added a stat still loads); the JSON Schema is the strict check.
static func _validate_stats(pr: Dictionary, errs: Array) -> void:
	var st: Dictionary = _dict_at(pr, "stats", "$.progress", errs, false)
	if st.size() > MAX_STAT_KEYS:
		errs.append("$.progress.stats has too many keys")
	for k in st.keys():
		if not _matches(ID_PATTERN, k):
			errs.append("$.progress.stats has a malformed key")
		else:
			_int_in(st, String(k), 0, MAX_STAT, "$.progress.stats", errs)


static func _validate_streak(pr: Dictionary, errs: Array) -> void:
	var sk: Dictionary = _dict_at(pr, "streak", "$.progress", errs, false)
	if not pr.has("streak"):
		return
	for key in ["current", "best", "grace", "active_days"]:
		_int_in(sk, key, 0, MAX_COUNTER, "$.progress.streak", errs)
	_int_in(sk, "last_day", -1, MAX_COUNTER, "$.progress.streak", errs)
	var claimed: Array = _array_at(sk, "claimed", MAX_STREAK_CLAIMED, "$.progress.streak", errs)
	var seen: Dictionary = {}
	for c in claimed:
		if typeof(c) != TYPE_INT or int(c) < 1 or int(c) > 10000:
			errs.append("$.progress.streak.claimed has a bad day")
		elif seen.has(c):
			errs.append("$.progress.streak.claimed has a duplicate")
		else:
			seen[c] = true


static func _validate_daily(pr: Dictionary, errs: Array) -> void:
	var dd: Dictionary = _dict_at(pr, "daily", "$.progress", errs, false)
	if not pr.has("daily"):
		return
	_int_in(dd, "day", -1, MAX_COUNTER, "$.progress.daily", errs)
	_int_in(dd, "used", 0, 10, "$.progress.daily", errs)
	_int_in(dd, "completed_today", 0, 1, "$.progress.daily", errs)
	_int_in(dd, "best_pm", 0, 1000, "$.progress.daily", errs)
	_int_in(dd, "best_f", 0, 1000, "$.progress.daily", errs)
	_int_in(dd, "attempted_days", 0, MAX_COUNTER, "$.progress.daily", errs)
	_int_in(dd, "completed_days", 0, MAX_COUNTER, "$.progress.daily", errs)
	var hist: Array = _array_at(dd, "history", MAX_DAILY_HISTORY, "$.progress.daily", errs)
	for i in range(hist.size()):
		if typeof(hist[i]) != TYPE_DICTIONARY:
			errs.append("$.progress.daily.history[%d] is not an object" % i)
			continue
		var h: Dictionary = hist[i]
		_int_in(h, "day", 0, MAX_COUNTER, "$.progress.daily.history", errs)
		_int_in(h, "attempts", 0, 10, "$.progress.daily.history", errs)
		_int_in(h, "completed", 0, 1, "$.progress.daily.history", errs)
		_int_in(h, "best_pm", 0, 1000, "$.progress.daily.history", errs)
	var board: Array = _array_at(dd, "board", MAX_DAILY_BOARD, "$.progress.daily", errs)
	for j in range(board.size()):
		if typeof(board[j]) != TYPE_DICTIONARY:
			errs.append("$.progress.daily.board[%d] is not an object" % j)
			continue
		var b: Dictionary = board[j]
		_int_in(b, "day", 0, MAX_COUNTER, "$.progress.daily.board", errs)
		_int_in(b, "score_pm", 0, 1000, "$.progress.daily.board", errs)
		_int_in(b, "fairness_pm", 0, 1000, "$.progress.daily.board", errs)


# ---------------------------------------------------------------- optional fields (v1 additive, see header)

## world.minute_of_day, 0 when the save has none (a v1 save resumes at the start of its day).
static func minute_of_day_of(d: Dictionary) -> int:
	var world: Variant = d.get("world", null)
	if typeof(world) != TYPE_DICTIONARY:
		return 0
	return clampi(_opt_int(world, "minute_of_day"), 0, MAX_MINUTE_OF_DAY)


## progress.playtime_s, 0 when the save has none.
static func playtime_s_of(d: Dictionary) -> int:
	var pr: Variant = d.get("progress", null)
	if typeof(pr) != TYPE_DICTIONARY:
		return 0
	return maxi(0, _opt_int(pr, "playtime_s"))


## A deep copy without legacy keys (today only "ironman"). Use it before sealing a document that came from an old
## save, so the rewritten file matches the current schema. Does not touch the checksum: re-seal afterwards.
static func strip_legacy_keys(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)
	out.erase("ironman")
	return out


static func _opt_int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	if typeof(v) == TYPE_INT:
		return int(v)
	return 0



## Optional exact live checkpoint. Reader 2 is required so an older app cannot silently lose accounting.
static func _validate_runtime(d: Dictionary, errs: Array) -> void:
	if not d.has("runtime"):
		return
	if typeof(d.get("min_reader_version", null)) != TYPE_INT or int(d["min_reader_version"]) < 2:
		errs.append("runtime requires reader version 2")
	var rt: Dictionary = _dict_at(d, "runtime", "$", errs)
	_only_keys(rt, ["v", "clock", "economy", "save_secret", "recent_scores", "ledger_hash", "terrain_bytes_hash", "practice", "craft_draft"], "$.runtime", errs)
	if not _matches("^[0-9a-f]{64}$", rt.get("terrain_bytes_hash", null)):
		errs.append("runtime terrain hash invalid")
	if not _matches("^[0-9a-f]{64}$", rt.get("ledger_hash", null)):
		errs.append("runtime ledger hash invalid")
	_int_in(rt, "v", 1, 1, "$.runtime", errs)
	_int_in(rt, "save_secret", 0, 4294967295, "$.runtime", errs)
	var scores: Array = _array_at(rt, "recent_scores", 14, "$.runtime", errs)
	for score: Variant in scores:
		if typeof(score) != TYPE_INT or int(score) < 0 or int(score) > 100:
			errs.append("runtime score invalid")
	if rt.has("practice"):
		if typeof(d.get("min_reader_version", null)) != TYPE_INT or int(d["min_reader_version"]) < 3 or typeof(rt["practice"]) != TYPE_DICTIONARY:
			errs.append("practice requires reader 3 and an object")
	if rt.has("craft_draft"):
		if typeof(d.get("min_reader_version", null)) != TYPE_INT or int(d["min_reader_version"]) < 4:
			errs.append("craft draft requires reader 4")
		elif MHCraftHole.from_dict(rt["craft_draft"]) == null:
			errs.append("craft draft invalid")
	var cl: Dictionary = _dict_at(rt, "clock", "$.runtime", errs)
	_only_keys(cl, ["v", "real_us_per_day", "total_minutes", "acc", "speed", "paused", "credit"], "$.runtime.clock", errs)
	_int_in(cl, "v", 1, 1, "$.runtime.clock", errs)
	_int_in(cl, "total_minutes", 0, 660000659, "$.runtime.clock", errs)
	_int_in(cl, "acc", 0, 1499999999, "$.runtime.clock", errs)
	_int_in(cl, "credit", 0, 59999999, "$.runtime.clock", errs)
	_enum_in(cl, "real_us_per_day", [900000000, 1500000000], "$.runtime.clock", errs)
	_enum_in(cl, "speed", [1, 2, 4, 8], "$.runtime.clock", errs)
	if typeof(cl.get("paused", null)) != TYPE_BOOL:
		errs.append("runtime clock pause invalid")
	if typeof(cl.get("acc", null)) == TYPE_INT and typeof(cl.get("real_us_per_day", null)) == TYPE_INT and int(cl["acc"]) >= int(cl["real_us_per_day"]):
		errs.append("runtime clock accumulator exceeds period")
	var e: Dictionary = _dict_at(rt, "economy", "$.runtime", errs)
	_only_keys(e, ["v", "tiers", "cash","fee","day","hour","arrears","loan_balance","loans_taken","reputation","holiday_hours","bankrupt","carry_milli","last_daily_upkeep","members_milli","holes","rating","parcels","ext_permille","renovation","total_revenue","total_upkeep_paid"], "$.runtime.economy", errs)
	_int_in(e, "v", 1, 1, "$.runtime.economy", errs)
	_int_in(e, "cash", -1000000000, MAX_INT, "$.runtime.economy", errs)
	_int_in(e, "fee", 0, 25000, "$.runtime.economy", errs)
	_int_in(e, "day", 0, 1000000, "$.runtime.economy", errs)
	_int_in(e, "hour", 0, 10, "$.runtime.economy", errs)
	_int_in(e, "arrears", 0, MAX_INT, "$.runtime.economy", errs)
	_int_in(e, "loan_balance", 0, MAX_INT, "$.runtime.economy", errs)
	_int_in(e, "loans_taken", 0, 1000000, "$.runtime.economy", errs)
	_int_in(e, "reputation", 0, 1000, "$.runtime.economy", errs)
	_int_in(e, "holiday_hours", 0, 1000000, "$.runtime.economy", errs)
	_int_in(e, "bankrupt", 0, 1, "$.runtime.economy", errs)
	_int_in(e, "carry_milli", 0, 999, "$.runtime.economy", errs)
	_int_in(e, "last_daily_upkeep", 0, MAX_INT, "$.runtime.economy", errs)
	_int_in(e, "members_milli", 0, 100000000, "$.runtime.economy", errs)
	_int_in(e, "holes", 0, 18, "$.runtime.economy", errs)
	_int_in(e, "rating", 0, 100, "$.runtime.economy", errs)
	_int_in(e, "parcels", 0, 16, "$.runtime.economy", errs)
	_int_in(e, "ext_permille", 0, 1000000, "$.runtime.economy", errs)
	_int_in(e, "renovation", 0, 12, "$.runtime.economy", errs)
	_int_in(e, "total_revenue", 0, MAX_INT, "$.runtime.economy", errs)
	_int_in(e, "total_upkeep_paid", 0, MAX_INT, "$.runtime.economy", errs)
	var tiers: Array = _array_at(e, "tiers", 10, "$.runtime.economy", errs)
	if tiers.size() != 10:
		errs.append("runtime requires ten tiers")
	for tier: Variant in tiers:
		if typeof(tier) != TYPE_INT or int(tier) < 0 or int(tier) > 5:
			errs.append("runtime tier invalid")
