class_name MHRatingGolden
extends RefCounted
## Loads tools/reference/rating/gen_golden.py output (golden/rating_golden.json). JSON numbers arrive as floats
## in GDScript (exact below 2^53, all values here are below 2^33); hashes are strings.

const PATH: String = "res://tests/rating/golden/rating_golden.json"
static var _cache: Dictionary = {}


static func load_all() -> Dictionary:
	if _cache.size() > 0:
		return _cache
	var text: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("rating golden missing or invalid: " + PATH)
		return {}
	_cache = parsed
	return _cache


static func i(v: Variant) -> int:
	if typeof(v) == TYPE_STRING:
		return String(v).to_int()
	return int(v)


## Array of JSON numbers -> PackedInt32Array-free plain Array of ints.
static func ints(v: Variant) -> Array:
	var out: Array = []
	for e in (v as Array):
		out.append(int(e))
	return out
