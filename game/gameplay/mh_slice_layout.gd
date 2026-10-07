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
## Cells under a hole corridor (HOLE_ORIGINS_DM, 16 m wide) are RESERVED and never hold a building. Cells that no
## corridor touches stay free for buildings even inside a hole parcel (the east column of parcels 6 and 10 sits
## right beside the three starter holes). When no owned free cell is left, a building goes into the ANNEX, a strip
## of cells just south of the map (fallback only).
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

## Candidate parcels per building, best first. Only cells that no hole corridor touches are used, so listing a hole
## parcel (6, 10) is safe: just its free east column is offered. Parcel kinds from buildings.json: golf
## 0,1,2,4,5,6,7,9,10,11,13,14; facility 8,12; homes 3,15.
const PREFERENCE: Dictionary = {
	"clubhouse": [8, 6, 10, 12, 1, 2, 13, 14, 3, 15],
	"pro_shop": [8, 6, 10, 12, 1, 2, 13, 14, 3, 15],
	"restaurant": [8, 6, 10, 12, 1, 2, 13, 14, 3, 15],
	"cart_barn": [8, 6, 10, 12, 1, 2, 13, 14, 3, 15],
	"maintenance": [8, 6, 10, 12, 1, 2, 13, 14, 3, 15],
	"driving_range": [1, 2, 13, 14, 6, 10, 8, 12, 3, 15],
	"pool_spa": [1, 2, 13, 14, 6, 10, 8, 12, 3, 15],
	"lodging": [1, 2, 13, 14, 6, 10, 8, 12, 3, 15],
	"landmark": [1, 2, 13, 14, 6, 10, 8, 12, 3, 15],
	"homes": [3, 15, 8, 12, 6, 10, 1, 2, 13, 14],
}

## Hole slot k is built at HOLE_ORIGINS_DM[k] (decimetres, the unit MHCourseLayout uses). Holes run toward +Z.
## Slots 0..2 are the starter holes on parcels 5/9 and 6/10 (16 m pitch, x 32..80), which leaves x 80..96 of
## parcels 6 and 10 free for four building cells right beside the course. Slots 3, 4 need parcels 7 and 11,
## slots 5, 6 need parcels 0 and 4. Development choice, not final routing. Seven sites, so the slice cannot
## reach the 10 holes the tier 3 gates ask for.
const HOLE_ORIGINS_DM: Array = [[400, 320], [560, 320], [720, 320], [1040, 320], [1200, 320], [80, 5], [240, 5]]
## Parcels each hole slot lies on. A slot can be built only when all of them are owned.
const HOLE_PARCELS: Array = [[5, 9], [5, 9], [6, 10], [7, 11], [7, 11], [0, 4], [0, 4]]
## Half width and length (metres) of the corridor kept free of buildings for every hole slot.
const CORRIDOR_HALF_M: float = 8.0
const CORRIDOR_LENGTH_M: float = 61.0
## Longest hole length of HOLE_DESIGNS (yards). The nature scatter keeps this much of every corridor clear.
const HOLE_LENGTH_YD: int = 66

