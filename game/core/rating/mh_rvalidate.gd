class_name MHRValidate
extends RefCounted
## Deterministic rejection of untrusted hole input (rating-engine.md 2.2). Mirror of validate_input in
## tools/reference/rating/rating_core.py. Never reads a claimed score. JSON parsed by Godot gives every number
## as float, so a float with a whole value counts as an integer; fractional, NaN, infinite, string, bool and
## null values are E07.

const MAX_FEATURES: int = 3000
const MAX_TREES: int = 1500
const COORD_ABS: int = 1200
const SCHEMA_VERSION: int = 1
const TYPES: Array = ["fairway", "deep_rough", "bunker", "water", "ob", "tree", "rock", "flower"]
const AREA_TYPES: Array = ["fairway", "deep_rough", "bunker", "water", "ob"]


static func is_int_value(v: Variant) -> bool:
	var t: int = typeof(v)
	if t == TYPE_INT:
		return true
	if t == TYPE_FLOAT:
		var f: float = v
		return is_finite(f) and absf(f) < 1.0e15 and f == floorf(f)
	return false


static func _num(v: Variant) -> int:
	return int(v)


## Returns {"ok": bool, "code": String}. Order of checks follows the spec table.
static func validate_input(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		return _res("E01_NOT_OBJECT")
	var d: Dictionary = raw
	var sv: Variant = d.get("schema", null)
	if not is_int_value(sv) or _num(sv) != SCHEMA_VERSION:
		return _res("E02_BAD_SCHEMA_VERSION")
	if typeof(d.get("engine", null)) != TYPE_STRING or String(d["engine"]) != MHRParams.ENGINE_VERSION:
		return _res("E03_ENGINE_MISMATCH")
	var hv: Variant = d.get("hole", null)
	if typeof(hv) != TYPE_DICTIONARY:
		return _res("E04_MISSING_FIELD")
	var h: Dictionary = hv
	if not (h.has("tee") and h.has("green") and h.has("features")):
		return _res("E04_MISSING_FIELD")
	var fv: Variant = h["features"]
	var n: int = 0
	if typeof(fv) == TYPE_DICTIONARY:
		var dl: Variant = (fv as Dictionary).get("_len", null)
		if not is_int_value(dl):
			return _res("E04_MISSING_FIELD")
		n = _num(dl)
	elif typeof(fv) == TYPE_ARRAY:
		n = (fv as Array).size()
	else:
		return _res("E04_MISSING_FIELD")
	if n > MAX_FEATURES:
		return _res("E05_TOO_MANY_OBJECTS")
	for pair in [[h["tee"], 2], [h["green"], 3]]:
		var pt: Variant = pair[0]
		var want: int = pair[1]
		if typeof(pt) != TYPE_ARRAY or (pt as Array).size() != want:
			return _res("E06_TRUNCATED_OR_SHAPE")
		for v in (pt as Array):
			if not is_int_value(v):
				return _res("E07_NON_INTEGER")
			if absi(_num(v)) > COORD_ABS:
				return _res("E08_OUT_OF_RANGE")
	if _num((h["green"] as Array)[2]) < 0:
		return _res("E09_NEGATIVE_SIZE")
	if typeof(fv) != TYPE_ARRAY:
		return _res("E10_BAD_FEATURE_TYPE")   # a count-only stub (reference harness) with a small count: no features to read
	var trees: int = 0
	for fe in (fv as Array):
		if typeof(fe) != TYPE_DICTIONARY:
			return _res("E10_BAD_FEATURE_TYPE")
		var f: Dictionary = fe
		if typeof(f.get("t", null)) != TYPE_STRING or not TYPES.has(String(f["t"])):
			return _res("E10_BAD_FEATURE_TYPE")
		for key in ["rect", "circle", "at"]:
			if not f.has(key):
				continue
			var v2: Variant = f[key]
			if typeof(v2) != TYPE_ARRAY:
				return _res("E06_TRUNCATED_OR_SHAPE")
			var arr: Array = v2
			if key == "rect" and arr.size() != 4:
				return _res("E06_TRUNCATED_OR_SHAPE")
			if key == "circle" and arr.size() != 3:
				return _res("E06_TRUNCATED_OR_SHAPE")
			var flat: Array = []
			for e in arr:
				if key == "at":
					if typeof(e) != TYPE_ARRAY or (e as Array).size() != 2:
						return _res("E06_TRUNCATED_OR_SHAPE")
					flat.append_array(e as Array)
				else:
					flat.append(e)
			for e2 in flat:
				if not is_int_value(e2):
					return _res("E07_NON_INTEGER")
				if absi(_num(e2)) > COORD_ABS:
					return _res("E08_OUT_OF_RANGE")
		var t: String = String(f["t"])
		if AREA_TYPES.has(t) and not f.has("rect") and not f.has("circle"):
			return _res("E06_TRUNCATED_OR_SHAPE")
		if f.has("rect"):
			var rc: Array = f["rect"]
			if _num(rc[2]) < _num(rc[0]) or _num(rc[3]) < _num(rc[1]):
				return _res("E09_NEGATIVE_SIZE")
		if f.has("circle") and _num((f["circle"] as Array)[2]) < 0:
			return _res("E09_NEGATIVE_SIZE")
		if f.has("count"):
			if not is_int_value(f["count"]):
				return _res("E07_NON_INTEGER")
			if _num(f["count"]) < 0:
				return _res("E09_NEGATIVE_SIZE")
		if t == "tree":
			if f.has("count"):
				trees += _num(f["count"])
			elif f.has("at"):
				trees += (f["at"] as Array).size()
			if trees > MAX_TREES:
				return _res("E05_TOO_MANY_OBJECTS")
	return {"ok": true, "code": "OK"}


static func _res(code: String) -> Dictionary:
	return {"ok": false, "code": code}
