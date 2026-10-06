class_name MHCartRoute
extends RefCounted
## Cheap presentation routing: stage at clubhouse, prefer painted cart path samples, then cross to the ball.
## It never returns a waypoint on a green or in water.

static func clubhouse_spawn(session: MHGameSession) -> Vector3:
	var ids: Array = MHClubPedestrian.instance_ids_for_type(session, "clubhouse")
	if ids.is_empty():
		return Vector3.INF
	var p: Vector3 = session.building_instance_position(str(ids[0]))
	if p == Vector3.INF:
		return p
	return p + Vector3(4.0, 0.0, 2.5)

static func route_to_ball(start: Vector3, ball: Vector3, serial: int, splat: MHSplatMap, grid: MHHeightGrid) -> Array:
	var points: Array = [MHClubPedestrian.apply_ground_height(start, grid)]
	var delta: Vector3 = ball - start
	delta.y = 0.0
	var distance: float = delta.length()
	if distance < 0.5:
		return points
	var steps: int = clampi(ceili(distance / 4.0), 2, 96)
	var last_path: Vector3 = Vector3.INF
	for i: int in range(1, steps):
		var p: Vector3 = start.lerp(ball, float(i) / float(steps))
		p = MHClubPedestrian.apply_ground_height(p, grid)
		if MHCartSurfacePolicy.is_path(splat, p, grid) and MHCartSurfacePolicy.ai_can_drive(splat, p, grid):
			last_path = p
			if points[-1].distance_to(p) >= 3.0:
				points.append(p)
	if last_path != Vector3.INF and points[-1] != last_path:
		points.append(last_path)
	var approach: Vector3 = ball
	if MHCartSurfacePolicy.is_green(splat, approach, grid) or MHCartSurfacePolicy.is_water(splat, approach, grid):
		# Stop short rather than ever routing an AI cart onto protected/hazard terrain.
		var back: Vector3 = (start - ball).normalized()
		approach = ball + back * 5.0
		approach = MHClubPedestrian.apply_ground_height(approach, grid)
	if MHCartSurfacePolicy.ai_can_drive(splat, approach, grid):
		points.append(approach)
	return points
