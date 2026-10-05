extends GdUnitTestSuite
## MHBuildingMeshes: 10 buildings x 5 tiers x 2 specs. Triangle budgets, tier growth, determinism, mesh
## sanity. Pure geometry, no scene tree. NOT YET RUN (Godot is not available where this was written).

const SIZE_TOLERANCE: float = 0.01


func _catalogue() -> Dictionary:
	var text: String = FileAccess.get_file_as_string("res://data/buildings.json")
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(parsed is Dictionary).override_failure_message("buildings.json did not parse").is_true()
	return parsed as Dictionary


func _all_ids() -> Array:
	return MHBuildingMeshes.IDS


func test_ids_match_catalogue_in_order() -> void:
	var cat: Dictionary = _catalogue()
	var rows: Array = cat["buildings"]
	assert_int(rows.size()).is_equal(MHBuildingMeshes.IDS.size())
	for i in range(rows.size()):
		var row: Dictionary = rows[i]
		assert_str(str(row["id"])).is_equal(str(MHBuildingMeshes.IDS[i]))
		var specs: Array = row["tier3_specs"]
		assert_int(specs.size()).is_equal(MHBuildingMeshes.SPECS.size())
		for j in range(specs.size()):
			var spec_row: Dictionary = specs[j]
			assert_str(str(spec_row["id"])).is_equal(str(MHBuildingMeshes.SPECS[j]))
		var tiers: Array = row["tiers"]
		assert_int(tiers.size()).is_equal(MHBuildingMeshes.TIER_COUNT)


func test_every_building_tier_spec_builds_a_mesh() -> void:
	for id: Variant in _all_ids():
		for tier in range(1, 6):
			for spec: Variant in MHBuildingMeshes.SPECS:
				var mesh: ArrayMesh = MHBuildingMeshes.build(str(id), tier, str(spec))
				var label: String = "%s tier %d spec %s" % [str(id), tier, str(spec)]
				assert_int(mesh.get_surface_count()).override_failure_message("surfaces " + label).is_equal(1)
				assert_bool(MHMeshBuilder.mesh_tri_count(mesh) > 0).override_failure_message("empty " + label).is_true()


func test_tier5_is_under_3000_triangles() -> void:
	for id: Variant in _all_ids():
		for spec: Variant in MHBuildingMeshes.SPECS:
			var n: int = MHBuildingMeshes.tri_count(str(id), 5, str(spec))
			assert_bool(n < 3000).override_failure_message("%s spec %s tier 5 has %d triangles" % [str(id), str(spec), n]).is_true()


func test_per_tier_budgets() -> void:
	for id: Variant in _all_ids():
		for tier in range(1, 6):
			for spec: Variant in MHBuildingMeshes.SPECS:
				var n: int = MHBuildingMeshes.tri_count(str(id), tier, str(spec))
				var cap: int = MHBuildingMeshes.budget(tier)
				assert_bool(n <= cap).override_failure_message("%s tier %d spec %s: %d > %d" % [str(id), tier, str(spec), n, cap]).is_true()


func test_budget_table_is_increasing_and_under_3000() -> void:
	var prev: int = 0
	for tier in range(1, 6):
		var cap: int = MHBuildingMeshes.budget(tier)
		assert_bool(cap > prev).is_true()
		prev = cap
	assert_bool(prev < 3000).is_true()


func test_triangles_strictly_increase_with_tier() -> void:
	for id: Variant in _all_ids():
		for spec: Variant in MHBuildingMeshes.SPECS:
			var prev: int = 0
			for tier in range(1, 6):
				var n: int = MHBuildingMeshes.tri_count(str(id), tier, str(spec))
				assert_bool(n > prev).override_failure_message("%s spec %s tier %d: %d not above %d" % [str(id), str(spec), tier, n, prev]).is_true()
				prev = n


func test_bounds_never_shrink_with_tier() -> void:
	for id: Variant in _all_ids():
		for spec: Variant in MHBuildingMeshes.SPECS:
			var prev: AABB = MHBuildingMeshes.bounds(str(id), 1, str(spec))
			for tier in range(2, 6):
				var cur: AABB = MHBuildingMeshes.bounds(str(id), tier, str(spec))
				var label: String = "%s spec %s tier %d" % [str(id), str(spec), tier]
				assert_bool(cur.size.x >= prev.size.x - SIZE_TOLERANCE).override_failure_message("width " + label).is_true()
				assert_bool(cur.size.y >= prev.size.y - SIZE_TOLERANCE).override_failure_message("height " + label).is_true()
				assert_bool(cur.size.z >= prev.size.z - SIZE_TOLERANCE).override_failure_message("depth " + label).is_true()
				prev = cur


func test_top_tier_is_clearly_bigger_than_tier_1() -> void:
	for id: Variant in _all_ids():
		var lo: AABB = MHBuildingMeshes.bounds(str(id), 1, "a")
		var hi: AABB = MHBuildingMeshes.bounds(str(id), 5, "a")
		assert_bool(hi.size.x * hi.size.z > lo.size.x * lo.size.z * 2.0).override_failure_message("footprint " + str(id)).is_true()
		assert_bool(MHBuildingMeshes.tri_count(str(id), 5, "a") >= MHBuildingMeshes.tri_count(str(id), 1, "a") * 3).override_failure_message("detail " + str(id)).is_true()


