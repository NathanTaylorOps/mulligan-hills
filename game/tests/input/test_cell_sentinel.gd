extends GdUnitTestSuite
## Sentinel translation between MHPicking.MISS and MHStrokeBridge.NO_CELL. NOT YET RUN.


func test_sentinels_differ() -> void:
	assert_bool(MHPicking.MISS == MHStrokeBridge.NO_CELL).is_false()


func test_miss_becomes_no_cell() -> void:
	assert_bool(MHCellSentinel.from_pick(MHPicking.MISS) == MHStrokeBridge.NO_CELL).is_true()
	assert_bool(MHCellSentinel.is_no_cell(MHCellSentinel.from_pick(MHPicking.MISS))).is_true()


func test_real_cells_pass_through() -> void:
	assert_bool(MHCellSentinel.from_pick(Vector2i(0, 0)) == Vector2i(0, 0)).is_true()
	assert_bool(MHCellSentinel.from_pick(Vector2i(600, 400)) == Vector2i(600, 400)).is_true()
	assert_bool(MHCellSentinel.from_pick(Vector2i(-1, 0)) == Vector2i(-1, 0)).is_true()
	assert_bool(MHCellSentinel.from_pick(Vector2i(0, -1)) == Vector2i(0, -1)).is_true()


func test_no_cell_is_idempotent() -> void:
	assert_bool(MHCellSentinel.from_pick(MHStrokeBridge.NO_CELL) == MHStrokeBridge.NO_CELL).is_true()


func test_ground_hit_null_is_no_cell() -> void:
	assert_bool(MHCellSentinel.from_ground_hit(null) == MHStrokeBridge.NO_CELL).is_true()


func test_ground_hit_floors_to_cell() -> void:
	assert_bool(MHCellSentinel.from_ground_hit(Vector3(3.7, 0.0, 9.2)) == Vector2i(3, 9)).is_true()
	assert_bool(MHCellSentinel.from_ground_hit(Vector3(-0.5, 0.0, -2.1)) == Vector2i(-1, -3)).is_true()


func test_pick_terrain_miss_upward_ray() -> void:
	var g: MHHeightGrid = MHHeightGrid.new(64, 64)
	var c: Vector2i = MHCellSentinel.pick_terrain(g, Vector3(20, 5, 20), Vector3(0, 1, 0), 200.0)
	assert_bool(c == MHStrokeBridge.NO_CELL).is_true()


func test_pick_terrain_hit_downward_ray() -> void:
	var g: MHHeightGrid = MHHeightGrid.new(64, 64)
	var c: Vector2i = MHCellSentinel.pick_terrain(g, Vector3(20.2, 50.0, 30.4), Vector3(0, -1, 0))
	assert_bool(c == Vector2i(20, 30)).is_true()


func _miss_via_pick(_p: Vector2) -> Vector2i:
	return MHCellSentinel.from_pick(MHPicking.MISS)


func _miss_raw(_p: Vector2) -> Vector2i:
	return MHPicking.MISS


func test_bridge_skips_translated_miss() -> void:
	var machine: MHGestureStateMachine = MHGestureStateMachine.new()
	var sink: MHMockStrokeSink = MHMockStrokeSink.new()
	var bridge: MHStrokeBridge = MHStrokeBridge.new(sink, Callable(self, "_miss_via_pick"), machine)
	machine.stroke_started.emit(Vector2(10, 10))
	machine.stroke_moved.emit(Vector2(12, 12))
	machine.stroke_ended.emit()
	assert_int(sink.calls.size()).is_equal(2)
	assert_str(sink.calls[0]).is_equal("begin")
	assert_str(sink.calls[1]).is_equal("end")
	assert_object(bridge).is_not_null()


func test_bridge_with_raw_miss_would_dab_minus_one() -> void:
	# Documents the bug this helper fixes: an untranslated MISS reaches the sink as (-1,-1).
	var machine: MHGestureStateMachine = MHGestureStateMachine.new()
	var sink: MHMockStrokeSink = MHMockStrokeSink.new()
	var bridge: MHStrokeBridge = MHStrokeBridge.new(sink, Callable(self, "_miss_raw"), machine)
	machine.stroke_started.emit(Vector2(10, 10))
	assert_bool(sink.calls.has("apply(-1,-1)")).is_true()
	assert_object(bridge).is_not_null()
