class_name MHSliceLayout
extends RefCounted
## Pure world layout for the vertical slice (res://gameplay/mh_vertical_slice.tscn). No scene tree, no session.
## Presentation only: nothing here feeds the sim. Units are metres, +Y up, ground at y = 0.
##
## The land is the 4x4 parcel grid from buildings.json (parcel id = row * 4 + col). A parcel is PARCEL_M
## square (the same 320 dm the live construction scene uses, so the map is 128 m square).
## Buildings sit in CELLS: a parcel holds a 2x2 grid of CELL_M cells, so up to 4 buildings per parcel.
## A building mesh is scaled down (never up) so its tier-5 footprint fits one cell, which keeps the size
## constant while the tier grows. The slot of a building is sticky: once placed it never moves.
## Parcels that a hole corridor may use (HOLE_PARCELS) are RESERVED and never hold a building.
## When no owned free cell is left, a building goes into the ANNEX, a strip of cells just south of the map.
## NOT YET RUN in Godot.
@warning_ignore_start("integer_division")

const COLS: int = 4
const ROWS: int = 4
const PARCEL_M: float = 32.0
const MAP_M: float = 128.0
const CELL_M: float = 16.0
const CELL_MARGIN_M: float = 1.0
const CELLS_PER_PARCEL: int = 4
const PARCEL_COUNT: int = 16
## Slots 0..63 are parcel cells (parcel * 4 + cell). Annex slots start here.
const ANNEX_BASE: int = 64
const ANNEX_COLS: int = 8
const ANNEX_SLOTS: int = 16
const ANNEX_Z0_M: float = 140.0

const YARD_M: float = 0.9144

## Building order for slot assignment. Same ids and order as MHBuildingMeshes.IDS.
const ORDER: Array = ["clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn",
	"maintenance", "lodging", "homes", "landmark"]

## Candidate parcels per building, best first. Reserved (hole) parcels never appear here.
## Parcel kinds from buildings.json: golf 0,1,2,4,5,6,7,9,10,11,13,14; facility 8,12; homes 3,15.
const PREFERENCE: Dictionary = {
	"clubhouse": [8, 12, 1, 2, 13, 14, 3, 15],
	"pro_shop": [8, 12, 1, 2, 13, 14, 3, 15],
	"restaurant": [8, 12, 1, 2, 13, 14, 3, 15],
	"cart_barn": [8, 12, 1, 2, 13, 14, 3, 15],
	"maintenance": [8, 12, 1, 2, 13, 14, 3, 15],
	"driving_range": [1, 2, 13, 14, 8, 12, 3, 15],
	"pool_spa": [1, 2, 13, 14, 8, 12, 3, 15],
	"lodging": [1, 2, 13, 14, 8, 12, 3, 15],
	"landmark": [1, 2, 13, 14, 8, 12, 3, 15],
	"homes": [3, 15, 8, 12, 1, 2, 13, 14],
}

## Hole slot k is built at HOLE_ORIGINS_DM[k] (decimetres, the unit MHCourseLayout uses). Holes run toward +Z.
## Two holes share one parcel column (16 m apart in x), so the four start parcels 5, 6, 9, 10 already
## hold four holes. This table is a development choice, not final routing.
const HOLE_ORIGINS_DM: Array = [[400, 320], [560, 320], [720, 320], [880, 320], [1040, 320], [1200, 320], [80, 5], [240, 5]]
## Parcels each hole slot lies on. A slot can be built only when all of them are owned.
const HOLE_PARCELS: Array = [[5, 9], [5, 9], [6, 10], [6, 10], [7, 11], [7, 11], [0, 4], [0, 4]]
## A short par 3 with fairway, bunker, water and two trees. Scores 34..46 with the Python rating reference
## (tools/reference/rating, seed 0, slots 0..7). The plain 60 yd fairway hole scores 22, which is dead (< 25)
## and earns almost nothing. NOT yet confirmed with the GDScript rating engine.
const HOLE_LENGTH_YD: int = 64
const HOLE_HALF_WIDTH_YD: int = 8
const HOLE_GREEN_RADIUS_YD: int = 5
const HOLE_TREES_YD: Array = [[-10, 30], [10, 40]]


static func hole_slot_count() -> int:
	return HOLE_ORIGINS_DM.size()


