class_name MHSaveStore
extends RefCounted
## Slot storage: crash-safe writes, read-back verification, .bak generations, fallback loading, torn-pair recovery.
##
## Files for slot N inside `dir` (default user://saves):
##   slot_N.json (+ .tmp, .bak)   the save document (MHSaveGame canonical JSON, sha256 checksum)
##   slot_N.mhts (+ .tmp, .bak)   the terrain blob (MHTerrainSave format), paired to the JSON by
##                                course.terrain.content_hash (32-bit FNV-1a of the heights, 8 hex digits)
##   slot_N.premigrate            copy of the original file made before a migrated save is used (rule 4);
##                                deleted by the next successful save_slot of that slot
##
## Write order in save_slot: blob first, then JSON. A kill between the two leaves the OLD json (its blob is now in
## slot_N.mhts.bak) beside the NEW blob. Loading resolves this generically: every JSON candidate (main, tmp, bak, newest
## revision first) is tried against every blob candidate (main, tmp, bak); the first pair whose blob hash equals the JSON
## content_hash wins. This also covers "JSON newer than blob" (older blob restored, blob write lost) by falling back to
## the previous JSON generation. With heal = true a recovered pair is written back to the main files so a second
## kill cannot destroy the only matching generation.
## FileAccess.flush() is not a guaranteed fsync: process-kill safety is designed for, power-loss durability is not proven.
##
## The store never reads or writes entitlement data (MHSaveGame.validate rejects it).

signal saved(slot: int, revision: int)
signal load_failed(slot: int, code: int)

## Slot 0 is the autosave slot; slots 1 to 4 are manual.
const AUTOSAVE_SLOT: int = 0
const DEFAULT_DIR: String = "user://saves"

enum FaultPoint { NONE = 0, AFTER_BLOB_WRITTEN = 1 }

## Test hook: stop after the blob is written and before the JSON write (a kill between the two files).
static var fault_point: int = FaultPoint.NONE
static var fault_action: int = MHSaveFile.FaultAction.RETURN_ERROR

var dir: String = DEFAULT_DIR
var migrator: MHSaveMigrator = MHSaveMigrator.create_default()
## Test override for the clock; -1 uses the system clock.
var clock_unix: int = -1
## Game-hour index of the last successful autosave in this session, -1 if none.
var last_saved_hour: int = -1

const _SUFFIXES: Array = ["", ".tmp", ".bak"]
const _SUFFIX_NAMES: Array = ["main", "tmp", "bak"]


func _init(p_dir: String = DEFAULT_DIR) -> void:
	dir = p_dir


# ---------------------------------------------------------------- paths

func json_path(slot: int) -> String:
	return dir + "/slot_%d.json" % slot


func blob_name(slot: int) -> String:
	return "slot_%d.mhts" % slot


func blob_path(slot: int) -> String:
	return dir + "/" + blob_name(slot)


func premigrate_path(slot: int) -> String:
	return dir + "/slot_%d.premigrate" % slot


func _now(now_unix: int) -> int:
	if now_unix >= 0:
		return now_unix
	if clock_unix >= 0:
		return clock_unix
	return int(Time.get_unix_time_from_system())


func _slot_ok(slot: int) -> bool:
	return slot >= 0 and slot < MHSaveGame.MAX_SLOTS


func _json_valid(bytes: PackedByteArray) -> bool:
	return MHSaveGame.bytes_parse_ok(bytes)


# ---------------------------------------------------------------- writing

