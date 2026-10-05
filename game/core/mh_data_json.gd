class_name MHDataJson
extends RefCounted
## Shared loader for the integer-only data files (tournaments, daily challenges, achievements, progression).
## JSON numbers reach GDScript as floats. normalize() converts every whole-valued float to an int and records an
## error for anything fractional, so the modules that read the data never touch a float. Never used in the hot
## simulation path: it runs once per file load.

const MAX_SAFE: int = 9007199254740992


## Returns {"ok": bool, "value": Dictionary, "error": String}. The value has all numbers as ints.
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "value": {}, "error": "file not found: " + path}
	return parse_text(FileAccess.get_file_as_string(path))


static func parse_text(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "value": {}, "error": "not a JSON object"}
	var errs: Array = []
	var norm: Variant = normalize(parsed, errs, "$")
	if not errs.is_empty():
		return {"ok": false, "value": {}, "error": str(errs[0])}
	return {"ok": true, "value": norm as Dictionary, "error": ""}


## Deep copy with whole floats turned into ints. Fractional, NaN or huge numbers append a message to errs.
static func normalize(v: Variant, errs: Array, where: String) -> Variant:
	var t: int = typeof(v)
	if t == TYPE_FLOAT:
		var f: float = v
		var i: int = int(f)
		if float(i) != f or i > MAX_SAFE or i < -MAX_SAFE:
			errs.append(where + ": number is not a whole integer")
			return 0
		return i
	if t == TYPE_DICTIONARY:
		var src: Dictionary = v
		var out: Dictionary = {}
		for k: Variant in src.keys():
			out[k] = normalize(src[k], errs, where + "." + str(k))
		return out
	if t == TYPE_ARRAY:
		var arr: Array = v
		var out_a: Array = []
		for i2: int in range(arr.size()):
			out_a.append(normalize(arr[i2], errs, where + "[" + str(i2) + "]"))
		return out_a
	return v


## True when v is an int (after normalize) inside [lo, hi].
static func is_int_in(v: Variant, lo: int, hi: int) -> bool:
	if typeof(v) != TYPE_INT:
		return false
	var i: int = v
	return i >= lo and i <= hi


## True when v is an Array of exactly n ints, every one inside [lo, hi].
static func is_int_array(v: Variant, n: int, lo: int, hi: int) -> bool:
	if typeof(v) != TYPE_ARRAY:
		return false
	var arr: Array = v
	if n >= 0 and arr.size() != n:
		return false
	for x: Variant in arr:
		if not is_int_in(x, lo, hi):
			return false
	return true
