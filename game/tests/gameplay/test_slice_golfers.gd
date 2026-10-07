extends GdUnitTestSuite
## Multi-hole visual golfer routing: completion is emitted once per group and never writes economy.

func test_group_advances_across_three_holes_and_completes_once() -> void:
	var g: MHSliceGolfers = MHSliceGolfers.new()
	var route: Array = [
		{"tee": Vector2(0, 0), "green": Vector2(0, 10)},
		{"tee": Vector2(20, 0), "green": Vector2(20, 12)},
		{"tee": Vector2(40, 0), "green": Vector2(40, 14)},
	]
	g.spawn_course_group(7, 3, route)
	assert_int(g.golfer_count()).is_equal(3)
	for hole: int in range(3):
		var len: float = (route[hole]["green"] as Vector2).distance_to(route[hole]["tee"] as Vector2)
		g.advance(MHSliceRound.group_duration(3, len) + 0.01, Vector3.ZERO)
		if hole < 2:
			assert_int(g.golfer_count()).is_equal(3)
			assert_int(g.drain_completed_groups().size()).is_equal(0)
	assert_int(g.golfer_count()).is_equal(0)
	var completed: Array = g.drain_completed_groups()
	assert_int(completed.size()).is_equal(1)
	assert_int(int((completed[0] as Dictionary)["serial"])).is_equal(7)
	assert_int(int((completed[0] as Dictionary)["size"])).is_equal(3)
	assert_int(int((completed[0] as Dictionary)["holes"])).is_equal(3)
	assert_int(g.drain_completed_groups().size()).is_equal(0)

func test_empty_route_does_not_spawn() -> void:
	var g: MHSliceGolfers = MHSliceGolfers.new()
	g.spawn_course_group(1, 4, [])
	assert_int(g.golfer_count()).is_equal(0)
	assert_int(g.drain_completed_groups().size()).is_equal(0)
