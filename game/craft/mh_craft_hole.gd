class_name MHCraftHole
extends RefCounted
## One hole as the player paints it (the "craft" terrain designer, DEC-084, docs/phase1/terrain_designer.md).
## A grid of square tiles in the hole's local frame: x across (0 is the centre line), y toward the green (0 is the
## tee end). One tile is TILE_YD whole yards. Every tile has a surface and an exact integer-millimetre height;
## sculpt tools and imported shared-world shaping preserve millimetre precision. Heights stay
## within HEIGHT_MIN_M..HEIGHT_MAX_M (valleys and high ground, DEC-088). One tee box (DEC-090), up to four pin positions
## (conversion can select by round; current practice uses pin 1), trees as yard points, rock and flower counts.
## Pure data and integer maths: no nodes, no randomness. Strokes are undoable (one undo per finger stroke).
## Verification evidence and pending editor regressions: docs/phase1/terrain_designer.md.

@warning_ignore_start("integer_division")

enum Surface {
	ROUGH = 0, FAIRWAY = 1, FIRST_CUT = 2, DEEP_ROUGH = 3, GREEN = 4, FRINGE = 5, TEE = 6,
	BUNKER = 7, WASTE = 8, WATER = 9, OUT_OF_BOUNDS = 10, PATH = 11, DIRT = 12,
}
const SURFACE_COUNT: int = 13
const TILE_YD: int = 2
const HEIGHT_MIN_M: int = -4
const HEIGHT_MAX_M: int = 16
const MAX_TEES: int = 1
const MAX_PINS: int = 4
const MAX_TREES: int = 1500
const UNDO_LIMIT: int = 100

var cols: int
var rows: int
var surface: PackedByteArray = PackedByteArray()
var height_m: PackedInt32Array = PackedInt32Array()
## Authoritative millimetre heights; height_m is a rounded compatibility cache.
var height_mm: PackedInt32Array = PackedInt32Array()
## Tile coordinates (Vector2i(col, row)).
var tees: Array = []
var pins: Array = []
## Yard points (Vector2i(x, y)) in the hole frame.
var trees: Array = []
var rocks: int = 0
var flowers: int = 0
## Presentation-only course mowing customisation; never enters rating/physics geometry.
var mowing: Dictionary = MHMowingDesign.new().to_dict()

var _stroke: Dictionary = {} # tile index -> [old surface, old rounded metres, old exact mm]
var _stroke_open: bool = false
var _undo: Array = [] # each: tile deltas plus before/after marker arrays
var _stroke_tees: Array = []
var _stroke_pins: Array = []
var _redo: Array = []
var _last_history_indices: PackedInt32Array = PackedInt32Array()


func _init(p_cols: int = 24, p_rows: int = 40) -> void:
	cols = maxi(2, p_cols + (p_cols % 2)) # even, so column cols/2 starts at x = 0
	rows = maxi(2, p_rows)
	surface.resize(cols * rows)
	height_m.resize(cols * rows)
	height_mm.resize(cols * rows)
	surface.fill(Surface.ROUGH)
	height_m.fill(0)
	height_mm.fill(0)


func in_bounds(c: int, r: int) -> bool:
	return c >= 0 and c < cols and r >= 0 and r < rows


func index_of(c: int, r: int) -> int:
	return r * cols + c


func get_surface(c: int, r: int) -> int:
	return int(surface[index_of(c, r)]) if in_bounds(c, r) else Surface.OUT_OF_BOUNDS


func get_height(c: int, r: int) -> int:
	return int(height_m[index_of(c, r)]) if in_bounds(c, r) else 0


func get_height_mm(c: int, r: int) -> int:
	return int(height_mm[index_of(c, r)]) if in_bounds(c, r) else 0


## Left and bottom yard edge of a tile.
func tile_x0_yd(c: int) -> int:
	return (c - cols / 2) * TILE_YD


func tile_y0_yd(r: int) -> int:
	return r * TILE_YD