## The rating-engine hole definition for hole slot `slot` (same shape as MHOneHolePanel._layout(), more features).
static func hole_template(slot: int) -> Dictionary:
	var trees: Array = []
	for t: Variant in HOLE_TREES_YD:
		trees.append([int((t as Array)[0]), int((t as Array)[1])])
	return {"slot_id": slot, "tee": [0, 0], "green": [0, HOLE_LENGTH_YD, HOLE_GREEN_RADIUS_YD],
		"features": [
			{"t": "fairway", "rect": [-HOLE_HALF_WIDTH_YD, 0, HOLE_HALF_WIDTH_YD, HOLE_LENGTH_YD]},
			{"t": "bunker", "rect": [4, HOLE_LENGTH_YD - 12, 10, HOLE_LENGTH_YD - 4]},
			{"t": "water", "rect": [10, 20, 14, 30]},
			{"t": "tree", "at": trees}]}


## Parcels reserved for hole corridors, ascending, no duplicates.
static func reserved_parcels() -> PackedInt32Array:
	var seen: Dictionary = {}
	for row: Variant in HOLE_PARCELS:
		for p: Variant in (row as Array):
			seen[int(p)] = true
	var keys: Array = seen.keys()
	keys.sort()
	var out: PackedInt32Array = PackedInt32Array()
	for k: Variant in keys:
		out.append(int(k))
	return out


static func is_reserved(parcel: int) -> bool:
	return reserved_parcels().has(parcel)


## True when hole slot `slot` exists and every parcel under it is in `owned`.
static func can_build_hole_slot(slot: int, owned: PackedInt32Array) -> bool:
	if slot < 0 or slot >= HOLE_PARCELS.size():
		return false
	for p: Variant in (HOLE_PARCELS[slot] as Array):
		if not owned.has(int(p)):
			return false
	return true


## Lowest hole slot that is not in `built_slots` and whose parcels are owned, or -1.
static func next_hole_slot(built_slots: Array, owned: PackedInt32Array) -> int:
	for slot: int in range(HOLE_PARCELS.size()):
		if built_slots.has(slot):
			continue
		if can_build_hole_slot(slot, owned):
			return slot
	return -1


## World x,z (metres) of a point in a hole's local yard frame (x across, y toward the green).
static func hole_point_m(slot: int, local_x_yd: int, local_y_yd: int) -> Vector2:
	var o: Array = HOLE_ORIGINS_DM[clampi(slot, 0, HOLE_ORIGINS_DM.size() - 1)] as Array
	return Vector2(float(int(o[0])) * 0.1 + float(local_x_yd) * YARD_M,
		float(int(o[1])) * 0.1 + float(local_y_yd) * YARD_M)


## Tee and green world points of a hole definition (the dictionary the session keeps).
static func hole_points_m(def: Dictionary) -> Dictionary:
	var slot: int = int(def["slot_id"])
	var tee: Array = def["tee"] as Array
	var green: Array = def["green"] as Array
	return {"tee": hole_point_m(slot, int(tee[0]), int(tee[1])),
		"green": hole_point_m(slot, int(green[0]), int(green[1])),
		"green_radius_m": float(int(green[2])) * YARD_M}


## World rectangle (metres) of a hole feature rect [x0, y0, x1, y1] in yards.
static func feature_rect_m(slot: int, rect: Array) -> Rect2:
	var a: Vector2 = hole_point_m(slot, int(rect[0]), int(rect[1]))
	var b: Vector2 = hole_point_m(slot, int(rect[2]), int(rect[3]))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(b.x - a.x), absf(b.y - a.y)))


# ---------------------------------------------------------------- parcels and cells

static func parcel_origin_m(parcel: int) -> Vector2:
	return Vector2(float(parcel % COLS) * PARCEL_M, float(parcel / COLS) * PARCEL_M)


static func parcel_centre_m(parcel: int) -> Vector2:
	return parcel_origin_m(parcel) + Vector2(PARCEL_M * 0.5, PARCEL_M * 0.5)


