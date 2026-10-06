class_name MHClubPedestrian
extends RefCounted
## Presentation-only pedestrian routes. Destinations come from MHSliceLayout's authoritative building slots.

const WALK_MPS: float = 2.0
const ARRIVE_M: float = 0.35


static func building_positions(session: MHGameSession) -> Dictionary:
	var out: Dictionary = {}
	for instance_v: Variant in session.building_placements.keys():
		var placement: Dictionary = session.building_placements[instance_v] as Dictionary
		var building_id: String = str(placement.get("building_id", ""))
		if building_id.is_empty() or out.has(building_id):
			continue
		var p: Vector3 = session.building_position(building_id)
		if p != Vector3.INF:
			out[building_id] = p
	return out


static func route(start: Vector3, destination: Vector3, serial: int) -> Array:
	# One deterministic dog-leg reduces visual overlap while staying cheap and navmesh-free.
	var mid: Vector3 = (start + destination) * 0.5
	var side: float = float((posmod(serial, 5) - 2)) * 1.25
	var dir: Vector3 = destination - start
	var lateral: Vector3 = Vector3(-dir.z, 0.0, dir.x).normalized()
	mid += lateral * side
	return [start, mid, destination]


static func advance(route_points: Array, segment: int, position: Vector3, delta: float) -> Dictionary:
	if route_points.is_empty() or segment >= route_points.size():
		return {"done": true, "segment": segment, "position": position}
	var target: Vector3 = route_points[segment] as Vector3
	var d: Vector3 = target - position
	d.y = 0.0
	var step: float = WALK_MPS * maxf(delta, 0.0)
	if d.length() <= maxf(step, ARRIVE_M):
		var next: int = segment + 1
		return {"done": next >= route_points.size(), "segment": next, "position": target}
	return {"done": false, "segment": segment, "position": position + d.normalized() * step}