## Saves a new generation of `slot`. `doc` is the game's document (a Dictionary shaped like save.schema.json; the
## checksum key may be absent or stale). `blob` is MHTerrainSave.encode(...) output, required when doc.course has a
## terrain object. The store sets: slot, slot_kind (autosave for slot 0, manual otherwise), revision (highest revision
## on disk or in doc, plus 1), saved_at_unix, save_version, course.terrain.file and course.terrain.content_hash, and the
## checksum. `doc` is not modified. value = MHSaveSummary of what was written (use summary.revision to update the game's copy).
func save_slot(slot: int, doc: Dictionary, blob: PackedByteArray, now_unix: int = -1) -> MHSaveResult:
	if not _slot_ok(slot):
		return MHSaveResult.failure(MHSaveResult.Code.INVALID_ARGUMENT, "slot out of range")
	var nr: MHSaveResult = MHSaveGame.normalize(doc)
	if not nr.is_ok():
		return nr
	var work: Dictionary = nr.value
	var existing_rev: int = _highest_revision(slot)
	var doc_rev: int = 0
	if typeof(work.get("revision", 0)) == TYPE_INT:
		doc_rev = int(work.get("revision", 0))
	work["slot"] = slot
	work["slot_kind"] = "autosave" if slot == AUTOSAVE_SLOT else "manual"
	work["revision"] = maxi(existing_rev, doc_rev) + 1
	work["saved_at_unix"] = _now(now_unix)
	work["save_version"] = MHSaveGame.SAVE_VERSION
	var terr: Dictionary = _terrain_of(work)
	var has_terrain: bool = _has_terrain(work)
	if has_terrain:
		if blob.size() == 0:
			return MHSaveResult.failure(MHSaveResult.Code.INVALID_ARGUMENT, "course.terrain present but no terrain blob given")
		var dec: MHTerrainSave.LoadResult = MHTerrainSave.decode(blob)
		if dec.error != OK:
			return MHSaveResult.failure(MHSaveResult.Code.BLOB_CORRUPT, "terrain blob does not decode: " + dec.message)
		terr["file"] = blob_name(slot)
		terr["content_hash"] = MHHash.hex32(dec.grid.hash_fnv1a())
		(work["course"] as Dictionary)["terrain"] = terr
	elif blob.size() > 0:
		return MHSaveResult.failure(MHSaveResult.Code.INVALID_ARGUMENT, "terrain blob given but course.terrain is absent")
	if work.has("runtime"):
		if typeof(work["runtime"]) != TYPE_DICTIONARY:
			return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "runtime must be an object")
		var rt: Dictionary = work["runtime"]
		rt["terrain_bytes_hash"] = blob_digest(blob)
		work["runtime"] = rt
	MHSaveGame.seal(work)
	var errs: Array = MHSaveGame.validate(work)
	if not errs.is_empty():
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "invalid save: " + "; ".join(PackedStringArray(errs.slice(0, 5))))
	return _commit(slot, work, blob)


## Autosave slot convenience.
func autosave(doc: Dictionary, blob: PackedByteArray, now_unix: int = -1) -> MHSaveResult:
	return save_slot(AUTOSAVE_SLOT, doc, blob, now_unix)


## Autosave at every game hour boundary (DEC-052). value == null means "not due, nothing written".
func autosave_if_due(doc: Dictionary, blob: PackedByteArray, current_game_minute: int, now_unix: int = -1) -> MHSaveResult:
	if not MHAutosavePolicy.should_autosave(current_game_minute, last_saved_hour):
		return MHSaveResult.success(null)
	var r: MHSaveResult = autosave(doc, blob, now_unix)
	if r.is_ok():
		last_saved_hour = MHAutosavePolicy.hour_of(current_game_minute)
	return r


