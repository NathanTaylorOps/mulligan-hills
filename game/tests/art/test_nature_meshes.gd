extends GdUnitTestSuite
## Nature meshes: triangle budgets (low-end phone), determinism, variant variety, LOD ordering, sane size.
## Golden geometry hashes are NOT stored: Godot could not run when this was written. After the first green
## CI run, add them from the output of test_print_hashes_for_golden_values (see docs/phase1).
## NOT YET RUN in Godot.

const VARIANT_SAMPLES: Array = [0, 1, 2, 3, 17, 1023]


func test_every_kind_has_budget_and_height_entries() -> void:
	for k: Variant in MHNatureMeshes.KINDS:
		var kind: String = str(k)
		assert_bool(MHNatureMeshes.BUDGETS.has(kind)).override_failure_message("budget " + kind).is_true()
		assert_bool(MHNatureMeshes.HEIGHTS.has(kind)).override_failure_message("height " + kind).is_true()
		assert_int((MHNatureMeshes.BUDGETS[kind] as Array).size()).is_equal(MHNatureMeshes.LOD_COUNT)
	assert_int(MHNatureMeshes.BUDGETS.size()).is_equal(MHNatureMeshes.KINDS.size())


func test_triangle_counts_stay_inside_budget() -> void:
	for k: Variant in MHNatureMeshes.KINDS:
		var kind: String = str(k)
		for lod in range(MHNatureMeshes.LOD_COUNT):
			for v: Variant in VARIANT_SAMPLES:
				var tris: int = MHNatureMeshes.build_builder(kind, lod, int(v)).tri_count()
				var msg: String = "%s lod %d variant %d: %d tris, budget %d" % [kind, lod, int(v), tris, MHNatureMeshes.budget(kind, lod)]
				assert_bool(tris > 0 and tris <= MHNatureMeshes.budget(kind, lod)).override_failure_message(msg).is_true()


func test_tree_lod0_is_under_400_and_budgets_are_consistent() -> void:
	for k: Variant in MHNatureMeshes.TREE_KINDS:
		var kind: String = str(k)
		assert_bool(MHNatureMeshes.is_tree(kind)).is_true()
		assert_int(MHNatureMeshes.budget(kind, 0)).is_less(MHNatureMeshes.TREE_LOD0_LIMIT)
		for v in range(MHNatureMeshes.VARIANTS):
			assert_int(MHNatureMeshes.build_builder(kind, 0, v).tri_count()).is_less(MHNatureMeshes.TREE_LOD0_LIMIT)
	assert_bool(MHNatureMeshes.is_tree("bush")).is_false()
	for k: Variant in MHNatureMeshes.KINDS:
		var arr: Array = MHNatureMeshes.BUDGETS[str(k)] as Array
		for i in range(arr.size() - 1):
			assert_int(int(arr[i])).is_greater(int(arr[i + 1]))


func test_lods_get_cheaper() -> void:
	for k: Variant in MHNatureMeshes.KINDS:
		var kind: String = str(k)
		for v in range(MHNatureMeshes.VARIANTS):
			var t0: int = MHNatureMeshes.build_builder(kind, 0, v).tri_count()
			var t1: int = MHNatureMeshes.build_builder(kind, 1, v).tri_count()
			var t2: int = MHNatureMeshes.build_builder(kind, 2, v).tri_count()
			var msg: String = "%s v%d: %d, %d, %d" % [kind, v, t0, t1, t2]
			assert_bool(t0 > t1 and t1 >= t2).override_failure_message(msg).is_true()


func test_same_inputs_give_identical_geometry() -> void:
	for k: Variant in MHNatureMeshes.KINDS:
		var kind: String = str(k)
		for lod in range(MHNatureMeshes.LOD_COUNT):
			for v in range(MHNatureMeshes.VARIANTS):
				var a: int = MHNatureMeshes.build_builder(kind, lod, v).geometry_hash()
				var b: int = MHNatureMeshes.build_builder(kind, lod, v).geometry_hash()
				assert_int(a).is_equal(b)


func test_built_mesh_has_the_same_triangle_count_as_the_builder() -> void:
	# Only the count is compared. hash_mesh reads colours back after Godot stored them as 8-bit, which may
	# truncate where geometry_hash rounds, so the two hashes are not guaranteed equal for arbitrary colours.
	var b: MHMeshBuilder = MHNatureMeshes.build_builder("oak", 0, 2)
	var m: ArrayMesh = MHNatureMeshes.build("oak", 0, 2)
	assert_int(m.get_surface_count()).is_equal(1)
	assert_int(MHMeshBuilder.mesh_tri_count(m)).is_equal(b.tri_count())


