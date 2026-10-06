extends GdUnitTestSuite
## MHSliceRound: cosmetic golfer timeline. Pure functions of seconds. NOT YET RUN in Godot.

const LEN: float = 60.0


func test_times_are_ordered_for_every_member() -> void:
	for size: int in range(1, 5):
		for member: int in range(size):
			var k: Dictionary = MHSliceRound.times(member, size, LEN)
			assert_float(float(k["swing_start"])).is_greater_equal(0.0)
			assert_float(float(k["swing_end"])).is_greater(float(k["swing_start"]))
			assert_float(float(k["walk_start"])).is_greater_equal(float(k["swing_end"]) - 0.0001)
			assert_float(float(k["walk_end"])).is_greater(float(k["walk_start"]))
			assert_float(float(k["putt_start"])).is_greater_equal(float(k["walk_end"]) - 0.0001)
			assert_float(float(k["putt_end"])).is_greater(float(k["putt_start"]))
			assert_float(float(k["exit_end"])).is_greater(float(k["putt_end"]))
			assert_float(float(k["impact"])).is_equal_approx(float(k["swing_start"]) + MHGolferPoses.IMPACT_SWING, 0.0001)


func test_everyone_swings_before_anyone_walks() -> void:
	var size: int = 4
	var last_swing_end: float = float(MHSliceRound.times(size - 1, size, LEN)["swing_end"])
	for member: int in range(size):
		assert_float(float(MHSliceRound.times(member, size, LEN)["walk_start"])).is_greater_equal(last_swing_end - 0.0001)


func test_first_member_swings_at_once_and_the_second_waits() -> void:
	var s0: Dictionary = MHSliceRound.state(0.0, 0, 3, LEN)
	assert_int(int(s0["phase"])).is_equal(MHSliceRound.Phase.SWING)
	assert_str(str(s0["clip"])).is_equal("swing")
	assert_float(float(s0["clip_t"])).is_equal_approx(0.0, 0.0001)
	var s1: Dictionary = MHSliceRound.state(0.0, 1, 3, LEN)
	assert_int(int(s1["phase"])).is_equal(MHSliceRound.Phase.WAIT_TEE)
	assert_str(str(s1["clip"])).is_equal("idle")
	assert_float(float(s1["along"])).is_equal_approx(0.0, 0.0001)


func test_ball_is_in_the_air_only_after_impact() -> void:
	var impact: float = MHGolferPoses.IMPACT_SWING
	assert_float(float(MHSliceRound.state(impact - 0.05, 0, 3, LEN)["ball_u"])).is_equal(-1.0)
	assert_float(float(MHSliceRound.state(impact + MHSliceRound.FLIGHT_S * 0.5, 0, 3, LEN)["ball_u"])).is_equal_approx(0.5, 0.0001)
	assert_float(float(MHSliceRound.state(impact + MHSliceRound.FLIGHT_S + 0.05, 0, 3, LEN)["ball_u"])).is_equal(-1.0)


func test_walk_putt_exit_and_done() -> void:
	var k: Dictionary = MHSliceRound.times(0, 3, LEN)
	var w: Dictionary = MHSliceRound.state(float(k["walk_start"]) + 10.0, 0, 3, LEN)
	assert_int(int(w["phase"])).is_equal(MHSliceRound.Phase.WALK)
	assert_str(str(w["clip"])).is_equal("walk")
	assert_float(float(w["along"])).is_equal_approx(10.0 * MHSliceRound.WALK_SPEED_MPS, 0.0001)
	assert_bool(bool(w["aim"])).is_false()
	var p: Dictionary = MHSliceRound.state(float(k["putt_start"]) + 0.5, 0, 3, LEN)
	assert_int(int(p["phase"])).is_equal(MHSliceRound.Phase.PUTT)
	assert_str(str(p["clip"])).is_equal("putt")
	assert_float(float(p["along"])).is_equal_approx(LEN, 0.0001)
	assert_float(float(p["clip_t"])).is_equal_approx(0.5, 0.0001)
	var x: Dictionary = MHSliceRound.state(float(k["putt_end"]) + 2.0, 0, 3, LEN)
	assert_int(int(x["phase"])).is_equal(MHSliceRound.Phase.EXIT)
	assert_float(float(x["along"])).is_greater(LEN)
	var d: Dictionary = MHSliceRound.state(float(k["exit_end"]) + 0.1, 0, 3, LEN)
	assert_int(int(d["phase"])).is_equal(MHSliceRound.Phase.DONE)