## Centre of a tile in whole yards (TILE_YD is even).
func tile_centre_yd(c: int, r: int) -> Vector2i:
	return Vector2i(tile_x0_yd(c) + TILE_YD / 2, tile_y0_yd(r) + TILE_YD / 2)


## The tile that holds a yard point, or Vector2i(-1, -1) when outside the grid.
func tile_at_yd(x: int, y: int) -> Vector2i:
	var c: int = floori(float(x) / float(TILE_YD)) + cols / 2
	var r: int = floori(float(y) / float(TILE_YD))
	if not in_bounds(c, r):
		return Vector2i(-1, -1)
	return Vector2i(c, r)



func tile_at_cy(x_cy: int, y_cy: int) -> Vector2i:
	var span: int = TILE_YD * 100
	var c: int = MHRMath.fdiv(x_cy, span) + cols / 2
	var r: int = MHRMath.fdiv(y_cy, span)
	if not in_bounds(c, r):
		return Vector2i(-1, -1)
	return Vector2i(c, r)


# ---------------------------------------------------------------- strokes and undo

func begin_stroke() -> bool:
	if _stroke_open:
		return false
	_stroke = {}
	_stroke_tees = tees.duplicate()
	_stroke_pins = pins.duplicate()
	_stroke_open = true
	return true


func is_stroke_open() -> bool:
	return _stroke_open


## Closes the open stroke. An empty stroke is dropped. A new stroke clears the redo list.
func commit_stroke() -> bool:
	if not _stroke_open:
		return false
	_stroke_open = false
	var changes: Dictionary = {}
	for k: Variant in _stroke.keys():
		var i: int = int(k)
		var old: Array = _stroke[k] as Array
		if int(old[0]) != int(surface[i]) or int(old[1]) != int(height_m[i]) or int(old[2]) != int(height_mm[i]):
			changes[i] = [int(old[0]), int(old[1]), int(old[2]), int(surface[i]), int(height_m[i]), int(height_mm[i])]
	_stroke = {}
	if changes.is_empty() and tees == _stroke_tees and pins == _stroke_pins:
		_last_history_indices = PackedInt32Array()
		return false
	_last_history_indices = PackedInt32Array()
	for key: Variant in changes.keys():
		_last_history_indices.append(int(key))
	_undo.append({"tiles": changes, "tees_before": _stroke_tees, "pins_before": _stroke_pins,
		"tees_after": tees.duplicate(), "pins_after": pins.duplicate()})
	if _undo.size() > UNDO_LIMIT:
		_undo.remove_at(0)
	_redo.clear()
	return true


## Rolls the open stroke back and discards it.
func cancel_stroke() -> void:
	if not _stroke_open:
		return
	for k: Variant in _stroke.keys():
		var i: int = int(k)
		var old: Array = _stroke[k] as Array
		surface[i] = int(old[0])
		height_m[i] = int(old[1])
		height_mm[i] = int(old[2])
	tees = _stroke_tees.duplicate()
	pins = _stroke_pins.duplicate()
	_stroke = {}
	_stroke_open = false


func can_undo() -> bool:
	return not _undo.is_empty() and not _stroke_open


func can_redo() -> bool:
	return not _redo.is_empty() and not _stroke_open


func undo() -> bool:
	if not can_undo():
		return false
	var entry: Dictionary = _undo.pop_back() as Dictionary
	var changes: Dictionary = entry["tiles"] as Dictionary
	tees = (entry["tees_before"] as Array).duplicate()
	pins = (entry["pins_before"] as Array).duplicate()
	_last_history_indices = PackedInt32Array()
	for key: Variant in changes.keys():
		_last_history_indices.append(int(key))
	for k: Variant in changes.keys():
		var v: Array = changes[k] as Array
		surface[int(k)] = int(v[0])
		height_m[int(k)] = int(v[1])
		height_mm[int(k)] = int(v[2])
	_redo.append(entry)
	return true


