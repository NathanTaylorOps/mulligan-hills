class_name MHCourseSpatial
extends RefCounted
## Pure world-space projection for validated RHI hole geometry.
## slot_id is identity only; persisted origin_dm is the sole spatial authority.

const YARD_M: float = 0.9144

static func point_m(origin_dm: Array, x_yd: int, y_yd: int) -> Vector2:
	return Vector2(float(MHCourseLayout.world_mm(int(origin_dm[0]), x_yd * 100)) / 1000.0,
		float(MHCourseLayout.world_mm(int(origin_dm[1]), y_yd * 100)) / 1000.0)

static func hole_points_m(hole: Dictionary, origin_dm: Array) -> Dictionary:
	var tee: Array = hole["tee"] as Array
	var green: Array = hole["green"] as Array
	return {"slot_id": int(hole.get("slot_id", -1)),
		"tee": point_m(origin_dm, int(tee[0]), int(tee[1])),
		"green": point_m(origin_dm, int(green[0]), int(green[1])),
		"green_radius_m": float(int(green[2])) * YARD_M}

static func rect_m(origin_dm: Array, rect: Array) -> Rect2:
	var a: Vector2 = point_m(origin_dm, int(rect[0]), int(rect[1]))
	var b: Vector2 = point_m(origin_dm, int(rect[2]), int(rect[3]))
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)),
		Vector2(absf(b.x - a.x), absf(b.y - a.y)))

static func course_points_m(holes: Array, origins_dm: Array) -> Array:
	var out: Array = []
	if holes.size() != origins_dm.size():
		return out
	for i: int in range(holes.size()):
		out.append(hole_points_m(holes[i] as Dictionary, origins_dm[i] as Array))
	return out
