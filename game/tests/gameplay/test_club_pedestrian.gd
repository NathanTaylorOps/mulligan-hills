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