func test_sizes_are_sane() -> void:
	for id: Variant in _all_ids():
		for tier in range(1, 6):
			var bb: AABB = MHBuildingMeshes.bounds(str(id), tier, "a")
			var label: String = "%s tier %d" % [str(id), tier]
			assert_bool(bb.position.y > -0.3).override_failure_message("sunk " + label).is_true()
			assert_bool(bb.size.y > 0.4 and bb.size.y < 20.0).override_failure_message("height " + label).is_true()
			assert_bool(bb.size.x < 40.0 and bb.size.z < 40.0).override_failure_message("footprint " + label).is_true()


func test_deterministic_same_inputs_same_geometry() -> void:
	for id: Variant in _all_ids():
		for tier in range(1, 6):
			var a: MHMeshBuilder = MHBuildingMeshes.build_builder(str(id), tier, "b")
			var b: MHMeshBuilder = MHBuildingMeshes.build_builder(str(id), tier, "b")
			assert_int(a.geometry_hash()).is_equal(b.geometry_hash())
			assert_bool(a.verts == b.verts).is_true()
			assert_bool(a.colors == b.colors).is_true()
			assert_bool(a.indices == b.indices).is_true()
			assert_int(MHBuildingMeshes.geometry_hash(str(id), tier, "b")).is_equal(a.geometry_hash())


func test_mesh_is_stable_between_builds() -> void:
	# hash_mesh reads colours back from the GPU-format array (8-bit rounding), so only compare mesh to mesh.
	var m1: ArrayMesh = MHBuildingMeshes.build("clubhouse", 3, "a")
	var m2: ArrayMesh = MHBuildingMeshes.build("clubhouse", 3, "a")
	assert_int(MHMeshBuilder.hash_mesh(m1)).is_equal(MHMeshBuilder.hash_mesh(m2))


func test_every_tier_looks_different() -> void:
	for id: Variant in _all_ids():
		var seen: Dictionary = {}
		for tier in range(1, 6):
			seen[MHBuildingMeshes.geometry_hash(str(id), tier, "a")] = true
		assert_int(seen.size()).override_failure_message("duplicate tier geometry in " + str(id)).is_equal(5)


func test_every_building_looks_different() -> void:
	var seen: Dictionary = {}
	for id: Variant in _all_ids():
		seen[MHBuildingMeshes.geometry_hash(str(id), 5, "a")] = true
	assert_int(seen.size()).is_equal(MHBuildingMeshes.IDS.size())


func test_spec_only_matters_from_tier_3_and_never_changes_triangle_count() -> void:
	for id: Variant in _all_ids():
		for tier in range(1, 6):
			var ha: int = MHBuildingMeshes.geometry_hash(str(id), tier, "a")
			var hb: int = MHBuildingMeshes.geometry_hash(str(id), tier, "b")
			if tier < 3:
				assert_int(hb).override_failure_message("spec leaks below tier 3: %s %d" % [str(id), tier]).is_equal(ha)
			else:
				assert_bool(hb != ha).override_failure_message("spec a and b identical: %s %d" % [str(id), tier]).is_true()
			assert_int(MHBuildingMeshes.tri_count(str(id), tier, "a")).is_equal(MHBuildingMeshes.tri_count(str(id), tier, "b"))


func test_mesh_arrays_are_consistent_and_opaque() -> void:
	for id: Variant in _all_ids():
		var mesh: ArrayMesh = MHBuildingMeshes.build(str(id), 5, "a")
		var arrays: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		assert_int(normals.size()).is_equal(verts.size())
		assert_int(colors.size()).is_equal(verts.size())
		assert_int(idx.size() % 3).is_equal(0)
		for i in idx:
			assert_bool(i >= 0 and i < verts.size()).is_true()
		for c in colors:
			assert_float(c.a).is_equal(1.0)
		for v in verts:
			assert_bool(is_finite(v.x) and is_finite(v.y) and is_finite(v.z)).is_true()
		for n in normals:
			assert_float(n.length()).is_equal_approx(1.0, 0.01)


func test_unknown_id_gives_empty_mesh_and_tier_is_clamped() -> void:
	var empty: ArrayMesh = MHBuildingMeshes.build("not_a_building", 3, "a")
	assert_int(empty.get_surface_count()).is_equal(0)
	assert_bool(MHBuildingMeshes.is_valid_id("clubhouse")).is_true()
	assert_bool(MHBuildingMeshes.is_valid_id("not_a_building")).is_false()
	assert_int(MHBuildingMeshes.tri_count("homes", 0, "a")).is_equal(MHBuildingMeshes.tri_count("homes", 1, "a"))
	assert_int(MHBuildingMeshes.tri_count("homes", 9, "a")).is_equal(MHBuildingMeshes.tri_count("homes", 5, "a"))
	assert_float(MHBuildingMeshes.bounds("not_a_building", 1, "a").size.length()).is_equal(0.0)


func test_total_triangles_for_a_full_course_is_phone_friendly() -> void:
	# One of every building at tier 5 must stay well under a typical whole-scene mesh budget.
	var total: int = 0
	for id: Variant in _all_ids():
		total += MHBuildingMeshes.tri_count(str(id), 5, "a")
	assert_bool(total < 15000).override_failure_message("full set tier 5 = %d" % total).is_true()