func test_progress_along_the_hole_never_goes_backwards() -> void:
	for member: int in range(3):
		var prev: float = 0.0
		var t: float = 0.0
		var end: float = float(MHSliceRound.times(member, 3, LEN)["exit_end"])
		while t <= end:
			var along: float = float(MHSliceRound.state(t, member, 3, LEN)["along"])
			assert_float(along).is_greater_equal(prev - 0.0001)
			prev = along
			t += 0.25


func test_group_duration_is_the_last_member_exit() -> void:
	assert_float(MHSliceRound.group_duration(3, LEN)).is_equal_approx(float(MHSliceRound.times(2, 3, LEN)["exit_end"]), 0.0001)
	assert_float(MHSliceRound.group_duration(1, LEN)).is_equal_approx(float(MHSliceRound.times(0, 1, LEN)["exit_end"]), 0.0001)
	assert_float(MHSliceRound.group_duration(3, LEN)).is_greater(MHSliceRound.group_duration(1, LEN))


func test_facing_yaw_turns_the_right_local_axis_toward_the_hole() -> void:
	var dirs: Array = [Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.6, 0.8), Vector2(-0.8, -0.6)]
	for dv: Variant in dirs:
		var dir: Vector2 = dv
		var walk_yaw: float = MHSliceRound.facing_yaw(dir.x, dir.y, false)
		var fwd: Vector3 = Basis(Vector3.UP, walk_yaw) * Vector3(0.0, 0.0, 1.0)
		assert_float(fwd.x).is_equal_approx(dir.x, 0.0001)
		assert_float(fwd.z).is_equal_approx(dir.y, 0.0001)
		var aim_yaw: float = MHSliceRound.facing_yaw(dir.x, dir.y, true)
		var side: Vector3 = Basis(Vector3.UP, aim_yaw) * Vector3(1.0, 0.0, 0.0)
		assert_float(side.x).is_equal_approx(dir.x, 0.0001)
		assert_float(side.z).is_equal_approx(dir.y, 0.0001)


func test_group_members_spread_sideways_around_the_line() -> void:
	var tee: Vector2 = Vector2(10.0, 20.0)
	var dir: Vector2 = Vector2(0.0, 1.0)
	var mid: Vector2 = MHSliceRound.ground_point(tee, dir, 5.0, 1, 3)
	assert_float(mid.x).is_equal_approx(10.0, 0.0001)
	assert_float(mid.y).is_equal_approx(25.0, 0.0001)
	var a: Vector2 = MHSliceRound.ground_point(tee, dir, 5.0, 0, 3)
	var c: Vector2 = MHSliceRound.ground_point(tee, dir, 5.0, 2, 3)
	assert_float(a.x + c.x).is_equal_approx(20.0, 0.0001)
	assert_float(absf(a.x - c.x)).is_equal_approx(2.0 * MHSliceRound.LATERAL_SPACING_M, 0.0001)
	var solo: Vector2 = MHSliceRound.ground_point(tee, dir, 0.0, 0, 1)
	assert_float(solo.x).is_equal_approx(10.0, 0.0001)


func test_ball_flies_a_parabola_from_tee_to_green() -> void:
	var tee: Vector2 = Vector2(0.0, 0.0)
	var green: Vector2 = Vector2(0.0, 50.0)
	var start: Vector3 = MHSliceRound.ball_point(tee, green, 0.0)
	var top: Vector3 = MHSliceRound.ball_point(tee, green, 0.5)
	var end: Vector3 = MHSliceRound.ball_point(tee, green, 1.0)
	assert_float(start.z).is_equal_approx(0.0, 0.0001)
	assert_float(end.z).is_equal_approx(50.0, 0.0001)
	assert_float(top.z).is_equal_approx(25.0, 0.0001)
	assert_float(top.y).is_equal_approx(0.1 + MHSliceRound.BALL_APEX_M, 0.0001)
	assert_float(start.y).is_equal_approx(0.1, 0.0001)
	assert_float(end.y).is_equal_approx(0.1, 0.0001)


