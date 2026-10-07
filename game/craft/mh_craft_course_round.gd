class_name MHCraftCourseRound
extends RefCounted
## Pure sequential tour over authored craft holes. Keeps the presentation loop independent
## from the authoritative economy/rating model while preserving stable hole slot identity.

var hole_defs: Array = []
var hole_index: int = 0
var elapsed_s: float = 0.0
var group_size: int = 1
var complete: bool = false

func setup(defs: Array, size: int) -> bool:
	if defs.is_empty():
		return false
	hole_defs = defs.duplicate(true)
	group_size = clampi(size, 1, 4)
	hole_index = 0
	elapsed_s = 0.0
	complete = false
	return true

func current_hole() -> Dictionary:
	return {} if complete or hole_index >= hole_defs.size() else hole_defs[hole_index] as Dictionary

func current_points_m() -> Dictionary:
	var h: Dictionary = current_hole()
	if h.is_empty():
		return {}
	var tee: Array = h["tee"] as Array
	var green: Array = h["green"] as Array
	const YARD_M: float = 0.9144
	return {"tee": Vector2(float(tee[0]) * YARD_M, float(tee[1]) * YARD_M),
		"green": Vector2(float(green[0]) * YARD_M, float(green[1]) * YARD_M)}

func current_length_m() -> float:
	var p: Dictionary = current_points_m()
	return 0.0 if p.is_empty() else (p["green"] as Vector2).distance_to(p["tee"] as Vector2)

## Advances visual time. Returns true exactly when the active hole changes or the tour completes.
func advance(delta_s: float) -> bool:
	if complete:
		return false
	elapsed_s += maxf(delta_s, 0.0)
	var duration: float = MHSliceRound.group_duration(group_size, current_length_m())
	if elapsed_s < duration:
		return false
	elapsed_s -= duration
	hole_index += 1
	if hole_index >= hole_defs.size():
		complete = true
		elapsed_s = 0.0
	return true

func progress_text() -> String:
	if complete:
		return "%d holes complete" % hole_defs.size()
	return "Hole %d of %d" % [hole_index + 1, hole_defs.size()]
