class_name MHCraftHole
extends RefCounted
## One hole as the player paints it (the "craft" terrain designer, DEC-084, docs/phase1/terrain_designer.md).
## A grid of square tiles in the hole's local frame: x across (0 is the centre line), y toward the green (0 is the
## tee end). One tile is TILE_YD whole yards. Every tile has a surface and a height in whole metres, from
## HEIGHT_MIN_M to HEIGHT_MAX_M (valleys and high ground, DEC-088). One tee box (DEC-090), up to four pin positions
## (the pin used rotates each round), trees as yard points, rock and flower counts.
## Pure data and integer maths: no nodes, no randomness. Strokes are undoable (one undo per finger stroke).
## NOT YET RUN in Godot.

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
const UNDO_LIMIT: int = 100

var cols: int
var rows: int
var surface: PackedByteArray = PackedByteArray()
var height_m: PackedInt32Array = PackedInt32Array()
## Tile coordinates (Vector2i(col, row)).
var tees: Array = []
var pins: Array = []
## Yard points (Vector2i(x, y)) in the hole frame.
var trees: Array = []
var rocks: int = 0
var flowers: int = 0

var _stroke: Dictionary = {} # tile index -> [old surface, old height]
var _stroke_open: bool = false
var _undo: Array = [] # each: {index: [old_s, old_h, new_s, new_h]}
var _redo: Array = []


func _init(p_cols: int = 24, p_rows: int = 40) -> void:
	cols = maxi(2, p_cols + (p_cols % 2)) # even, so column cols/2 starts at x = 0
	rows = maxi(1, p_rows)
	surface.resize(cols * rows)
	height_m.resize(cols * rows)
	surface.fill(Surface.ROUGH)
	height_m.fill(0)


func in_bounds(c: int, r: int) -> bool:
	return c >= 0 and c < cols and r >= 0 and r < rows


func index_of(c: int, r: int) -> int:
	return r * cols + c


func get_surface(c: int, r: int) -> int:
	return int(surface[index_of(c, r)]) if in_bounds(c, r) else Surface.OUT_OF_BOUNDS


func get_height(c: int, r: int) -> int:
	return int(height_m[index_of(c, r)]) if in_bounds(c, r) else 0


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


# ---------------------------------------------------------------- strokes and undo

func begin_stroke() -> bool:
	if _stroke_open:
		return false
	_stroke = {}
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
		if int(old[0]) != int(surface[i]) or int(old[1]) != int(height_m[i]):
			changes[i] = [int(old[0]), int(old[1]), int(surface[i]), int(height_m[i])]
	_stroke = {}
	if changes.is_empty():
		return false
	_undo.append(changes)
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
	_stroke = {}
	_stroke_open = false


func can_undo() -> bool:
	return not _undo.is_empty() and not _stroke_open


func can_redo() -> bool:
	return not _redo.is_empty() and not _stroke_open


func undo() -> bool:
	if not can_undo():
		return false
	var changes: Dictionary = _undo.pop_back() as Dictionary
	for k: Variant in changes.keys():
		var v: Array = changes[k] as Array
		surface[int(k)] = int(v[0])
		height_m[int(k)] = int(v[1])
	_redo.append(changes)
	return true


func redo() -> bool:
	if not can_redo():
		return false
	var changes: Dictionary = _redo.pop_back() as Dictionary
	for k: Variant in changes.keys():
		var v: Array = changes[k] as Array
		surface[int(k)] = int(v[2])
		height_m[int(k)] = int(v[3])
	_undo.append(changes)
	return true


func undo_count() -> int:
	return _undo.size()


func redo_count() -> int:
	return _redo.size()


# ---------------------------------------------------------------- painting (call between begin and commit)

func _remember(i: int) -> void:
	if _stroke_open and not _stroke.has(i):
		_stroke[i] = [int(surface[i]), int(height_m[i])]


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
	height_m[i] = clampi(metres, HEIGHT_MIN_M, HEIGHT_MAX_M)


## Raise (+) or lower (-) a round patch by whole metres, clamped to the height range.
func raise_disc(c: int, r: int, radius: int, delta_m: int) -> void:
	var rad: int = maxi(0, radius)
	for dr: int in range(-rad, rad + 1):
		for dc: int in range(-rad, rad + 1):
			if dc * dc + dr * dr <= rad * rad and in_bounds(c + dc, r + dr):
				set_height_tile(c + dc, r + dr, get_height(c + dc, r + dr) + delta_m)


# ---------------------------------------------------------------- tees, pins, objects (not undoable strokes)

## Adds the hole's tee box tile. Returns 0, or -1 when the hole already has its tee or the tile is outside the grid.
func add_tee(c: int, r: int) -> int:
	if tees.size() >= MAX_TEES or not in_bounds(c, r):
		return -1
	tees.append(Vector2i(c, r))
	return tees.size() - 1


func add_pin(c: int, r: int) -> int:
	if pins.size() >= MAX_PINS or not in_bounds(c, r):
		return -1
	pins.append(Vector2i(c, r))
	return pins.size() - 1


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