## Writes an already sealed and validated document. Blob first, then JSON.
func _commit(slot: int, work: Dictionary, blob: PackedByteArray) -> MHSaveResult:
	var eerr: int = MHSaveFile.ensure_dir(dir)
	if eerr != OK:
		return MHSaveResult.failure(MHSaveResult.Code.IO_ERROR, "cannot create save directory (%d)" % eerr)
	# A prior interrupted two-file save may have left the last committed JSON paired only with blob .bak.
	# Heal that recoverable pair before rotating another blob generation, or a second failed save can overwrite
	# the only matching backup and leave the slot unloadable.
	_heal_existing_pair(slot)
	if blob.size() > 0:
		var bpath: String = blob_path(slot)
		if MHSaveFile.read_all(bpath) != blob:
			var berr: int = MHTerrainSave.write_atomic(bpath, blob)
			if berr != OK:
				return MHSaveResult.failure(MHSaveResult.Code.IO_ERROR, "terrain blob write failed (%d)" % berr)
	if fault_point == FaultPoint.AFTER_BLOB_WRITTEN:
		push_warning("MHSaveStore: fault injected between blob and JSON write")
		if fault_action == MHSaveFile.FaultAction.KILL_PROCESS:
			OS.kill(OS.get_process_id())
		return MHSaveResult.failure(MHSaveResult.Code.IO_ERROR, "fault injected after blob write")
	var bytes: PackedByteArray = MHSaveGame.to_bytes(work)
	var jerr: int = MHSaveFile.write_atomic(json_path(slot), bytes, Callable(self, "_json_valid"))
	if jerr != OK:
		return MHSaveResult.failure(MHSaveResult.Code.IO_ERROR, "save file write failed (%d)" % jerr)
	# Final read-back of the file that is now in place.
	var check: MHSaveResult = MHSaveGame.parse_bytes(MHSaveFile.read_all(json_path(slot)))
	if not check.is_ok():
		return MHSaveResult.failure(MHSaveResult.Code.VERIFY_FAILED, "post-write verification failed: " + check.message)
	MHSaveFile.remove(premigrate_path(slot))
	var summary: MHSaveSummary = MHSaveSummary.from_doc(work)
	saved.emit(slot, summary.revision)
	return MHSaveResult.success(summary)


func _heal_existing_pair(slot: int) -> void:
	var has_json: bool = false
	for suffix in _SUFFIXES:
		if MHSaveFile.exists(json_path(slot) + String(suffix)):
			has_json = true
			break
	if not has_json:
		return
	# Best effort only. If the existing slot is genuinely corrupt, the new validated save is still allowed to replace it.
	_load_core(slot, true, true)


func _has_terrain(doc: Dictionary) -> bool:
	var c: Variant = doc.get("course", null)
	if typeof(c) != TYPE_DICTIONARY:
		return false
	return typeof((c as Dictionary).get("terrain", null)) == TYPE_DICTIONARY


func _terrain_of(doc: Dictionary) -> Dictionary:
	if not _has_terrain(doc):
		return {}
	return ((doc["course"] as Dictionary)["terrain"] as Dictionary)


func _highest_revision(slot: int) -> int:
	var best: int = -1
	for suffix in _SUFFIXES:
		var r: MHSaveResult = MHSaveGame.parse_bytes(MHSaveFile.read_all(json_path(slot) + String(suffix)))
		if r.is_ok():
			var rv: Variant = (r.value as Dictionary).get("revision", 0)
			if typeof(rv) == TYPE_INT and int(rv) > best:
				best = int(rv)
	return best


# ---------------------------------------------------------------- loading

## Loads the newest verifiable generation of `slot`. Runs the SAVE_MIGRATION.md loader order (parse, schema tag,
## min_reader_version, checksum, migrate, validate) and pairs the terrain blob by content hash, falling back through
## tmp and .bak files. Never returns a partially valid state. If nothing usable exists the files are left untouched.
## heal = true writes a recovered generation back to the main file names after a successful load.
## value = MHLoadedSave.
func load_slot(slot: int, heal: bool = true) -> MHSaveResult:
	var r: MHSaveResult = _load_core(slot, heal, true)
	if not r.is_ok():
		load_failed.emit(slot, r.code)
	return r


