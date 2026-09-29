extends GdUnitTestSuite
## gdUnit4 tests for MHProceduralSwing. NOT YET RUN (no Godot in the authoring sandbox).
## Located in game/characters/tests/ because workstream G does not own game/tests/. The lead may move it.

const SKEL: NodePath = NodePath("Skeleton3D")


func test_expand_pose_mirrors_symmetric_keys() -> void:
	var full: Dictionary = MHProceduralSwing.expand_pose({"S:UpperArm": Vector3(-40.0, 5.0, -98.0)})
	assert_that(full["LeftUpperArm"]).is_equal(Vector3(-40.0, 5.0, -98.0))
	assert_that(full["RightUpperArm"]).is_equal(Vector3(-40.0, -5.0, 98.0))


func test_expand_pose_side_key_overrides_symmetric() -> void:
	var full: Dictionary = MHProceduralSwing.expand_pose({"S:UpperArm": Vector3(1.0, 2.0, 3.0), "R:UpperArm": Vector3(9.0, 9.0, 9.0)})
	assert_that(full["RightUpperArm"]).is_equal(Vector3(9.0, 9.0, 9.0))
	assert_that(full["LeftUpperArm"]).is_equal(Vector3(1.0, 2.0, 3.0))


func test_swap_sides_is_involution() -> void:
	var p: Dictionary = {"Hips": Vector3(1.0, 2.0, 3.0), "L:UpperLeg": Vector3(4.0, 5.0, 6.0), "S:LowerArm": Vector3(7.0, 8.0, 9.0)}
	var twice: Dictionary = MHProceduralSwing.swap_sides(MHProceduralSwing.swap_sides(p))
	assert_that(twice["Hips"]).is_equal(p["Hips"])
	assert_that(twice["L:UpperLeg"]).is_equal(p["L:UpperLeg"])
	assert_that(twice["S:LowerArm"]).is_equal(p["S:LowerArm"])


func test_library_has_expected_clips_and_lengths() -> void:
	var lib: AnimationLibrary = MHProceduralSwing.build_library(SKEL)
	for clip: StringName in [&"idle", &"address", &"walk", &"putt", &"swing_full"]:
		assert_bool(lib.has_animation(clip)).is_true()
	assert_float(lib.get_animation(&"swing_full").length).is_equal_approx(MHProceduralSwing.LENGTH_SWING_FULL, 0.0001)
	assert_int(lib.get_animation(&"walk").loop_mode).is_equal(Animation.LOOP_LINEAR)
	assert_int(lib.get_animation(&"swing_full").loop_mode).is_equal(Animation.LOOP_NONE)


func test_every_track_targets_the_skeleton_and_a_humanoid_bone() -> void:
	var lib: AnimationLibrary = MHProceduralSwing.build_library(SKEL)
	for clip: StringName in lib.get_animation_list():
		var anim: Animation = lib.get_animation(clip)
		assert_int(anim.get_track_count()).is_greater(0)
		for t: int in range(anim.get_track_count()):
			var path: String = str(anim.track_get_path(t))
			assert_bool(path.begins_with("Skeleton3D:")).is_true()
			var bone: String = path.substr("Skeleton3D:".length())
			assert_bool(MHGolferRig.HUMANOID_BONES.has(bone)).is_true()


func test_looping_clips_end_where_they_start() -> void:
	var lib: AnimationLibrary = MHProceduralSwing.build_library(SKEL)
	for clip: StringName in [&"idle", &"address", &"walk"]:
		var anim: Animation = lib.get_animation(clip)
		for t: int in range(anim.get_track_count()):
			var n: int = anim.track_get_key_count(t)
			var first: Variant = anim.track_get_key_value(t, 0)
			var last: Variant = anim.track_get_key_value(t, n - 1)
			assert_that(last).is_equal(first)


func test_impact_time_is_inside_clip() -> void:
	assert_float(MHProceduralSwing.IMPACT_TIME_SWING_FULL).is_less(MHProceduralSwing.LENGTH_SWING_FULL)
	assert_float(MHProceduralSwing.IMPACT_TIME_PUTT).is_less(MHProceduralSwing.LENGTH_PUTT)
