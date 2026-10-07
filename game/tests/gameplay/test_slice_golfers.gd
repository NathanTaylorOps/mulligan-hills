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

func test_staggered_members_advance_with_small_frame_steps() -> void:
	var g: MHSliceGolfers = MHSliceGolfers.new()
	var route: Array = [
		{"tee": Vector2(0, 0), "green": Vector2(0, 10)},
		{"tee": Vector2(20, 0), "green": Vector2(20, 12)},
		{"tee": Vector2(40, 0), "green": Vector2(40, 14)},
	]
	g.spawn_course_group(11, 4, route)
	var completed: Array = []
	# Real frames finish staggered members on different calls. Run well beyond the
	# theoretical route duration without ever using a giant one-frame jump.
	for frame: int in range(2400):
		g.advance(0.1, Vector3.ZERO)
		completed.append_array(g.drain_completed_groups())
		if not completed.is_empty():
			break
	assert_int(completed.size()).is_equal(1)
	assert_int(int((completed[0] as Dictionary)["serial"])).is_equal(11)
	assert_int(int((completed[0] as Dictionary)["holes"])).is_equal(3)
	assert_int(g.golfer_count()).is_equal(0)
	assert_int(g.drain_completed_groups().size()).is_equal(0)

func test_two_groups_can_finish_staggered_without_cross_contamination() -> void:
	var g: MHSliceGolfers = MHSliceGolfers.new()
	var route_a: Array = [{"tee": Vector2(0, 0), "green": Vector2(0, 8)}]
	var route_b: Array = [{"tee": Vector2(30, 0), "green": Vector2(30, 18)}]
	g.spawn_course_group(21, 2, route_a)
	g.spawn_course_group(22, 4, route_b)
	var serials: Array = []
	for frame: int in range(1200):
		g.advance(0.1, Vector3.ZERO)
		for row: Variant in g.drain_completed_groups():
			serials.append(int((row as Dictionary)["serial"]))
		if serials.size() == 2:
			break
	serials.sort()
	assert_array(serials).is_equal([21, 22])
	assert_int(g.golfer_count()).is_equal(0)
