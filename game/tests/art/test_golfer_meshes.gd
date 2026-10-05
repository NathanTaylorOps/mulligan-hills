extends GdUnitTestSuite
## Golfer meshes and kinematics: triangle budgets, determinism, colour variety, joint conventions.
## NOT YET RUN in Godot.

const LOOK_COUNT: int = 40


func test_budgets_are_descending_and_cover_every_lod() -> void:
	assert_int(MHGolferMeshes.BUDGETS.size()).is_equal(MHGolferMeshes.LOD_COUNT)
	assert_int(MHGolferMeshes.budget(0)).is_greater(MHGolferMeshes.budget(1))
	assert_int(MHGolferMeshes.budget(1)).is_greater(MHGolferMeshes.budget(2))
	assert_int(MHGolferMeshes.budget(99)).is_equal(MHGolferMeshes.budget(2))


func test_every_look_stays_inside_the_triangle_budget() -> void:
	for seed_value in range(1, LOOK_COUNT + 1):
		var look: MHGolferLook = MHGolferLook.from_seed(seed_value)
		for lod in range(MHGolferMeshes.LOD_COUNT):
			var tris: int = MHGolferMeshes.total_tri_count(look, lod)
			var msg: String = "seed %d lod %d: %d tris, budget %d" % [seed_value, lod, tris, MHGolferMeshes.budget(lod)]
			assert_bool(tris > 40 and tris <= MHGolferMeshes.budget(lod)).override_failure_message(msg).is_true()


func test_lods_get_cheaper() -> void:
	for seed_value in range(1, 11):
		var look: MHGolferLook = MHGolferLook.from_seed(seed_value)
		var t0: int = MHGolferMeshes.total_tri_count(look, 0)
		var t1: int = MHGolferMeshes.total_tri_count(look, 1)
		var t2: int = MHGolferMeshes.total_tri_count(look, 2)
		assert_bool(t0 > t1 and t1 > t2).override_failure_message("%d %d %d" % [t0, t1, t2]).is_true()


func test_posed_mesh_triangles_equal_the_sum_of_parts() -> void:
	var look: MHGolferLook = MHGolferLook.from_seed(3)
	for lod in range(MHGolferMeshes.LOD_COUNT):
		var sum: int = 0
		for j: Variant in MHGolferMeshes.JOINTS:
			sum += MHMeshBuilder.mesh_tri_count(MHGolferMeshes.build_part(look, str(j), lod))
		assert_int(sum).is_equal(MHGolferMeshes.total_tri_count(look, lod))


func test_far_lod_has_no_club_and_near_lods_have_every_part() -> void:
	var look: MHGolferLook = MHGolferLook.from_seed(5)
	for lod in range(2):
		for j: Variant in MHGolferMeshes.JOINTS:
			var m: ArrayMesh = MHGolferMeshes.build_part(look, str(j), lod)
			assert_int(m.get_surface_count()).override_failure_message("%s lod %d" % [str(j), lod]).is_equal(1)
	assert_int(MHGolferMeshes.build_part(look, "club", 2).get_surface_count()).is_equal(0)
	assert_int(MHGolferMeshes.build_part(look, "head", 2).get_surface_count()).is_equal(1)


func test_same_look_and_pose_give_identical_geometry() -> void:
	var pose: Dictionary = MHGolferPoses.sample(MHGolferPoses.CLIP_SWING, 0.9)
	for seed_value in range(1, 6):
		var a: int = MHGolferMeshes.build_posed_builder(MHGolferLook.from_seed(seed_value), 0, pose).geometry_hash()
		var b: int = MHGolferMeshes.build_posed_builder(MHGolferLook.from_seed(seed_value), 0, pose).geometry_hash()
		assert_int(a).is_equal(b)


func test_different_poses_and_looks_give_different_geometry() -> void:
	var look: MHGolferLook = MHGolferLook.from_seed(2)
	var rest: int = MHGolferMeshes.build_posed_builder(look, 0, {}).geometry_hash()
	var swing: int = MHGolferMeshes.build_posed_builder(look, 0, MHGolferPoses.sample("swing", 1.0)).geometry_hash()
	var other: int = MHGolferMeshes.build_posed_builder(MHGolferLook.from_seed(9), 0, {}).geometry_hash()
	assert_bool(rest != swing).is_true()
	assert_bool(rest != other).is_true()


func test_looks_are_deterministic_and_varied() -> void:
	assert_int(MHGolferLook.from_seed(7).key()).is_equal(MHGolferLook.from_seed(7).key())
	var keys: Dictionary = {}
	var skins: Dictionary = {}
	var styles: Dictionary = {}
	for seed_value in range(1, LOOK_COUNT + 1):
		var look: MHGolferLook = MHGolferLook.from_seed(seed_value)
		keys[look.key()] = true
		skins[look.skin.to_html(false)] = true
		styles[look.hair_style] = true
		assert_float(look.height).is_between(0.91, 1.09)
		assert_float(look.build).is_between(0.89, 1.16)
		assert_bool(look.hat != look.shirt).is_true()
	assert_int(keys.size()).is_greater(LOOK_COUNT - 6)
	assert_int(skins.size()).is_greater_equal(4)
	assert_int(styles.size()).is_equal(MHGolferLook.STYLE_COUNT)