## One design per hole slot, hole-local yards (tee at 0,0, green at 0,length). No two designs are alike on purpose:
## the course roll-up (rating spec 7) multiplies the score of a hole by 0.4 when it is a near copy of an earlier
## one, which is what held the old identical-hole course at rating 20 to 23 while each hole alone scored 42.
## Fields: length, half_width (fairway), green_r, trees [[x, y]], water [[x0, y0, x1, y1]], bunkers [[...]].
## Checked with tools/reference/rating (seed 0, slot k, calm): hole scores 49, 42, 47, 49, 46, 49, 49; courses of 3 to 7 holes roll up to 44 to 47.
const HOLE_DESIGNS: Array = [
	{"length": 65, "half_width": 6, "green_r": 6,
		"trees": [[-8, 1], [8, 1], [-8, 5], [8, 5], [-8, 9], [8, 9], [-8, 33], [8, 33], [-8, 37], [8, 37], [-8, 41], [8, 41]],
		"water": [[6, 34, 8, 43]],
		"bunkers": [[-8, 51, -4, 57]]},
	{"length": 66, "half_width": 7, "green_r": 6,
		"trees": [[-8, 12], [8, 12], [-8, 15], [8, 15], [-8, 18], [8, 18], [-8, 21], [8, 21], [-8, 23], [8, 23], [-8, 26], [8, 26], [-8, 29], [8, 29], [-8, 32], [8, 32], [-8, 34], [8, 34], [-8, 37], [8, 37], [-8, 40], [8, 40], [-8, 43], [8, 43], [-8, 45], [-8, 48], [-8, 51], [-8, 54]],
		"water": [[-8, 14, -7, 20]],
		"bunkers": [[5, 54, 8, 58], [4, 55, 7, 60]]},
	{"length": 63, "half_width": 6, "green_r": 5,
		"trees": [[-8, 11], [8, 11], [-8, 15], [8, 15], [-8, 19], [8, 19], [-8, 32], [8, 32], [-8, 36], [8, 36], [-8, 40], [8, 40], [-8, 43], [8, 43], [-8, 47], [8, 47], [-8, 51], [8, 51], [-8, 53], [-8, 57], [-8, 61]],
		"water": [[-8, 21, -7, 32]],
		"bunkers": [[-7, 44, -4, 49]]},
	{"length": 65, "half_width": 7, "green_r": 6,
		"trees": [[-8, 22], [8, 22], [-8, 25], [8, 25], [-8, 28], [8, 28], [-8, 31], [8, 31], [8, 44], [8, 47], [8, 50], [8, 53]],
		"water": [[-8, 31, -7, 38]],
		"bunkers": [[-8, 45, -4, 48]]},
	{"length": 64, "half_width": 7, "green_r": 6,
		"trees": [[-8, 1], [8, 1], [-8, 4], [8, 4], [-8, 7], [8, 7], [-8, 11], [-8, 14], [-8, 17], [-8, 20], [-8, 43], [8, 43], [-8, 46], [8, 46], [-8, 49], [8, 49], [-8, 52], [8, 52]],
		"water": [[-8, 30, -8, 39]],
		"bunkers": [[-8, 44, -5, 47], [5, 50, 8, 55]]},
	{"length": 64, "half_width": 6, "green_r": 6,
		"trees": [[-8, 11], [-8, 15], [-8, 19], [-8, 22], [8, 22], [-8, 26], [8, 26], [-8, 30], [8, 30], [-8, 33], [8, 33], [-8, 37], [8, 37], [-8, 41], [8, 41]],
		"water": [[-8, 15, -6, 22]],
		"bunkers": [[3, 53, 7, 58], [3, 48, 6, 54]]},
	{"length": 63, "half_width": 7, "green_r": 6,
		"trees": [[-8, 1], [-8, 4], [-8, 7], [-8, 32], [8, 32], [-8, 35], [8, 35], [-8, 38], [8, 38], [-8, 41], [8, 41], [-8, 43], [8, 43], [-8, 46], [8, 46], [-8, 49], [8, 49]],
		"water": [[8, 15, 8, 21]],
		"bunkers": [[5, 55, 9, 61]]},
]


static func hole_slot_count() -> int:
	return HOLE_ORIGINS_DM.size()


## The rating-engine hole definition for hole slot `slot` (RHI v1, whole yards): fairway, then bunkers, water and
## trees from HOLE_DESIGNS[slot]. The slot id is the rating seed input, so it must equal the slot the hole is built in.
static func hole_template(slot: int) -> Dictionary:
	var d: Dictionary = HOLE_DESIGNS[clampi(slot, 0, HOLE_DESIGNS.size() - 1)] as Dictionary
	var length: int = int(d["length"])
	var half: int = int(d["half_width"])
	var feats: Array = [{"t": "fairway", "rect": [-half, 0, half, length]}]
	for r: Variant in (d["bunkers"] as Array):
		feats.append({"t": "bunker", "rect": _ints(r as Array)})
	for r2: Variant in (d["water"] as Array):
		feats.append({"t": "water", "rect": _ints(r2 as Array)})
	var trees: Array = []
	for t: Variant in (d["trees"] as Array):
		trees.append([int((t as Array)[0]), int((t as Array)[1])])
	if not trees.is_empty():
		feats.append({"t": "tree", "at": trees})
	return {"slot_id": slot, "tee": [0, 0], "green": [0, length, int(d["green_r"])], "features": feats}


static func _ints(a: Array) -> Array:
	var out: Array = []
	for v: Variant in a:
		out.append(int(v))
	return out


## Hole length in yards of the design for `slot`.
static func hole_length_yd(slot: int) -> int:
	return int((HOLE_DESIGNS[clampi(slot, 0, HOLE_DESIGNS.size() - 1)] as Dictionary)["length"])


## Corridor kept free of buildings for hole slot `slot`, in metres (x, z, width, depth).
static func corridor_rect_m(slot: int) -> Rect2:
	var o: Array = HOLE_ORIGINS_DM[clampi(slot, 0, HOLE_ORIGINS_DM.size() - 1)] as Array
	return Rect2(float(int(o[0])) * 0.1 - CORRIDOR_HALF_M, float(int(o[1])) * 0.1, CORRIDOR_HALF_M * 2.0, CORRIDOR_LENGTH_M)


## True when building cell `slot` (0..63) overlaps any hole corridor, built or not. Edge contact is not overlap.
static func cell_reserved(slot: int) -> bool:
	if slot < 0 or slot >= ANNEX_BASE:
		return false
	var c: Vector2 = slot_centre_m(slot)
	var cell: Rect2 = Rect2(c.x - CELL_M * 0.5, c.y - CELL_M * 0.5, CELL_M, CELL_M)
	for k: int in range(HOLE_ORIGINS_DM.size()):
		var r: Rect2 = corridor_rect_m(k)
		if cell.position.x < r.end.x and cell.end.x > r.position.x and cell.position.y < r.end.y and cell.end.y > r.position.y:
			return true
	return false