func redo() -> bool:
	if not can_redo():
		return false
	var entry: Dictionary = _redo.pop_back() as Dictionary
	var changes: Dictionary = entry["tiles"] as Dictionary
	tees = (entry["tees_after"] as Array).duplicate()
	pins = (entry["pins_after"] as Array).duplicate()
	_last_history_indices = PackedInt32Array()
	for key: Variant in changes.keys():
		_last_history_indices.append(int(key))
	for k: Variant in changes.keys():
		var v: Array = changes[k] as Array
		surface[int(k)] = int(v[3])
		height_m[int(k)] = int(v[4])
		height_mm[int(k)] = int(v[5])
	_undo.append(entry)
	return true


func undo_count() -> int:
	return _undo.size()


func redo_count() -> int:
	return _redo.size()


func last_changed_tiles() -> Array:
	var out: Array = []
	for idx: int in _last_history_indices:
		out.append(Vector2i(idx % cols, idx / cols))
	return out


# ---------------------------------------------------------------- painting (call between begin and commit)

func _remember(i: int) -> void:
	if _stroke_open and not _stroke.has(i):
		_stroke[i] = [int(surface[i]), int(height_m[i]), int(height_mm[i])]


func paint_tile(c: int, r: int, s: int) -> void:
	if not in_bounds(c, r) or s < 0 or s >= SURFACE_COUNT:
		return
	var i: int = index_of(c, r)
	_remember(i)
	surface[i] = s


## Round brush: every tile whose centre is within `radius` tiles of (c, r).
func paint_disc(c: int, r: int, radius: int, s: int) -> void:
	var rad: int = maxi(0, radius)
	for dr: int in range(-rad, rad + 1):
		for dc: int in range(-rad, rad + 1):
			if dc * dc + dr * dr <= rad * rad:
				paint_tile(c + dc, r + dr, s)


func paint_rect(c0: int, r0: int, c1: int, r1: int, s: int) -> void:
	for r: int in range(mini(r0, r1), maxi(r0, r1) + 1):
		for c: int in range(mini(c0, c1), maxi(c0, c1) + 1):
			paint_tile(c, r, s)


func set_height_tile(c: int, r: int, metres: int) -> void:
	if not in_bounds(c, r):
		return
	var i: int = index_of(c, r)
	_remember(i)
	var m: int = clampi(metres, HEIGHT_MIN_M, HEIGHT_MAX_M)
	height_m[i] = m
	height_mm[i] = m * 1000


func set_height_mm_tile(c: int, r: int, millimetres: int) -> void:
	if not in_bounds(c, r):
		return
	var i: int = index_of(c, r)
	_remember(i)
	var mm: int = clampi(millimetres, HEIGHT_MIN_M * 1000, HEIGHT_MAX_M * 1000)
	height_mm[i] = mm
	height_m[i] = MHRMath.rdiv(mm, 1000)


func clear_history() -> void:
	if _stroke_open:
		cancel_stroke()
	_undo.clear()
	_redo.clear()
	_last_history_indices = PackedInt32Array()


## Whole-metre entry points remain available to existing callers.
func raise_disc(c: int, r: int, radius: int, delta_m: int) -> void:
	raise_disc_mm(c, r, radius, delta_m * 1000)


func raise_disc_mm(c: int, r: int, radius: int, delta_mm: int) -> void:
	var rad: int = maxi(0, radius)
	for dr: int in range(-rad, rad + 1):
		for dc: int in range(-rad, rad + 1):
			if dc * dc + dr * dr <= rad * rad and in_bounds(c + dc, r + dr):
				set_height_mm_tile(c + dc, r + dr, get_height_mm(c + dc, r + dr) + delta_mm)


func level_disc(c: int, r: int, radius: int, target_m: int) -> void:
	level_disc_mm(c, r, radius, target_m * 1000)


func level_disc_mm(c: int, r: int, radius: int, target_mm: int) -> void:
	var rad: int = maxi(0, radius)
	var target: int = clampi(target_mm, HEIGHT_MIN_M * 1000, HEIGHT_MAX_M * 1000)
	for dr: int in range(-rad, rad + 1):
		for dc: int in range(-rad, rad + 1):
			if dc * dc + dr * dr <= rad * rad and in_bounds(c + dc, r + dr):
				set_height_mm_tile(c + dc, r + dr, target)


