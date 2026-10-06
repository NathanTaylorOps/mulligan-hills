class_name MHClubPedestrian
extends RefCounted
## Presentation-only pedestrian routes. Destinations come from MHSliceLayout's authoritative building slots.

const WALK_MPS: float = 2.0
const ARRIVE_M: float = 0.35


static func building_positions(session: MHGameSession) -> Dictionary:
	# Permanent instance identity is the routing key. Multiple restaurants/pro shops must remain distinct.
	var out: Dictionary = {}
	var ids: Array = session.building_placements.keys()
	ids.sort()
	for instance_v: Variant in ids:
		var instance_id: String = str(instance_v)
		var p: Vector3 = session.building_instance_position(instance_id)
		if p != Vector3.INF:
			out[instance_id] = p
	return out


static func instance_ids_for_type(session: MHGameSession, building_id: String) -> Array:
	var out: Array = []
	for id_v: Variant in session.building_placements.keys():
		var id: String = str(id_v)
		var placement: Dictionary = session.building_placements[id] as Dictionary
		if str(placement.get("building_id", "")) == building_id:
			out.append(id)
	out.sort()
	return out


static func route(start: Vector3, destination: Vector3, serial: int) -> Array:
	# One deterministic dog-leg reduces visual overlap while staying cheap and navmesh-free.
	var mid: Vector3 = (start + destination) * 0.5
	var side: float = float((posmod(serial, 5) - 2)) * 1.25
	var dir: Vector3 = destination - start
	var lateral: Vector3 = Vector3(-dir.z, 0.0, dir.x).normalized()
	mid += lateral * side
	return [start, mid, destination]



static func route_avoiding(start: Vector3, destination: Vector3, serial: int, obstacles: Array) -> Array:
	var direct: Array = route(start, destination, serial)
	for obstacle_v: Variant in obstacles:
		if typeof(obstacle_v) != TYPE_DICTIONARY:
			continue
		var obstacle: Dictionary = obstacle_v
		var center: Vector2 = obstacle.get("center", Vector2.ZERO) as Vector2
		var radius: float = maxf(0.0, float(obstacle.get("radius", 0.0)))
		if radius <= 0.0:
			continue
		var a: Vector2 = Vector2(start.x, start.z)
		var b: Vector2 = Vector2(destination.x, destination.z)
		var ab: Vector2 = b - a
		var t: float = 0.0 if ab.length_squared() < 0.0001 else clampf((center - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a + ab * t).distance_to(center) >= radius + 0.75:
			continue
		var lateral: Vector2 = Vector2(-ab.y, ab.x).normalized()
		if posmod(serial, 2) == 1:
			lateral = -lateral
		var detour2: Vector2 = center + lateral * (radius + 1.25)
		return [start, Vector3(detour2.x, start.y, detour2.y), destination]
	return direct


static func apply_ground_height(position: Vector3, grid: MHHeightGrid) -> Vector3:
	if grid == null:
		return position
	var world_x_mm: int = roundi(position.x * 1000.0)
	var world_y_mm: int = roundi(position.z * 1000.0)
	var max_x_mm: int = grid.cells_x * grid.cell_size_mm
	var max_y_mm: int = grid.cells_y * grid.cell_size_mm
	world_x_mm = clampi(world_x_mm, 0, max_x_mm)
	world_y_mm = clampi(world_y_mm, 0, max_y_mm)
	var x0: int = mini(grid.cells_x, world_x_mm / grid.cell_size_mm)
	var y0: int = mini(grid.cells_y, world_y_mm / grid.cell_size_mm)
	var x1: int = mini(grid.cells_x, x0 + 1)
	var y1: int = mini(grid.cells_y, y0 + 1)
	var fx: int = 0 if x0 == grid.cells_x else world_x_mm - x0 * grid.cell_size_mm
	var fy: int = 0 if y0 == grid.cells_y else world_y_mm - y0 * grid.cell_size_mm
	var h0: int = MHRMath.rdiv(grid.get_h(x0, y0) * (grid.cell_size_mm - fx) + grid.get_h(x1, y0) * fx, grid.cell_size_mm)
	var h1: int = MHRMath.rdiv(grid.get_h(x0, y1) * (grid.cell_size_mm - fx) + grid.get_h(x1, y1) * fx, grid.cell_size_mm)
	var h: int = MHRMath.rdiv(h0 * (grid.cell_size_mm - fy) + h1 * fy, grid.cell_size_mm)
	position.y = float(h) / 1000.0
	return position


static func advance(route_points: Array, segment: int, position: Vector3, delta: float, grid: MHHeightGrid = null) -> Dictionary:
	if route_points.is_empty() or segment >= route_points.size():
		return {"done": true, "segment": segment, "position": position}
	var target: Vector3 = route_points[segment] as Vector3
	var d: Vector3 = target - position
	d.y = 0.0
	var step: float = WALK_MPS * maxf(delta, 0.0)
	if d.length() <= maxf(step, ARRIVE_M):
		var next: int = segment + 1
		return {"done": next >= route_points.size(), "segment": next, "position": apply_ground_height(target, grid)}
	return {"done": false, "segment": segment, "position": apply_ground_height(position + d.normalized() * step, grid)}