func test_golfer_renderer_uses_authoritative_shot_endpoints() -> void:
	var golfers: MHSliceGolfers = auto_free(MHSliceGolfers.new())
	add_child(golfers)
	golfers.setup(MHArtMaterials.vertex_color())
	var events: Array = [{"kind": "shot", "shot": 1, "x0": 1000, "y0": 2000, "x1": 2000, "y1": 4000,
		"z0": 0, "z1": 0, "penalty": 0, "tree": false}]
	golfers.spawn_group(7, 1, Vector2.ZERO, Vector2(100.0, 100.0), {"events": events})
	var address: Dictionary = golfers._authoritative_state(events, 0.2, 0, 1)
	assert_bool(bool(address["done"])).is_false()
	var address_world: Vector2 = address["world"] as Vector2
	assert_float(address_world.x).is_equal_approx(9.144, 0.001)
	assert_float(address_world.y).is_equal_approx(18.288, 0.001)
	var flight: Dictionary = golfers._authoritative_state(events,
		MHAIRoundTimeline.ADDRESS_S + MHAIRoundTimeline.SWING_S + 0.7, 0, 1)
	assert_float(float(flight["ball_u"])).is_greater(0.0)
	var ball_from: Vector2 = flight["ball_from"] as Vector2
	var ball_to: Vector2 = flight["ball_to"] as Vector2
	assert_float(ball_from.x).is_equal_approx(9.144, 0.001)
	assert_float(ball_from.y).is_equal_approx(18.288, 0.001)
	assert_float(ball_to.x).is_equal_approx(18.288, 0.001)
	assert_float(ball_to.y).is_equal_approx(36.576, 0.001)


func test_group_does_not_duplicate_one_authoritative_round_trace() -> void:
	var golfers: MHSliceGolfers = auto_free(MHSliceGolfers.new())
	add_child(golfers)
	golfers.setup(MHArtMaterials.vertex_color())
	var events: Array = [{"kind": "shot", "shot": 1, "x0": 0, "y0": 0, "x1": 1000, "y1": 1000,
		"z0": 0, "z1": 0, "penalty": 0, "tree": false}]
	golfers.spawn_group(10, 3, Vector2.ZERO, Vector2(30.0, 30.0), {"events": events})
	assert_int(golfers.golfer_count()).is_equal(3)
	assert_int(((golfers.golfers[0] as Dictionary)["events"] as Array).size()).is_equal(1)
	assert_int(((golfers.golfers[1] as Dictionary)["events"] as Array).size()).is_equal(0)
	assert_int(((golfers.golfers[2] as Dictionary)["events"] as Array).size()).is_equal(0)


func test_authoritative_party_keeps_distinct_round_traces_per_golfer() -> void:
	var golfers: MHSliceGolfers = auto_free(MHSliceGolfers.new())
	add_child(golfers)
	golfers.setup(MHArtMaterials.vertex_color())
	var a_events: Array = [{"kind": "shot", "shot": 1, "x0": 0, "y0": 0, "x1": 1000, "y1": 1000}]
	var b_events: Array = [{"kind": "shot", "shot": 1, "x0": 0, "y0": 0, "x1": 2000, "y1": 3000}]
	golfers.spawn_authoritative_party([
		{"serial": 1, "party_id": 1, "round": {"events": a_events}},
		{"serial": 2, "party_id": 1, "round": {"events": b_events}},
	], Vector2.ZERO, Vector2(30.0, 30.0))
	assert_int(golfers.golfer_count()).is_equal(2)
	assert_int(int((((golfers.golfers[0] as Dictionary)["events"] as Array)[0] as Dictionary)["x1"])).is_equal(1000)
	assert_int(int((((golfers.golfers[1] as Dictionary)["events"] as Array)[0] as Dictionary)["x1"])).is_equal(2000)


func test_authoritative_party_preserves_hole_world_origin() -> void:
	var golfers: MHSliceGolfers = auto_free(MHSliceGolfers.new())
	add_child(golfers)
	golfers.setup(MHArtMaterials.vertex_color())
	golfers.spawn_authoritative_party([{"serial": 1, "party_id": 1, "round": {"events": []}}],
		Vector2(19.144, 38.288), Vector2(28.288, 56.576), Vector2(10.0, 20.0))
	var origin: Vector2 = (golfers.golfers[0] as Dictionary)["world_origin"] as Vector2
	assert_float(origin.x).is_equal_approx(10.0, 0.0001)
	assert_float(origin.y).is_equal_approx(20.0, 0.0001)


func test_authoritative_party_visual_can_be_replaced_between_holes() -> void:
	var golfers: MHSliceGolfers = auto_free(MHSliceGolfers.new())
	add_child(golfers)
	golfers.setup(MHArtMaterials.vertex_color())
	var customer: Dictionary = {"serial": 30, "party_id": 9, "round": {"events": []}}
	golfers.spawn_authoritative_party([customer], Vector2.ZERO, Vector2(0, 10))
	assert_int(golfers.golfer_count()).is_equal(1)
	golfers.remove_group(9)
	assert_int(golfers.golfer_count()).is_equal(0)
	golfers.spawn_authoritative_party([customer], Vector2(20, 20), Vector2(20, 40))
	assert_int(golfers.golfer_count()).is_equal(1)