func smooth_disc(c: int, r: int, radius: int) -> void:
	var rad: int = maxi(0, radius)
	var updates: Dictionary = {}
	# Compute from the pre-dab grid so iteration order cannot change the result.
	for dr: int in range(-rad, rad + 1):
		for dc: int in range(-rad, rad + 1):
			if dc * dc + dr * dr > rad * rad:
				continue
			var tc: int = c + dc
			var tr: int = r + dr
			if not in_bounds(tc, tr):
				continue
			var total: int = 0
			var count: int = 0
			for nr: int in range(maxi(0, tr - 1), mini(rows - 1, tr + 1) + 1):
				for nc: int in range(maxi(0, tc - 1), mini(cols - 1, tc + 1) + 1):
					total += get_height_mm(nc, nr)
					count += 1
			updates[index_of(tc, tr)] = MHRMath.rdiv(total, maxi(1, count))
	for key: Variant in updates.keys():
		var idx: int = int(key)
		var tc2: int = idx % cols
		var tr2: int = idx / cols
		set_height_mm_tile(tc2, tr2, int(updates[key]))


# ---------------------------------------------------------------- markers (included in strokes) and objects

## Adds the hole's tee box tile. Returns 0, or -1 when the hole already has its tee or the tile is outside the grid.
func add_tee(c: int, r: int) -> int:
	if tees.size() >= MAX_TEES or not in_bounds(c, r):
		return -1
	tees.append(Vector2i(c, r))
	return tees.size() - 1


func add_pin(c: int, r: int) -> int:
	if pins.size() >= MAX_PINS or not in_bounds(c, r) or pins.has(Vector2i(c, r)):
		return -1
	pins.append(Vector2i(c, r))
	return pins.size() - 1


## Marker mutations participate in the same begin/commit/cancel history as terrain.
func move_tee(c: int, r: int) -> bool:
	if not in_bounds(c, r):
		return false
	tees = [Vector2i(c, r)]
	return true


## index == pins.size() appends one pin; existing indices move only that pin.
func set_pin(pin_index: int, c: int, r: int) -> bool:
	if pin_index < 0 or pin_index > pins.size() or pin_index >= MAX_PINS or not in_bounds(c, r):
		return false
	var point: Vector2i = Vector2i(c, r)
	var occupied: int = pins.find(point)
	if occupied >= 0 and occupied != pin_index:
		return false
	if pin_index == pins.size():
		pins.append(point)
	else:
		pins[pin_index] = point
	return true


func remove_pin(pin_index: int) -> bool:
	if pin_index < 0 or pin_index >= pins.size():
		return false
	pins.remove_at(pin_index)
	return true


## The pin used in play round `round_no` (0 based): the pins take turns, so the hole plays differently each round.
func pin_for_round(round_no: int) -> int:
	if pins.is_empty():
		return -1
	return posmod(round_no, pins.size())


func add_tree_yd(x: int, y: int) -> void:
	trees.append(Vector2i(x, y))


func count_surface(s: int) -> int:
	var n: int = 0
	for i: int in range(surface.size()):
		if int(surface[i]) == s:
			n += 1
	return n


# ---------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	var surfaces: Array = []
	var heights: Array = []
	for i: int in range(surface.size()):
		surfaces.append(int(surface[i]))
		heights.append(int(height_mm[i]))
	var tee_rows: Array = []
	for value: Variant in tees:
		var p: Vector2i = value as Vector2i
		tee_rows.append([p.x, p.y])
	var pin_rows: Array = []
	for value: Variant in pins:
		var p: Vector2i = value as Vector2i
		pin_rows.append([p.x, p.y])
	var tree_rows: Array = []
	for value: Variant in trees:
		var p: Vector2i = value as Vector2i
		tree_rows.append([p.x, p.y])
	return {
		"v": 1,
		"cols": cols,
		"rows": rows,
		"surface": surfaces,
		"height_mm": heights,
		"tees": tee_rows,
		"pins": pin_rows,
		"trees": tree_rows,
		"rocks": rocks,
		"flowers": flowers,
		"mowing": mowing.duplicate(true),
	}


