class_name MHCartRoute
extends RefCounted
## Cheap presentation routing: stage at clubhouse, follow connected painted cart paths, then cross to the ball.
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
	var safe_ball: Vector3 = _safe_approach(ball, start, splat, grid)
	var path_points: Array = _path_search(start, safe_ball, splat, grid)
	if path_points.is_empty():
		return [MHClubPedestrian.apply_ground_height(start, grid), safe_ball]
	if (path_points[-1] as Vector3).distance_to(safe_ball) > 0.5:
		path_points.append(safe_ball)
	return path_points

static func _safe_approach(ball: Vector3, start: Vector3, splat: MHSplatMap, grid: MHHeightGrid) -> Vector3:
	var p: Vector3 = MHClubPedestrian.apply_ground_height(ball, grid)
	if MHCartSurfacePolicy.ai_can_drive(splat, p, grid):
		return p
	var back: Vector3 = start - ball
	back.y = 0.0
	if back.length_squared() < 0.01:
		back = Vector3.FORWARD
	return MHClubPedestrian.apply_ground_height(ball + back.normalized() * 5.0, grid)

static func _path_search(start: Vector3, goal: Vector3, splat: MHSplatMap, grid: MHHeightGrid) -> Array:
	var step: int = maxi(1, roundi(2000.0 / float(grid.cell_size_mm)))
	var first: Vector2i = _nearest_path(start, splat, grid, step)
	var last: Vector2i = _nearest_path(goal, splat, grid, step)
	if first.x < 0 or last.x < 0:
		return []
	var queue: Array = [first]
	var came: Dictionary = {first: first}
	var head: int = 0
	var dirs: Array = [Vector2i(step, 0), Vector2i(-step, 0), Vector2i(0, step), Vector2i(0, -step)]
	while head < queue.size() and queue.size() < 4096:
		var cur: Vector2i = queue[head]
		head += 1
		if cur.distance_squared_to(last) <= step * step:
			last = cur
			break
		for dv: Variant in dirs:
			var n: Vector2i = cur + (dv as Vector2i)
			if n.x < 0 or n.y < 0 or n.x >= splat.samples_x or n.y >= splat.samples_y or came.has(n):
				continue
			var wp: Vector3 = _cell_world(n, grid)
			if MHCartSurfacePolicy.is_path(splat, wp, grid) and MHCartSurfacePolicy.ai_can_drive(splat, wp, grid):
				came[n] = cur
				queue.append(n)
	if not came.has(last):
		return []
	var cells: Array = []
	var at: Vector2i = last
	while at != first:
		cells.push_front(at)
		at = came[at] as Vector2i
	cells.push_front(first)
	var out: Array = [MHClubPedestrian.apply_ground_height(start, grid)]
	for i: int in range(0, cells.size(), 2):
		out.append(MHClubPedestrian.apply_ground_height(_cell_world(cells[i] as Vector2i, grid), grid))
	return out

static func _nearest_path(world: Vector3, splat: MHSplatMap, grid: MHHeightGrid, step: int) -> Vector2i:
	var cx: int = clampi(roundi(world.x * 1000.0) / grid.cell_size_mm, 0, splat.samples_x - 1)
	var cy: int = clampi(roundi(world.z * 1000.0) / grid.cell_size_mm, 0, splat.samples_y - 1)
	for radius: int in range(0, 13, step):
		for y: int in range(maxi(0, cy - radius), mini(splat.samples_y - 1, cy + radius) + 1, step):
			for x: int in range(maxi(0, cx - radius), mini(splat.samples_x - 1, cx + radius) + 1, step):
				var cell: Vector2i = Vector2i(x, y)
				if MHCartSurfacePolicy.is_path(splat, _cell_world(cell, grid), grid):
					return cell
	return Vector2i(-1, -1)

static func _cell_world(cell: Vector2i, grid: MHHeightGrid) -> Vector3:
	return Vector3(float(cell.x * grid.cell_size_mm) / 1000.0, 0.0, float(cell.y * grid.cell_size_mm) / 1000.0)