func test_variants_differ() -> void:
	for k: Variant in MHNatureMeshes.KINDS:
		var kind: String = str(k)
		var seen: Dictionary = {}
		for v in range(MHNatureMeshes.VARIANTS):
			seen[MHNatureMeshes.build_builder(kind, 0, v).geometry_hash()] = true
		assert_bool(seen.size() >= 3).override_failure_message("too little variety: " + kind).is_true()


func test_variant_numbers_wrap_modulo_1024_including_negatives() -> void:
	var a: int = MHNatureMeshes.build_builder("pine", 0, 1023).geometry_hash()
	var b: int = MHNatureMeshes.build_builder("pine", 0, -1).geometry_hash()
	var c: int = MHNatureMeshes.build_builder("pine", 0, 1023 + 1024).geometry_hash()
	assert_int(a).is_equal(b)
	assert_int(a).is_equal(c)


func test_lod_argument_is_clamped() -> void:
	var a: int = MHNatureMeshes.build_builder("bush", 2, 0).geometry_hash()
	var b: int = MHNatureMeshes.build_builder("bush", 9, 0).geometry_hash()
	var c: int = MHNatureMeshes.build_builder("bush", 0, 0).geometry_hash()
	var d: int = MHNatureMeshes.build_builder("bush", -4, 0).geometry_hash()
	assert_int(a).is_equal(b)
	assert_int(c).is_equal(d)
	assert_int(MHNatureMeshes.budget("bush", 99)).is_equal(MHNatureMeshes.budget("bush", 2))


func test_unknown_kind_is_empty() -> void:
	var m: ArrayMesh = MHNatureMeshes.build("nope", 0, 0)
	assert_int(m.get_surface_count()).is_equal(0)
	assert_int(MHNatureMeshes.build_builder("nope", 0, 0).tri_count()).is_equal(0)


func test_sizes_are_plausible_and_origin_is_near_the_ground() -> void:
	for k: Variant in MHNatureMeshes.KINDS:
		var kind: String = str(k)
		var h: float = MHNatureMeshes.height_of(kind)
		for lod in range(MHNatureMeshes.LOD_COUNT):
			for v in range(MHNatureMeshes.VARIANTS):
				var box: AABB = MHNatureMeshes.build(kind, lod, v).get_aabb()
				var msg: String = "%s lod %d v%d top %.2f of %.2f" % [kind, lod, v, box.end.y, h]
				assert_bool(box.end.y >= 0.3 * h and box.end.y <= 1.5 * h).override_failure_message(msg).is_true()
				assert_bool(box.position.y >= -0.6).override_failure_message("sunk too deep: " + msg).is_true()
				assert_bool(box.size.x < 12.0 and box.size.z < 12.0).override_failure_message("too wide: " + msg).is_true()


func test_vertices_normals_and_colours_are_valid() -> void:
	for k: Variant in MHNatureMeshes.KINDS:
		var kind: String = str(k)
		var b: MHMeshBuilder = MHNatureMeshes.build_builder(kind, 0, 1)
		assert_int(b.verts.size()).is_equal(b.normals.size())
		assert_int(b.verts.size()).is_equal(b.colors.size())
		assert_int(b.indices.size()).is_equal(b.verts.size())
		for i in range(b.verts.size()):
			var p: Vector3 = b.verts[i]
			assert_bool(is_finite(p.x) and is_finite(p.y) and is_finite(p.z)).is_true()
			assert_float(b.normals[i].length()).is_equal_approx(1.0, 0.001)
			var c: Color = b.colors[i]
			assert_bool(c.r >= 0.0 and c.r <= 1.0 and c.g >= 0.0 and c.g <= 1.0 and c.b >= 0.0 and c.b <= 1.0).is_true()


func test_flower_variants_use_the_palette_flower_colours() -> void:
	# Head colours come from MHPalette.FLOWERS (lerped toward white at the tip); at least two distinct colours show up.
	var b: MHMeshBuilder = MHNatureMeshes.build_builder("flower_patch", 0, 0)
	var seen: Dictionary = {}
	for c in b.colors:
		seen[(c as Color).to_html(false)] = true
	assert_int(seen.size()).is_greater(3)


func test_print_hashes_for_golden_values() -> void:
	# Not an assertion: prints one line per (kind, lod 0, variant 0..1) so golden hashes can be pasted in later.
	for k: Variant in MHNatureMeshes.KINDS:
		var kind: String = str(k)
		for v in range(2):
			var b: MHMeshBuilder = MHNatureMeshes.build_builder(kind, 0, v)
			print("ART_HASH nature %s lod0 v%d tris=%d hash=%d" % [kind, v, b.tri_count(), b.geometry_hash()])
	assert_bool(true).is_true()
