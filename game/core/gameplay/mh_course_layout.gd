class_name MHCourseLayout
extends RefCounted
## Exact primitive layout boundary. Legacy dm polygons are preserved but never converted to RHI.
## Origin is world dm; local geometry is the official engine's whole yards. No float sim conversion.
@warning_ignore_start("integer_division")

static func decode(course: Dictionary) -> MHSaveResult:
	if typeof(course.get("holes", null)) != TYPE_ARRAY:
		return _bad("course holes missing")
	if not _world_valid(course.get("world", null)):
		return _bad("course parcels are malformed or incomplete")
	if not MHRValidate.is_int_value(course.get("schema_version", null)):
		return _bad("course version invalid")
	var rows: Array = course["holes"]
	if rows.is_empty():
		return MHSaveResult.success([])
	if int(course.get("schema_version", 0)) != 2 or str(course.get("rating_engine_version", "")) != MHRatingEngine.RATING_VERSION:
		return _bad("legacy polygon course needs its own geometry adapter")
	if rows.size() > 18:
		return _bad("too many holes")
	var layouts: Array = []
	var seen: Dictionary = {}
	for row: Variant in rows:
		if typeof(row) != TYPE_DICTIONARY:
			return _bad("hole must be an object")
		var h: Dictionary = row
		if h.size() != 3 or not MHRValidate.is_int_value(h.get("hole_no", null)) \
			or typeof(h.get("layout", null)) != TYPE_DICTIONARY or not _point(h.get("origin_dm", null)):
			return _bad("primitive hole shape invalid")
		var layout: Dictionary = h["layout"]
		if not MHRValidate.is_int_value(layout.get("slot_id", null)):
			return _bad("hole slot missing")
		var slot: int = int(layout["slot_id"])
		if slot < 0 or slot >= 18 or int(h["hole_no"]) != slot + 1 or seen.has(slot):
			return _bad("hole identity invalid")
		seen[slot] = true
		var validation: Dictionary = MHRatingEngine.validate_input({"schema": 1, "engine": MHRatingEngine.RATING_VERSION, "hole": layout})
		if not bool(validation["ok"]) or not _known_layout(layout):
			return _bad("invalid or ambiguous rating geometry")
		if not _owned_geometry(course, h["origin_dm"] as Array, layout):
			return _bad("hole geometry must remain on owned land")
		layouts.append(layout.duplicate(true))
	return MHSaveResult.success(layouts)


static func encode(layouts: Array, previous: Dictionary, origins: Array) -> MHSaveResult:
	var old: MHSaveResult = decode(previous)
	if not old.is_ok():
		return old # Never overwrite legacy polygons by dropping their geometry.
	if layouts.size() != origins.size():
		return _bad("every hole needs its world origin")
	var course: Dictionary = previous.duplicate(true)
	course["schema_version"] = 2
	course["rating_engine_version"] = MHRatingEngine.RATING_VERSION
	var rows: Array = []
	for i: int in range(layouts.size()):
		if typeof(layouts[i]) != TYPE_DICTIONARY:
			return _bad("hole must be an object")
		var layout: Dictionary = layouts[i]
		if not MHRValidate.is_int_value(layout.get("slot_id", null)):
			return _bad("hole slot missing")
		rows.append({"hole_no": int(layout.get("slot_id", -1)) + 1,
			"origin_dm": origins[i], "layout": layout.duplicate(true)})
	course["holes"] = rows
	var checked: MHSaveResult = decode(course)
	if not checked.is_ok():
		return checked
	return MHSaveResult.success(course)


static func origins(course: Dictionary) -> Array:
	var out: Array = []
	for row: Variant in course.get("holes", []):
		out.append((row as Dictionary).get("origin_dm", []).duplicate())
	return out


## Preserve the exact rational conversion: a whole yard is 9.144 dm. Renderers may convert to floats.
static func world_mm(origin_dm: int, local_cy: int) -> int:
	return origin_dm * 100 + MHRMath.rdiv(local_cy * 9144, 1000)


