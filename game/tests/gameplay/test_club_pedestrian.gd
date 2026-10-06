extends GdUnitTestSuite

func test_ground_height_interpolates_between_samples() -> void:
	var grid: MHHeightGrid = MHHeightGrid.new(1, 1, 1000)
	grid.set_h(0, 0, 0)
	grid.set_h(1, 0, 1000)
	grid.set_h(0, 1, 1000)
	grid.set_h(1, 1, 2000)
	var p: Vector3 = MHClubPedestrian.apply_ground_height(Vector3(0.5, 99.0, 0.5), grid)
	assert_float(p.y).is_equal_approx(1.0, 0.001)


func test_advance_remains_grounded_on_sloped_terrain() -> void:
	var grid: MHHeightGrid = MHHeightGrid.new(2, 1, 1000)
	grid.set_h(0, 0, 0)
	grid.set_h(1, 0, 1000)
	grid.set_h(2, 0, 2000)
	grid.set_h(0, 1, 0)
	grid.set_h(1, 1, 1000)
	grid.set_h(2, 1, 2000)
	var route: Array = [Vector3(0, 0, 0), Vector3(2, 0, 0)]
	var step: Dictionary = MHClubPedestrian.advance(route, 1, Vector3(0, 0, 0), 0.5, grid)
	assert_float((step["position"] as Vector3).y).is_equal_approx(1.0, 0.001)


func test_route_detours_around_blocking_obstacle() -> void:
	var start: Vector3 = Vector3(0, 0, 0)
	var destination: Vector3 = Vector3(10, 0, 0)
	var obstacles: Array = [{"center": Vector2(5, 0), "radius": 1.5}]
	var points: Array = MHClubPedestrian.route_avoiding(start, destination, 2, obstacles)
	assert_int(points.size()).is_equal(3)
	var detour: Vector3 = points[1] as Vector3
	assert_bool(absf(detour.z) > 1.5).is_true()
	assert_bool((points[2] as Vector3).is_equal_approx(destination)).is_true()


func test_nonblocking_obstacle_keeps_normal_route() -> void:
	var start: Vector3 = Vector3(0, 0, 0)
	var destination: Vector3 = Vector3(10, 0, 0)
	var normal: Array = MHClubPedestrian.route(start, destination, 4)
	var routed: Array = MHClubPedestrian.route_avoiding(start, destination, 4, [{"center": Vector2(5, 8), "radius": 1.0}])
	assert_int(routed.size()).is_equal(normal.size())
	assert_bool((routed[1] as Vector3).is_equal_approx(normal[1] as Vector3)).is_true()