func _load_core(slot: int, heal: bool, check_blob: bool) -> MHSaveResult:
	if not _slot_ok(slot):
		return MHSaveResult.failure(MHSaveResult.Code.INVALID_ARGUMENT, "slot out of range")
	var valid: Array = []
	var first_error: MHSaveResult = null
	var any_file: bool = false
	for i in range(_SUFFIXES.size()):
		var bytes: PackedByteArray = MHSaveFile.read_all(json_path(slot) + String(_SUFFIXES[i]))
		if bytes.size() == 0:
			if MHSaveFile.exists(json_path(slot) + String(_SUFFIXES[i])):
				any_file = true
				if first_error == null:
					first_error = MHSaveResult.failure(MHSaveResult.Code.PARSE_ERROR, "empty save file")
			continue
		any_file = true
		var pr: MHSaveResult = MHSaveGame.parse_bytes(bytes)
		if not pr.is_ok():
			if first_error == null:
				first_error = pr
			continue
		var d: Dictionary = pr.value
		valid.append({"order": i, "bytes": bytes, "doc": d, "revision": int(d.get("revision", 0))})
	if valid.is_empty():
		if not any_file:
			return MHSaveResult.failure(MHSaveResult.Code.NOT_FOUND, "no save in slot %d" % slot)
		return first_error
	var pair_error: MHSaveResult = null
	var remaining: Array = valid.duplicate()
	while not remaining.is_empty():
		var best_idx: int = 0
		for j in range(1, remaining.size()):
			var a: Dictionary = remaining[j]
			var b: Dictionary = remaining[best_idx]
			if int(a["revision"]) > int(b["revision"]) or (int(a["revision"]) == int(b["revision"]) and int(a["order"]) < int(b["order"])):
				best_idx = j
		var cand: Dictionary = remaining[best_idx]
		remaining.remove_at(best_idx)
		var res: MHSaveResult = _try_candidate(slot, cand, heal, check_blob)
		if res.is_ok():
			return res
		if res.code == MHSaveResult.Code.BLOB_MISSING or res.code == MHSaveResult.Code.PAIR_MISMATCH or res.code == MHSaveResult.Code.BLOB_CORRUPT:
			if pair_error == null:
				pair_error = res
		elif first_error == null:
			first_error = res
	if pair_error != null:
		return pair_error
	return first_error


func _try_candidate(slot: int, cand: Dictionary, heal: bool, check_blob: bool) -> MHSaveResult:
	var doc: Dictionary = cand["doc"]
	var from_version: int = MHSaveMigrator.version_of(doc)
	var migrated: bool = false
	if migrator.needs_migration(doc):
		var mr: MHSaveResult = migrator.migrate(doc)
		if not mr.is_ok():
			return mr
		doc = mr.value
		MHSaveGame.seal(doc)
		migrated = true
	var strict: bool = from_version <= MHSaveGame.SAVE_VERSION
	var errs: Array = MHSaveGame.validate(doc, strict)
	if not errs.is_empty():
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "invalid save: " + "; ".join(PackedStringArray(errs.slice(0, 5))))
	if int(doc.get("slot", -1)) != slot:
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "file belongs to slot %d, not %d" % [int(doc.get("slot", -1)), slot])
	var loaded := MHLoadedSave.new()
	loaded.data = doc
	loaded.json_source = String(_SUFFIX_NAMES[int(cand["order"])])
	loaded.migrated = migrated
	loaded.from_version = from_version
	loaded.recovered = int(cand["order"]) != 0
	if check_blob and _has_terrain(doc):
		var pr: Dictionary = _find_blob(slot, doc)
		if not bool(pr["ok"]):
			return MHSaveResult.failure(int(pr["code"]), String(pr["message"]))
		loaded.blob = pr["bytes"]
		loaded.blob_source = String(pr["source"])
		if loaded.blob_source != "main":
			loaded.recovered = true
	if loaded.recovered:
		loaded.warnings.append("recovered from %s / blob %s" % [loaded.json_source, loaded.blob_source])
	if heal and check_blob:
		_heal(slot, cand, loaded)
	if migrated:
		var pm: String = premigrate_path(slot)
		if not MHSaveFile.exists(pm):
			if MHSaveFile.ensure_dir(dir) != OK or MHSaveFile.write_plain(pm, cand["bytes"]) != OK:
				loaded.warnings.append("could not write the pre-migration backup")
	return MHSaveResult.success(loaded)