static func _point(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 2:
		return false
	for n: Variant in v:
		if not MHRValidate.is_int_value(n) or int(n) < 0 or int(n) > 65535:
			return false
	return true


static func _known_layout(h: Dictionary) -> bool:
	for key: Variant in h.keys():
		if not ["slot_id", "tee", "green", "features", "tee_z_mm", "green_z_mm", "relief"].has(key):
			return false
	for key: String in ["tee_z_mm", "green_z_mm"]:
		if h.has(key) and (not MHRValidate.is_int_value(h[key]) or int(h[key]) < -32768 or int(h[key]) > 32767):
			return false
	for row: Variant in h["features"]:
		var f: Dictionary = row
		for key: Variant in f.keys():
			if not ["t", "rect", "circle", "at", "count"].has(key):
				return false
		if f.has("count") and int(f["count"]) > 1500:
			return false
		if f.has("at") and (f["at"] as Array).size() > 1500:
			return false
		var t: String = str(f["t"])
		if MHRValidate.AREA_TYPES.has(t):
			if int(f.has("rect")) + int(f.has("circle")) != 1 or f.has("at") or f.has("count"):
				return false
		elif t == "tree":
			if f.has("circle") or (f.has("at") and (f.has("rect") or f.has("count"))):
				return false
			if not f.has("at") and not (f.has("rect") and f.has("count")):
				return false
	return true


static func _bad(message: String) -> MHSaveResult:
	return MHSaveResult.failure(MHSaveResult.Code.BAD_SCHEMA, message)


static func _owned_geometry(course: Dictionary, origin: Array, h: Dictionary) -> bool:
	if typeof(course.get("world", null)) != TYPE_DICTIONARY:
		return false
	var world: Dictionary = course["world"]
	if typeof(world.get("parcels", null)) != TYPE_ARRAY:
		return false
	var shapes: Array = [[int(h["tee"][0]), int(h["tee"][1]), int(h["tee"][0]), int(h["tee"][1])]]
	var g: Array = h["green"]
	shapes.append([int(g[0]) - int(g[2]), int(g[1]) - int(g[2]), int(g[0]) + int(g[2]), int(g[1]) + int(g[2])])
	for row: Variant in h["features"]:
		var f: Dictionary = row
		if f.has("rect"):
			shapes.append(f["rect"])
		elif f.has("circle"):
			var c: Array = f["circle"]
			shapes.append([int(c[0]) - int(c[2]), int(c[1]) - int(c[2]), int(c[0]) + int(c[2]), int(c[1]) + int(c[2])])
		elif f.has("at"):
			for point: Variant in f["at"]:
				shapes.append([int(point[0]), int(point[1]), int(point[0]), int(point[1])])
	for shape: Variant in shapes:
		var r: Array = shape
		# Rational world positions in tenths of a millimetre, avoiding rounding at parcel edges.
		var x0: int = int(origin[0]) * 1000 + int(r[0]) * 9144
		var y0: int = int(origin[1]) * 1000 + int(r[1]) * 9144
		var x1: int = int(origin[0]) * 1000 + int(r[2]) * 9144
		var y1: int = int(origin[1]) * 1000 + int(r[3]) * 9144
		if x0 < 0 or y0 < 0 or x1 >= int(world.get("width_dm", 0)) * 1000 or y1 >= int(world.get("height_dm", 0)) * 1000:
			return false
		var covered: int = 0
		for parcel: Variant in world["parcels"]:
			if typeof(parcel) != TYPE_DICTIONARY:
				return false
			var p: Dictionary = parcel
			var px0: int = int(p.get("x0", -1)) * 1000
			var py0: int = int(p.get("y0", -1)) * 1000
			var px1: int = (int(p.get("x1", -1)) + 1) * 1000
			var py1: int = (int(p.get("y1", -1)) + 1) * 1000
			if x0 < px1 and x1 >= px0 and y0 < py1 and y1 >= py0:
				if not bool(p.get("owned", false)):
					return false
				covered += 1
		if covered == 0:
			return false
	return true


static func _world_valid(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var w: Dictionary = raw
	for key: String in ["width_dm", "height_dm"]:
		if not MHRValidate.is_int_value(w.get(key, null)) or int(w[key]) < 1000 or int(w[key]) > 65535:
			return false
	if typeof(w.get("parcels", null)) != TYPE_ARRAY or (w["parcels"] as Array).is_empty() or (w["parcels"] as Array).size() > 64:
		return false
	var rects: Array = []
	var ids: Dictionary = {}
	var area: int = 0
	for row: Variant in w["parcels"]:
		if typeof(row) != TYPE_DICTIONARY:
			return false
		var p: Dictionary = row
		for key: String in ["parcel_id", "x0", "y0", "x1", "y1"]:
			if not MHRValidate.is_int_value(p.get(key, null)) or int(p[key]) < 0 or int(p[key]) > 65535:
				return false
		if typeof(p.get("owned", null)) != TYPE_BOOL or ids.has(int(p["parcel_id"])):
			return false
		ids[int(p["parcel_id"])] = true
		var x0: int = int(p["x0"])
		var y0: int = int(p["y0"])
		var x1: int = int(p["x1"]) + 1
		var y1: int = int(p["y1"]) + 1
		if x0 >= x1 or y0 >= y1 or x1 > int(w["width_dm"]) or y1 > int(w["height_dm"]):
			return false
		for r: Variant in rects:
			if x0 < int(r[2]) and x1 > int(r[0]) and y0 < int(r[3]) and y1 > int(r[1]):
				return false
		rects.append([x0, y0, x1, y1])
		area += (x1 - x0) * (y1 - y0)
	return area == int(w["width_dm"]) * int(w["height_dm"])
