extends GdUnitTestSuite
## Course props: budgets, determinism, variety, LOD order, size sanity. NOT YET RUN in Godot.

const VARIANT_SAMPLES: Array = [0, 1, 2, 3, 9, 1023]


func test_every_kind_has_budget_and_height() -> void:
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		assert_bool(MHPropMeshes.is_known(kind)).is_true()
		assert_int((MHPropMeshes.BUDGETS[kind] as Array).size()).is_equal(MHPropMeshes.LOD_COUNT)
		assert_bool(MHPropMeshes.HEIGHTS.has(kind)).override_failure_message(kind).is_true()
	assert_int(MHPropMeshes.BUDGETS.size()).is_equal(MHPropMeshes.KINDS.size())
	assert_int(MHPropMeshes.HEIGHTS.size()).is_equal(MHPropMeshes.KINDS.size())
	assert_bool(MHPropMeshes.is_known("pine")).is_false()


func test_triangle_counts_stay_inside_budget() -> void:
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		for lod in range(MHPropMeshes.LOD_COUNT):
			for v: Variant in VARIANT_SAMPLES:
				var tris: int = MHPropMeshes.build_builder(kind, lod, int(v)).tri_count()
				var msg: String = "%s lod %d v%d: %d tris, budget %d" % [kind, lod, int(v), tris, MHPropMeshes.budget(kind, lod)]
				assert_bool(tris > 0 and tris <= MHPropMeshes.budget(kind, lod)).override_failure_message(msg).is_true()


func test_far_lod_is_cheaper_than_near() -> void:
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		for v in range(MHPropMeshes.VARIANTS):
			var t0: int = MHPropMeshes.build_builder(kind, 0, v).tri_count()
			var t1: int = MHPropMeshes.build_builder(kind, 1, v).tri_count()
			assert_bool(t0 > t1).override_failure_message("%s v%d: %d vs %d" % [kind, v, t0, t1]).is_true()


func test_same_inputs_give_identical_geometry() -> void:
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		for lod in range(MHPropMeshes.LOD_COUNT):
			for v in range(MHPropMeshes.VARIANTS):
				assert_int(MHPropMeshes.build_builder(kind, lod, v).geometry_hash()).is_equal(
					MHPropMeshes.build_builder(kind, lod, v).geometry_hash())


func test_variants_differ_and_wrap() -> void:
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		var seen: Dictionary = {}
		for v in range(MHPropMeshes.VARIANTS):
			seen[MHPropMeshes.build_builder(kind, 0, v).geometry_hash()] = true
		assert_int(seen.size()).override_failure_message("no variety: " + kind).is_equal(MHPropMeshes.VARIANTS)
		assert_int(MHPropMeshes.build_builder(kind, 0, 1023).geometry_hash()).is_equal(
			MHPropMeshes.build_builder(kind, 0, -1).geometry_hash())


func test_lod_is_clamped_and_unknown_kind_is_empty() -> void:
	assert_int(MHPropMeshes.build_builder("bench", 1, 0).geometry_hash()).is_equal(MHPropMeshes.build_builder("bench", 7, 0).geometry_hash())
	assert_int(MHPropMeshes.build_builder("bench", 0, 0).geometry_hash()).is_equal(MHPropMeshes.build_builder("bench", -2, 0).geometry_hash())
	assert_int(MHPropMeshes.build("nope", 0, 0).get_surface_count()).is_equal(0)


func test_sizes_are_plausible() -> void:
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		var h: float = MHPropMeshes.height_of(kind)
		for lod in range(MHPropMeshes.LOD_COUNT):
			for v in range(MHPropMeshes.VARIANTS):
				var box: AABB = MHPropMeshes.build(kind, lod, v).get_aabb()
				var msg: String = "%s lod %d v%d: top %.3f of %.3f, bottom %.3f" % [kind, lod, v, box.end.y, h, box.position.y]
				assert_bool(box.end.y >= 0.5 * h and box.end.y <= 1.3 * h).override_failure_message(msg).is_true()
				assert_bool(box.position.y >= -0.01 and box.position.y <= 0.03).override_failure_message(msg).is_true()


func test_cart_dimensions_and_front() -> void:
	var box: AABB = MHPropMeshes.build("cart", 0, 0).get_aabb()
	assert_float(box.size.z).is_between(2.2, 2.6)
	assert_float(box.size.x).is_between(1.1, 1.6)


func test_fence_section_spans_exactly_its_length_along_x() -> void:
	for v in range(MHPropMeshes.VARIANTS):
		var box: AABB = MHPropMeshes.build("fence", 0, v).get_aabb()
		assert_float(box.position.x).is_between(-0.13, 0.0)
		assert_float(box.end.x).is_between(MHPropMeshes.FENCE_LENGTH, MHPropMeshes.FENCE_LENGTH + 0.13)


func test_sign_label_area_sits_on_the_board_face() -> void:
	var box: AABB = MHPropMeshes.build("sign", 0, 0).get_aabb()
	assert_float(MHPropMeshes.SIGN_FACE_CENTER.z).is_greater(0.02)
	assert_float(box.end.z).is_greater_equal(MHPropMeshes.SIGN_FACE_CENTER.z - 0.0001)
	assert_float(MHPropMeshes.SIGN_FACE_CENTER.y + MHPropMeshes.SIGN_FACE_SIZE.y * 0.5).is_less(box.end.y)


func test_flag_variants_use_distinct_flag_colours() -> void:
	var seen: Dictionary = {}
	for v in range(MHPropMeshes.VARIANTS):
		var b: MHMeshBuilder = MHPropMeshes.build_builder("flag", 0, v)
		seen[(b.colors[b.colors.size() - 1] as Color).to_html(false)] = true
	assert_int(seen.size()).is_equal(MHPropMeshes.VARIANTS)


func test_vertices_and_normals_are_valid() -> void:
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		var b: MHMeshBuilder = MHPropMeshes.build_builder(kind, 0, 1)
		for i in range(b.verts.size()):
			var p: Vector3 = b.verts[i]
			assert_bool(is_finite(p.x) and is_finite(p.y) and is_finite(p.z)).is_true()
			assert_float(b.normals[i].length()).is_equal_approx(1.0, 0.001)


func test_print_hashes_for_golden_values() -> void:
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		var b: MHMeshBuilder = MHPropMeshes.build_builder(kind, 0, 0)
		print("ART_HASH prop %s lod0 v0 tris=%d hash=%d" % [kind, b.tri_count(), b.geometry_hash()])
	for seed_value in range(1, 4):
		var look: MHGolferLook = MHGolferLook.from_seed(seed_value)
		var g: MHMeshBuilder = MHGolferMeshes.build_posed_builder(look, 0, MHGolferPoses.sample("swing", 0.0))
		print("ART_HASH golfer seed %d lod0 swing_address tris=%d hash=%d" % [seed_value, g.tri_count(), g.geometry_hash()])
	assert_bool(true).is_true()