## Finds a blob that decodes and whose height hash equals the JSON's content_hash.
func _find_blob(slot: int, doc: Dictionary) -> Dictionary:
	var terr: Dictionary = _terrain_of(doc)
	var name: Variant = terr.get("file", null)
	if not MHSaveGame.is_safe_blob_name(name):
		return {"ok": false, "code": MHSaveResult.Code.BAD_SCHEMA, "message": "unsafe terrain file name"}
	var base: String = dir + "/" + String(name)
	var want: String = String(terr.get("content_hash", "")).to_lower()
	var saw_file: bool = false
	var saw_decodable: bool = false
	for i in range(_SUFFIXES.size()):
		var bytes: PackedByteArray = MHSaveFile.read_all(base + String(_SUFFIXES[i]))
		if bytes.size() == 0:
			continue
		saw_file = true
		var dec: MHTerrainSave.LoadResult = MHTerrainSave.decode(bytes)
		if dec.error != OK:
			continue
		saw_decodable = true
		if MHHash.hex32(dec.grid.hash_fnv1a()) == want and _exact_blob_matches(doc, bytes):
			return {"ok": true, "bytes": bytes, "source": String(_SUFFIX_NAMES[i])}
	if not saw_file:
		return {"ok": false, "code": MHSaveResult.Code.BLOB_MISSING, "message": "terrain blob file is missing"}
	if not saw_decodable:
		return {"ok": false, "code": MHSaveResult.Code.BLOB_CORRUPT, "message": "terrain blob is damaged and no backup decodes"}
	return {"ok": false, "code": MHSaveResult.Code.PAIR_MISMATCH, "message": "terrain blob does not match the save (torn pair) and no backup matches"}


func _heal(slot: int, cand: Dictionary, loaded: MHLoadedSave) -> void:
	if int(cand["order"]) != 0:
		var jerr: int = MHSaveFile.write_atomic(json_path(slot), cand["bytes"], Callable(self, "_json_valid"))
		if jerr != OK:
			loaded.warnings.append("heal: could not restore the save file (%d)" % jerr)
	if loaded.blob_source != "" and loaded.blob_source != "main":
		var berr: int = MHTerrainSave.write_atomic(blob_path(slot), loaded.blob)
		if berr != OK:
			loaded.warnings.append("heal: could not restore the terrain blob (%d)" % berr)


# ---------------------------------------------------------------- listing

## One row per slot (0 to 4). Cheap by default: it verifies the JSON (checksum, migration, structure) but does not
## decode the terrain blob. check_blob = true also runs the pairing check (slower; use on the load screen only).
func list_slots(check_blob: bool = false) -> Array[MHSlotInfo]:
	var out: Array[MHSlotInfo] = []
	for slot in range(MHSaveGame.MAX_SLOTS):
		var info := MHSlotInfo.new()
		info.slot = slot
		for suffix in _SUFFIXES:
			if MHSaveFile.exists(json_path(slot) + String(suffix)):
				info.present = true
		if info.present:
			var r: MHSaveResult = _load_core(slot, false, check_blob)
			if r.is_ok():
				var ls: MHLoadedSave = r.value
				info.valid = true
				info.summary = MHSaveSummary.from_doc(ls.data)
				info.kind = String(ls.data.get("slot_kind", ""))
				info.source = ls.json_source
			else:
				info.error_code = r.code
				info.error_message = r.message
		out.append(info)
	return out


# ---------------------------------------------------------------- export, import, delete

## value = {"json": PackedByteArray, "blob": PackedByteArray, "summary": MHSaveSummary}: exactly what cloud upload or
## the share sheet needs. Only verified data is exported.
func export_slot(slot: int) -> MHSaveResult:
	var r: MHSaveResult = _load_core(slot, false, true)
	if not r.is_ok():
		return r
	var ls: MHLoadedSave = r.value
	return MHSaveResult.success({
		"json": MHSaveGame.to_bytes(ls.data),
		"blob": ls.blob,
		"summary": MHSaveSummary.from_doc(ls.data),
	})


