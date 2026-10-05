extends GdUnitTestSuite
## MHGolferFigure: joint tree, pose application, clip playback, impact and finish signals. Runs without a
## scene tree (advance() is driven by hand). NOT YET RUN in Godot.


func _make(lod: int, seed_value: int = 1) -> MHGolferFigure:
	var fig: MHGolferFigure = MHGolferFigure.new()
	auto_free(fig)
	fig.auto_advance = false
	fig.setup(MHGolferLook.from_seed(seed_value), lod, MHArtMaterials.vertex_color())
	return fig


func _mesh_nodes(fig: MHGolferFigure) -> int:
	return fig.find_children("*", "MeshInstance3D", true, false).size()


func test_setup_builds_every_joint_and_one_mesh_per_part() -> void:
	var near: MHGolferFigure = _make(0)
	assert_int(near.joint_count()).is_equal(MHGolferMeshes.JOINTS.size())
	assert_int(_mesh_nodes(near)).is_equal(MHGolferMeshes.JOINTS.size())
	for j: Variant in MHGolferMeshes.JOINTS:
		assert_bool(near.joint_node(str(j)) != null).override_failure_message(str(j)).is_true()
	assert_bool(near.joint_node("nope") == null).is_true()
	var far: MHGolferFigure = _make(2)
	assert_int(_mesh_nodes(far)).is_equal(MHGolferMeshes.JOINTS.size() - 1)


func test_setup_twice_replaces_the_tree() -> void:
	var fig: MHGolferFigure = _make(0)
	fig.setup(MHGolferLook.from_seed(2), 1, MHArtMaterials.vertex_color())
	assert_int(fig.joint_count()).is_equal(MHGolferMeshes.JOINTS.size())
	assert_int(fig.get_child_count()).is_equal(1)
	assert_int(_mesh_nodes(fig)).is_equal(MHGolferMeshes.JOINTS.size())


func test_figure_scale_follows_look_height() -> void:
	var look: MHGolferLook = MHGolferLook.new()
	look.height = 1.05
	var fig: MHGolferFigure = MHGolferFigure.new()
	auto_free(fig)
	fig.setup(look, 1, MHArtMaterials.vertex_color())
	assert_float(fig.scale.y).is_equal_approx(1.05, 0.0001)


func test_pose_application_matches_forward_kinematics() -> void:
	var fig: MHGolferFigure = _make(0)
	var pose: Dictionary = MHGolferPoses.sample(MHGolferPoses.CLIP_SWING, 1.0)
	fig.set_pose(pose)
	var expected: Dictionary = MHGolferMeshes.joint_transforms(pose)
	for j: Variant in MHGolferMeshes.JOINTS:
		var joint: String = str(j)
		var world: Transform3D = Transform3D.IDENTITY
		var node: Node3D = fig.joint_node(joint)
		while node != null and node != fig:
			world = node.transform * world
			node = node.get_parent() as Node3D
		var want: Vector3 = (expected[joint] as Transform3D).origin
		assert_float(world.origin.distance_to(want)).override_failure_message(joint).is_less(0.0001)


func test_play_starts_at_the_first_key() -> void:
	var fig: MHGolferFigure = _make(1)
	fig.play(MHGolferPoses.CLIP_WALK)
	assert_bool(fig.playing).is_true()
	assert_float(fig.time).is_equal(0.0)
	var hips: Node3D = fig.joint_node("hips")
	var want: Vector3 = MHGolferMeshes.local_origin("hips", MHGolferPoses.sample("walk", 0.0))
	assert_float(hips.position.distance_to(want)).is_less(0.0001)


func test_swing_fires_impact_once_and_then_finishes() -> void:
	var fig: MHGolferFigure = _make(1)
	var impacts: Array = []
	var finished: Array = []
	fig.impact.connect(func() -> void: impacts.append(1))
	fig.clip_finished.connect(func(c: String) -> void: finished.append(c))
	fig.play(MHGolferPoses.CLIP_SWING)
	fig.advance(MHGolferPoses.IMPACT_SWING - 0.05)
	assert_int(impacts.size()).is_equal(0)
	fig.advance(0.1)
	assert_int(impacts.size()).is_equal(1)
	fig.advance(0.2)
	assert_int(impacts.size()).is_equal(1)
	assert_int(finished.size()).is_equal(0)
	fig.advance(10.0)
	assert_int(finished.size()).is_equal(1)
	assert_str(str(finished[0])).is_equal("swing")
	assert_bool(fig.playing).is_false()
	assert_float(fig.time).is_equal_approx(MHGolferPoses.LENGTH_SWING, 0.0001)
	fig.advance(1.0)
	assert_int(finished.size()).is_equal(1)


func test_replay_resets_impact() -> void:
	var fig: MHGolferFigure = _make(1)
	var impacts: Array = []
	fig.impact.connect(func() -> void: impacts.append(1))
	for i in range(2):
		fig.play(MHGolferPoses.CLIP_PUTT)
		fig.advance(MHGolferPoses.LENGTH_PUTT + 1.0)
	assert_int(impacts.size()).is_equal(2)


func test_looping_clip_wraps_and_keeps_playing() -> void:
	var fig: MHGolferFigure = _make(1)
	var finished: Array = []
	fig.clip_finished.connect(func(c: String) -> void: finished.append(c))
	fig.play(MHGolferPoses.CLIP_WALK)
	fig.advance(2.35)
	assert_bool(fig.playing).is_true()
	assert_float(fig.time).is_between(0.0, 1.0)
	assert_int(finished.size()).is_equal(0)


func test_speed_scales_playback_and_stop_freezes() -> void:
	var fig: MHGolferFigure = _make(1)
	fig.speed = 2.0
	fig.play(MHGolferPoses.CLIP_IDLE)
	fig.advance(0.5)
	assert_float(fig.time).is_equal_approx(1.0, 0.0001)
	fig.stop()
	fig.advance(0.5)
	assert_float(fig.time).is_equal_approx(1.0, 0.0001)


func test_play_without_restart_keeps_the_running_clip() -> void:
	var fig: MHGolferFigure = _make(1)
	fig.play(MHGolferPoses.CLIP_WALK)
	fig.advance(0.4)
	fig.play(MHGolferPoses.CLIP_WALK, false)
	assert_float(fig.time).is_equal_approx(0.4, 0.0001)
	fig.play(MHGolferPoses.CLIP_WALK, true)
	assert_float(fig.time).is_equal(0.0)