## Centre of a slot (parcel cell or annex cell) in metres, or Vector2(-1, -1) for an invalid slot.
static func slot_centre_m(slot: int) -> Vector2:
	if slot >= 0 and slot < ANNEX_BASE:
		var parcel: int = slot / CELLS_PER_PARCEL
		var cell: int = slot % CELLS_PER_PARCEL
		return parcel_origin_m(parcel) + Vector2(CELL_M * 0.5 + float(cell % 2) * CELL_M,
			CELL_M * 0.5 + float(cell / 2) * CELL_M)
	if slot >= ANNEX_BASE and slot < ANNEX_BASE + ANNEX_SLOTS:
		var k: int = slot - ANNEX_BASE
		return Vector2(CELL_M * 0.5 + float(k % ANNEX_COLS) * CELL_M, ANNEX_Z0_M + float(k / ANNEX_COLS) * CELL_M)
	return Vector2(-1.0, -1.0)


static func slot_is_annex(slot: int) -> bool:
	return slot >= ANNEX_BASE


## Parcel a slot belongs to, or -1 for the annex and invalid slots.
static func slot_parcel(slot: int) -> int:
	if slot >= 0 and slot < ANNEX_BASE:
		return slot / CELLS_PER_PARCEL
	return -1


## Scale (<= 1) that fits a footprint of size_x by size_z metres into one cell with its margin.
static func fit_scale(size_x: float, size_z: float) -> float:
	var big: float = maxf(size_x, size_z)
	if big <= 0.0001:
		return 1.0
	return minf(1.0, (CELL_M - 2.0 * CELL_MARGIN_M) / big)


## Placement of a building mesh: `bounds5` is the tier-5 AABB of the mesh (stable across tiers, so the
## building does not shift when it grows). The footprint centre of bounds5 lands on the slot centre.
static func building_transform(slot: int, bounds5: AABB) -> Transform3D:
	var s: float = fit_scale(bounds5.size.x, bounds5.size.z)
	var c: Vector2 = slot_centre_m(slot)
	var cx: float = bounds5.position.x + bounds5.size.x * 0.5
	var cz: float = bounds5.position.z + bounds5.size.z * 0.5
	var basis: Basis = Basis.from_scale(Vector3(s, s, s))
	return Transform3D(basis, Vector3(c.x - cx * s, 0.0, c.y - cz * s))


# ---------------------------------------------------------------- slot assignment

## Free slot for `building_id` given owned parcels and already used slots, or -1 when even the annex is full.
static func pick_slot(building_id: String, owned: PackedInt32Array, used: Dictionary) -> int:
	var prefs: Array = PREFERENCE.get(building_id, []) as Array
	for p: Variant in prefs:
		var parcel: int = int(p)
		if not owned.has(parcel) or is_reserved(parcel):
			continue
		for cell: int in range(CELLS_PER_PARCEL):
			var slot: int = parcel * CELLS_PER_PARCEL + cell
			if not used.has(slot):
				return slot
	for k: int in range(ANNEX_SLOTS):
		if not used.has(ANNEX_BASE + k):
			return ANNEX_BASE + k
	return -1


## Slots for every building with tier > 0. `tiers` maps building id to owned tier (MHGameSession.tiers()).
## `previous` is the last result: a previous slot is kept while it is still valid (its parcel is owned and not
## reserved, or it is an annex slot) and not claimed by an earlier building. Others get pick_slot in ORDER.
## Returns {building_id: slot}. Same inputs always give the same output.
static func assign_slots(tiers: Dictionary, owned: PackedInt32Array, previous: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var used: Dictionary = {}
	for id: Variant in ORDER:
		var bid: String = str(id)
		if int(tiers.get(bid, 0)) <= 0 or not previous.has(bid):
			continue
		var old: int = int(previous[bid])
		if _slot_still_valid(old, owned) and not used.has(old):
			out[bid] = old
			used[old] = true
	for id2: Variant in ORDER:
		var bid2: String = str(id2)
		if int(tiers.get(bid2, 0)) <= 0 or out.has(bid2):
			continue
		var slot: int = pick_slot(bid2, owned, used)
		if slot >= 0:
			out[bid2] = slot
			used[slot] = true
	return out


static func _slot_still_valid(slot: int, owned: PackedInt32Array) -> bool:
	if slot_is_annex(slot):
		return slot < ANNEX_BASE + ANNEX_SLOTS
	var parcel: int = slot_parcel(slot)
	return parcel >= 0 and owned.has(parcel) and not is_reserved(parcel)
