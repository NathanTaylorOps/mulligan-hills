class_name MHJsonFile
extends RefCounted
## Small crash-safe JSON files that are NOT save slots: player settings (analytics consent) and the token ledger.
## Same write path as the save slots (tmp, read-back verify, .bak) via MHSaveFile.write_atomic.
## Content is canonical JSON (MHSaveGame.canonical_json), so integers stay integers.
## read_dict falls back to "<path>.bak" when the main file is missing or damaged.


static func write_dict(path: String, d: Dictionary) -> int:
	var nr: MHSaveResult = MHSaveGame.normalize(d)
	if not nr.is_ok():
		return ERR_INVALID_DATA
	var ensure: int = MHSaveFile.ensure_dir(path.get_base_dir())
	if ensure != OK:
		return ensure
	var bytes: PackedByteArray = MHSaveGame.canonical_json(nr.value).to_utf8_buffer()
	var validator: Callable = func(b: PackedByteArray) -> bool: return _is_dict_bytes(b)
	return MHSaveFile.write_atomic(path, bytes, validator)


## Reads exactly one file with no fallback. value = Dictionary (ints only).
static func read_dict_exact(path: String) -> MHSaveResult:
	if not MHSaveFile.exists(path):
		return MHSaveResult.failure(MHSaveResult.Code.NOT_FOUND, "no file")
	return _parse(MHSaveFile.read_all(path))


## value = Dictionary (ints only). NOT_FOUND when neither file exists.
static func read_dict(path: String) -> MHSaveResult:
	var any: bool = false
	var first: MHSaveResult = null
	for suffix in ["", ".bak"]:
		var p: String = path + String(suffix)
		if not MHSaveFile.exists(p):
			continue
		any = true
		var r: MHSaveResult = read_dict_exact(p)
		if r.is_ok():
			return r
		if first == null:
			first = r
	if not any:
		return MHSaveResult.failure(MHSaveResult.Code.NOT_FOUND, "no file")
	return first


static func delete_all(path: String) -> void:
	for suffix in ["", ".tmp", ".bak"]:
		MHSaveFile.remove(path + String(suffix))


static func _is_dict_bytes(bytes: PackedByteArray) -> bool:
	return _parse(bytes).is_ok()


static func _parse(bytes: PackedByteArray) -> MHSaveResult:
	if bytes.size() == 0:
		return MHSaveResult.failure(MHSaveResult.Code.PARSE_ERROR, "empty file")
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return MHSaveResult.failure(MHSaveResult.Code.PARSE_ERROR, "JSON parse failed")
	if typeof(json.data) != TYPE_DICTIONARY:
		return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, "top level is not an object")
	return MHSaveGame.normalize(json.data)
