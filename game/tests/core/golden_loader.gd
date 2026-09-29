class_name MHGolden
extends RefCounted
## Loads golden vectors written by tools/reference/determinism/gen_golden.py.
## JSON numbers arrive as floats in GDScript (exact below 2^53); larger values are stored as decimal strings.

const DIR: String = "res://tests/core/golden/"


static func load_json(file_name: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(DIR + file_name)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("golden file missing or invalid: " + file_name)
		return {}
	return parsed


## Convert a JSON value (float number or decimal string) to int.
static func i(v: Variant) -> int:
	if typeof(v) == TYPE_STRING:
		return String(v).to_int()
	return int(v)