## Validates a downloaded or imported pair completely before touching anything, then installs it in `slot`.
## Refuses (SLOT_OCCUPIED) to replace an existing slot unless confirmed_overwrite is true; the UI must have asked the
## player (DEC-058). The imported revision is kept (not incremented), so cloud sync stays consistent.
func import_slot(json_bytes: PackedByteArray, blob: PackedByteArray, slot: int, confirmed_overwrite: bool) -> MHSaveResult:
	if not _slot_ok(slot):
		return MHSaveResult.failure(MHSaveResult.Code.INVALID_ARGUMENT, "slot out of range")
	var pr: MHSaveResult = MHSaveGame.parse_bytes(json_bytes)
	if not pr.is_ok():
		return pr
	var doc: Dictionary = pr.value
	var from_version: int = MHSaveMigrator.version_of(doc)
	if migrator.needs_migration(doc):
		var mr: MHSaveResult = migrator.migrate(doc)
		if not mr.is_ok():
			return mr
		doc = mr.value
	var errs: Array = MHSaveGame.validate(doc, from_version <= MHSaveGame.SAVE_VERSION)
	if not errs.is_empty():
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "invalid save: " + "; ".join(PackedStringArray(errs.slice(0, 5))))
	if _has_terrain(doc):
		var dec: MHTerrainSave.LoadResult = MHTerrainSave.decode(blob)
		if dec.error != OK:
			return MHSaveResult.failure(MHSaveResult.Code.BLOB_CORRUPT, "terrain blob does not decode: " + dec.message)
		var terr: Dictionary = _terrain_of(doc)
		if MHHash.hex32(dec.grid.hash_fnv1a()) != String(terr.get("content_hash", "")).to_lower() or not _exact_blob_matches(doc, blob):
			return MHSaveResult.failure(MHSaveResult.Code.PAIR_MISMATCH, "terrain blob does not match the save")
		terr["file"] = blob_name(slot)
		(doc["course"] as Dictionary)["terrain"] = terr
	elif blob.size() > 0:
		return MHSaveResult.failure(MHSaveResult.Code.INVALID_ARGUMENT, "terrain blob given but course.terrain is absent")
	if not confirmed_overwrite:
		for suffix in _SUFFIXES:
			if MHSaveFile.exists(json_path(slot) + String(suffix)):
				return MHSaveResult.failure(MHSaveResult.Code.SLOT_OCCUPIED, "slot %d already has a save" % slot)
	doc["slot"] = slot
	doc["save_version"] = MHSaveGame.SAVE_VERSION
	doc["slot_kind"] = "autosave" if slot == AUTOSAVE_SLOT else "manual"
	MHSaveGame.seal(doc)
	var errs2: Array = MHSaveGame.validate(doc)
	if not errs2.is_empty():
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "invalid save after import: " + "; ".join(PackedStringArray(errs2.slice(0, 5))))
	return _commit(slot, doc, blob)


## Deletes every file of the slot (json, blob, tmp, bak, premigrate). value = number of files removed.
func delete_slot(slot: int) -> MHSaveResult:
	if not _slot_ok(slot):
		return MHSaveResult.failure(MHSaveResult.Code.INVALID_ARGUMENT, "slot out of range")
	var removed: int = 0
	var failed: int = 0
	var paths: Array = [premigrate_path(slot)]
	for suffix in _SUFFIXES:
		paths.append(json_path(slot) + String(suffix))
		paths.append(blob_path(slot) + String(suffix))
	for p in paths:
		if MHSaveFile.exists(String(p)):
			if MHSaveFile.remove(String(p)):
				removed += 1
			else:
				failed += 1
	if failed > 0:
		return MHSaveResult.failure(MHSaveResult.Code.IO_ERROR, "%d files could not be removed" % failed)
	return MHSaveResult.success(removed)



## Exact equality digest of the entire compressed terrain blob, including paint. SHA256 of lowercase hex text.
## hex_encode is documented in Godot's PackedByteArray API; this is not raw-byte SHA256.
static func blob_digest(bytes: PackedByteArray) -> String:
	return bytes.hex_encode().sha256_text()


static func _exact_blob_matches(doc: Dictionary, bytes: PackedByteArray) -> bool:
	if not doc.has("runtime"):
		return true # Legacy pairing remains unchanged.
	return str(doc["runtime"].get("terrain_bytes_hash", "")) == blob_digest(bytes)
