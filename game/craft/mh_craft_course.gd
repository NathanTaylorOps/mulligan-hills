class_name MHCraftCourse
extends RefCounted
## Editable authoring state for a small course. The rated MHCourseLayout remains authoritative
## after finalization; this object preserves the richer tile/relief/mowing source drafts.

const VERSION: int = 1
const NIGHT_SLICE_HOLES: int = 3
const MAX_HOLES: int = 18

var holes: Array[MHCraftHole] = []
var active_index: int = 0

func _init(seed_first: bool = true) -> void:
	if seed_first:
		holes.append(default_hole(0))

func active() -> MHCraftHole:
	if holes.is_empty():
		return null
	active_index = clampi(active_index, 0, holes.size() - 1)
	return holes[active_index]

func count() -> int:
	return holes.size()

func select(index: int) -> bool:
	if index < 0 or index >= holes.size():
		return false
	active_index = index
	return true

func ensure_holes(wanted: int) -> void:
	var target: int = clampi(wanted, 1, MAX_HOLES)
	while holes.size() < target:
		holes.append(default_hole(holes.size()))

func to_dict() -> Dictionary:
	var rows: Array = []
	for hole: MHCraftHole in holes:
		rows.append(hole.to_dict())
	return {"v": VERSION, "active": active_index, "holes": rows}

static func from_dict(raw: Variant) -> MHCraftCourse:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw as Dictionary
	if int(d.get("v", -1)) != VERSION or typeof(d.get("holes", null)) != TYPE_ARRAY:
		return null
	var rows: Array = d["holes"] as Array
	if rows.is_empty() or rows.size() > MAX_HOLES:
		return null
	var out: MHCraftCourse = MHCraftCourse.new(false)
	for row: Variant in rows:
		var hole: MHCraftHole = MHCraftHole.from_dict(row)
		if hole == null:
			return null
		out.holes.append(hole)
	out.active_index = clampi(int(d.get("active", 0)), 0, out.holes.size() - 1)
	return out

static func from_legacy_hole(hole: MHCraftHole) -> MHCraftCourse:
	if hole == null:
		return null
	var out: MHCraftCourse = MHCraftCourse.new(false)
	out.holes.append(hole)
	return out

static func default_hole(index: int) -> MHCraftHole:
	var craft: MHCraftHole = MHCraftHole.new(24, 40)
	# Give each starter hole a distinct but editable routing so switching is obvious.
	var shift: int = [0, -3, 3][index % 3]
	var fair_x0: int = clampi(10 + shift, 2, 18)
	var fair_x1: int = fair_x0 + 3
	craft.paint_rect(fair_x0, 0, fair_x1, 29, MHCraftHole.Surface.FAIRWAY)
	var green_x0: int = clampi(fair_x0 - 1, 1, 17)
	craft.paint_rect(green_x0, 30, green_x0 + 5, 35, MHCraftHole.Surface.GREEN)
	craft.add_tee(fair_x0 + 1, 0)
	craft.add_pin(green_x0 + 2, 32)
	var mowing: MHMowingDesign = MHMowingDesign.new()
	mowing.direction_deg = (index * 15) % 180
	craft.mowing = mowing.to_dict()
	return craft

func valid_hole_defs(round_no: int = 0) -> Array:
	var defs: Array = []
	for i: int in range(holes.size()):
		var converted: Dictionary = MHCraftConvert.to_hole_def(holes[i], i, 0, round_no)
		if converted.is_empty():
			return []
		defs.append(converted)
	return defs