## Free (buildable) cells of a parcel, ascending cell order, as slot numbers.
static func free_cells(parcel: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for cell: int in range(CELLS_PER_PARCEL):
		var slot: int = parcel * CELLS_PER_PARCEL + cell
		if not cell_reserved(slot):
			out.append(slot)
	return out


## Parcels whose four cells are all under hole corridors (no building can stand there), ascending.
static func reserved_parcels() -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for p: int in range(PARCEL_COUNT):
		if free_cells(p).is_empty():
			out.append(p)
	return out


static func is_reserved(parcel: int) -> bool:
	return parcel >= 0 and parcel < PARCEL_COUNT and free_cells(parcel).is_empty()


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


## World x,z (metres) from an authoritative persisted origin in decimetres.
static func origin_point_m(origin_dm: Array, local_x_yd: int, local_y_yd: int) -> Vector2:
	return MHCourseSpatial.point_m(origin_dm, local_x_yd, local_y_yd)


static func hole_points_at_origin_m(def: Dictionary, origin_dm: Array) -> Dictionary:
	var points: Dictionary = MHCourseSpatial.hole_points_m(def, origin_dm)
	return {"tee": points["tee"], "green": points["green"], "green_radius_m": points["green_radius_m"]}


static func feature_rect_at_origin_m(origin_dm: Array, rect: Array) -> Rect2:
	return MHCourseSpatial.rect_m(origin_dm, rect)


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


## Footprint of a building at each tier as a share of the cell's usable width (CELL_M minus both margins):
## tier 1 about half a cell, tier 5 the whole cell, so growth is clearly visible and nothing is tiny.
const TIER_FOOTPRINT_SHARE: Array = [0.5, 0.62, 0.75, 0.88, 1.0]
## A very small mesh is never blown up by more than this.
const MAX_UPSCALE: float = 3.0


## Target footprint (metres, the longer side) of a building at `tier` (clamped 1..5).
static func footprint_target_m(tier: int) -> float:
	var share: float = float(TIER_FOOTPRINT_SHARE[clampi(tier, 1, TIER_FOOTPRINT_SHARE.size()) - 1])
	return (CELL_M - 2.0 * CELL_MARGIN_M) * share


## Uniform scale that makes a mesh whose footprint is size_x by size_z metres reach the tier's target footprint.
static func tier_scale(size_x: float, size_z: float, tier: int) -> float:
	var big: float = maxf(size_x, size_z)
	if big <= 0.0001:
		return 1.0
	return minf(MAX_UPSCALE, footprint_target_m(tier) / big)


## Placement of the mesh of `tier`: `bounds` is that tier's own AABB (MHBuildingMeshes.bounds). The footprint
## centre of the bounds lands on the slot centre and the scale comes from tier_scale().
static func building_transform_tier(slot: int, bounds: AABB, tier: int) -> Transform3D:
	var s: float = tier_scale(bounds.size.x, bounds.size.z, tier)
	var c: Vector2 = slot_centre_m(slot)
	var cx: float = bounds.position.x + bounds.size.x * 0.5
	var cz: float = bounds.position.z + bounds.size.z * 0.5
	var basis: Basis = Basis.from_scale(Vector3(s, s, s))
	return Transform3D(basis, Vector3(c.x - cx * s, 0.0, c.y - cz * s))


# ---------------------------------------------------------------- land

## Order in which the slice buys land: the parcels that open hole sites first (7 and 11 for slots 3 and 4, then 4 and 0
## for slots 5 and 6), then the rest. The session's own recommended_next would pick the lowest golf id.
const LAND_ORDER: Array = [7, 11, 4, 0, 1, 2, 12, 13, 14, 3, 15]


## The parcel the Buy land button buys: the first of LAND_ORDER that is in `buyable` (the session's own list of parcels
## that touch owned land), else the lowest buyable id, else -1.
static func next_land_parcel(buyable: PackedInt32Array) -> int:
	for p: Variant in LAND_ORDER:
		if buyable.has(int(p)):
			return int(p)
	if buyable.size() > 0:
		return buyable[0]
	return -1


# ---------------------------------------------------------------- slot assignment

## Free slot for `building_id` given owned parcels and already used slots, or -1 when even the annex is full.
static func pick_slot(building_id: String, owned: PackedInt32Array, used: Dictionary) -> int:
	var prefs: Array = PREFERENCE.get(building_id, []) as Array
	for p: Variant in prefs:
		var parcel: int = int(p)
		if not owned.has(parcel):
			continue
		for slot: int in free_cells(parcel):
			if not used.has(slot):
				return slot
	for k: int in range(ANNEX_SLOTS):
		if not used.has(ANNEX_BASE + k):
			return ANNEX_BASE + k
	return -1


## Slots for every building with tier > 0. `tiers` maps building id to owned tier (MHGameSession.tiers()).
## `previous` is the last result: a previous slot is kept while it is still valid (its parcel is owned and its cell
## is not under a hole corridor, or it is an annex slot) and not claimed by an earlier building. Others get pick_slot in ORDER.
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
	return parcel >= 0 and owned.has(parcel) and not cell_reserved(slot)