static func from_dict(raw: Variant) -> MHCraftHole:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw as Dictionary
	var required: Array = ["v", "cols", "rows", "surface", "height_mm", "tees", "pins", "trees", "rocks", "flowers"]
	if d.size() < required.size() or d.size() > required.size() + 1:
		return null
	for key: String in required:
		if not d.has(key):
			return null
	for key: Variant in d.keys():
		if str(key) not in required and str(key) != "mowing":
			return null
	if not MHRValidate.is_int_value(d["v"]) or int(d["v"]) != 1:
		return null
	if not MHRValidate.is_int_value(d["cols"]) or not MHRValidate.is_int_value(d["rows"]):
		return null
	var p_cols: int = int(d["cols"])
	var p_rows: int = int(d["rows"])
	if p_cols < 2 or p_cols > 600 or p_cols % 2 != 0 or p_rows < 2 or p_rows > 600:
		return null
	if typeof(d["surface"]) != TYPE_ARRAY or typeof(d["height_mm"]) != TYPE_ARRAY:
		return null
	var surfaces: Array = d["surface"] as Array
	var heights: Array = d["height_mm"] as Array
	if surfaces.size() != p_cols * p_rows or heights.size() != p_cols * p_rows:
		return null
	var out: MHCraftHole = MHCraftHole.new(p_cols, p_rows)
	for i: int in range(surfaces.size()):
		if not MHRValidate.is_int_value(surfaces[i]) or int(surfaces[i]) < 0 or int(surfaces[i]) >= SURFACE_COUNT:
			return null
		if not MHRValidate.is_int_value(heights[i]) or int(heights[i]) < HEIGHT_MIN_M * 1000 or int(heights[i]) > HEIGHT_MAX_M * 1000:
			return null
		out.surface[i] = int(surfaces[i])
		out.height_mm[i] = int(heights[i])
		out.height_m[i] = MHRMath.rdiv(int(heights[i]), 1000)
	if not _load_tile_points(d["tees"], out, true) or not _load_tile_points(d["pins"], out, false):
		return null
	if typeof(d["trees"]) != TYPE_ARRAY or (d["trees"] as Array).size() > MAX_TREES:
		return null
	for value: Variant in d["trees"] as Array:
		if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
			return null
		var a: Array = value as Array
		if not MHRValidate.is_int_value(a[0]) or not MHRValidate.is_int_value(a[1]):
			return null
		if absi(int(a[0])) > 1200 or absi(int(a[1])) > 1200:
			return null
		out.trees.append(Vector2i(int(a[0]), int(a[1])))
	if not MHRValidate.is_int_value(d["rocks"]) or not MHRValidate.is_int_value(d["flowers"]):
		return null
	out.rocks = int(d["rocks"])
	out.flowers = int(d["flowers"])
	out.mowing = MHMowingDesign.from_dict(d.get("mowing", {})).to_dict()
	if out.rocks < 0 or out.rocks > 1500 or out.flowers < 0 or out.flowers > 1500:
		return null
	out.clear_history()
	return out


static func _load_tile_points(raw: Variant, out: MHCraftHole, tee_points: bool) -> bool:
	if typeof(raw) != TYPE_ARRAY:
		return false
	var rows_in: Array = raw as Array
	var limit: int = MAX_TEES if tee_points else MAX_PINS
	if rows_in.size() > limit:
		return false
	var target: Array = out.tees if tee_points else out.pins
	var seen: Dictionary = {}
	for value: Variant in rows_in:
		if typeof(value) != TYPE_ARRAY or (value as Array).size() != 2:
			return false
		var a: Array = value as Array
		if not MHRValidate.is_int_value(a[0]) or not MHRValidate.is_int_value(a[1]):
			return false
		var p: Vector2i = Vector2i(int(a[0]), int(a[1]))
		if not out.in_bounds(p.x, p.y) or seen.has(p):
			return false
		seen[p] = true
		target.append(p)
	return true