func test_standing_golfer_has_realistic_height_and_stands_on_the_ground() -> void:
	# The idle pose is used because the rest pose lets the club hang below the ground.
	var idle: Dictionary = MHGolferPoses.sample(MHGolferPoses.CLIP_IDLE, 0.0)
	for seed_value in range(1, 11):
		var look: MHGolferLook = MHGolferLook.from_seed(seed_value)
		for lod in range(MHGolferMeshes.LOD_COUNT):
			var box: AABB = MHGolferMeshes.build_posed(look, lod, idle).get_aabb()
			var h: float = look.height
			var msg: String = "seed %d lod %d: y %.3f..%.3f" % [seed_value, lod, box.position.y, box.end.y]
			assert_bool(box.position.y >= -0.03 and box.position.y <= 0.06).override_failure_message(msg).is_true()
			assert_bool(box.end.y >= 1.6 * h and box.end.y <= 2.0 * h).override_failure_message(msg).is_true()
			assert_bool(box.size.x < 1.2 and box.size.z < 1.2).override_failure_message(msg).is_true()


func test_rest_pose_ankles_are_on_the_ground() -> void:
	assert_float(MHGolferMeshes.ankle_height({})).is_equal_approx(0.04, 0.001)
	var t: Dictionary = MHGolferMeshes.joint_transforms({})
	assert_int(t.size()).is_equal(MHGolferMeshes.JOINTS.size())
	var head: Vector3 = (t["head"] as Transform3D).origin
	assert_float(head.y).is_equal_approx(0.94 + 0.08 + 0.55, 0.001)


func test_every_joint_has_a_known_parent_listed_before_it() -> void:
	var seen: Dictionary = {}
	for j: Variant in MHGolferMeshes.JOINTS:
		var joint: String = str(j)
		var parent: String = str(MHGolferMeshes.PARENT[joint])
		assert_bool(parent == "" or seen.has(parent)).override_failure_message(joint).is_true()
		assert_bool(MHGolferMeshes.OFFSET.has(joint)).is_true()
		seen[joint] = true


func test_rotation_sign_conventions() -> void:
	# Facing +Z, left is +X. A hanging limb swings FORWARD (+Z) with negative X rotation.
	var fwd: Vector3 = MHGolferMeshes.rot(Vector3(-90.0, 0.0, 0.0)) * Vector3(0.0, -1.0, 0.0)
	assert_float(fwd.distance_to(Vector3(0.0, 0.0, 1.0))).is_less(0.001)
	# Positive Z moves a hanging limb toward +X (left side outward for the left arm).
	var out: Vector3 = MHGolferMeshes.rot(Vector3(0.0, 0.0, 90.0)) * Vector3(0.0, -1.0, 0.0)
	assert_float(out.distance_to(Vector3(1.0, 0.0, 0.0))).is_less(0.001)
	# Positive Y turns the front (+Z) toward the target (+X).
	var turn: Vector3 = MHGolferMeshes.rot(Vector3(0.0, 90.0, 0.0)) * Vector3(0.0, 0.0, 1.0)
	assert_float(turn.distance_to(Vector3(1.0, 0.0, 0.0))).is_less(0.001)
	# Positive X bends the spine forward (up becomes +Z).
	var bend: Vector3 = MHGolferMeshes.rot(Vector3(90.0, 0.0, 0.0)) * Vector3(0.0, 1.0, 0.0)
	assert_float(bend.distance_to(Vector3(0.0, 0.0, 1.0))).is_less(0.001)
	assert_bool(MHGolferMeshes.rot(Vector3.ZERO).is_equal_approx(Basis.IDENTITY)).is_true()


func test_club_scale_changes_only_the_club_length() -> void:
	var base: Dictionary = {"arm_r_lower": Vector3(-30.0, 0.0, 0.0)}
	var short: Dictionary = {"arm_r_lower": Vector3(-30.0, 0.0, 0.0), "club_scale": 0.5}
	var h0: Vector3 = MHGolferMeshes.club_head_position(base)
	var h1: Vector3 = MHGolferMeshes.club_head_position(short)
	var hand: Vector3 = (MHGolferMeshes.joint_transforms(base)["club"] as Transform3D).origin
	assert_float(h1.distance_to(hand)).is_less(h0.distance_to(hand))
	assert_float(h1.distance_to(hand)).is_equal_approx(h0.distance_to(hand) * 0.5, 0.05)


func test_hips_position_shifts_the_whole_body() -> void:
	var a: Dictionary = MHGolferMeshes.joint_transforms({})
	var b: Dictionary = MHGolferMeshes.joint_transforms({"hips_pos": Vector3(0.1, -0.05, 0.2)})
	for j: Variant in MHGolferMeshes.JOINTS:
		var d: Vector3 = (b[str(j)] as Transform3D).origin - (a[str(j)] as Transform3D).origin
		assert_float(d.distance_to(Vector3(0.1, -0.05, 0.2))).is_less(0.0001)
