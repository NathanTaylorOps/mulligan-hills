extends GdUnitTestSuite
## MHMeshBuilder: triangle counts, winding, normals, determinism. NOT YET RUN in Godot.
##
## Godot front faces are clockwise. For a clockwise (a, b, c) the cross product (b - a) x (c - a)
## points INTO the surface, so the outward normal is its negation. Each check below recomputes that from
## the emitted vertices and compares it with the stored normal and with the direction away from the
## centre of a convex shape.

const WHITE: Color = Color(1, 1, 1)


func _outward_ok(b: MHMeshBuilder, centre: Vector3) -> bool:
	var n_tris: int = b.tri_count()
	for t in range(n_tris):
		var a: Vector3 = b.verts[t * 3]
		var bb: Vector3 = b.verts[t * 3 + 1]
		var c: Vector3 = b.verts[t * 3 + 2]
		var geo: Vector3 = -((bb - a).cross(c - a)).normalized()
		var mid: Vector3 = (a + bb + c) / 3.0
		if geo.dot(mid - centre) <= 0.0:
			return false
		if geo.dot(b.normals[t * 3]) < 0.999:
			return false
	return true


func test_box_is_12_triangles_with_outward_clockwise_faces() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.box(Vector3.ZERO, Vector3(2.0, 1.0, 3.0), WHITE, WHITE, WHITE)
	assert_int(b.tri_count()).is_equal(12)
	assert_int(b.verts.size()).is_equal(36)
	assert_bool(_outward_ok(b, Vector3.ZERO)).is_true()


func test_box_respects_centre_and_size() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.box(Vector3(1.0, 2.0, 3.0), Vector3(2.0, 4.0, 6.0), WHITE, WHITE, WHITE)
	var m: ArrayMesh = b.to_mesh()
	var box: AABB = MHMeshBuilder.mesh_bounds(m)
	assert_float(box.position.x).is_equal_approx(0.0, 0.0001)
	assert_float(box.end.x).is_equal_approx(2.0, 0.0001)
	assert_float(box.position.y).is_equal_approx(0.0, 0.0001)
	assert_float(box.end.y).is_equal_approx(4.0, 0.0001)
	assert_float(box.size.z).is_equal_approx(6.0, 0.0001)


func test_blob_count_formula_and_outward_faces() -> void:
	for stacks in [2, 3, 4]:
		for sides in [4, 5, 8]:
			var b: MHMeshBuilder = MHMeshBuilder.new()
			b.blob(Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 1.0), stacks, sides, WHITE, WHITE, 3, 0.0)
			assert_int(b.tri_count()).is_equal(2 * sides * (stacks - 1))
			assert_bool(_outward_ok(b, Vector3(0.0, 1.0, 0.0))).is_true()


func test_blob_jitter_is_deterministic_and_seed_dependent() -> void:
	var a: MHMeshBuilder = MHMeshBuilder.new()
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var c: MHMeshBuilder = MHMeshBuilder.new()
	a.blob(Vector3.ZERO, Vector3.ONE, 3, 7, WHITE, WHITE, 11, 0.2)
	b.blob(Vector3.ZERO, Vector3.ONE, 3, 7, WHITE, WHITE, 11, 0.2)
	c.blob(Vector3.ZERO, Vector3.ONE, 3, 7, WHITE, WHITE, 12, 0.2)
	assert_int(a.geometry_hash()).is_equal(b.geometry_hash())
	assert_bool(a.geometry_hash() != c.geometry_hash()).is_true()


func test_frustum_triangle_counts() -> void:
	var cyl: MHMeshBuilder = MHMeshBuilder.new()
	cyl.frustum(0.0, 1.0, 0.5, 0.5, 6, WHITE, WHITE, false, false)
	assert_int(cyl.tri_count()).is_equal(12)
	var capped: MHMeshBuilder = MHMeshBuilder.new()
	capped.frustum(0.0, 1.0, 0.5, 0.4, 6, WHITE, WHITE, true, true)
	assert_int(capped.tri_count()).is_equal(24)
	var cone: MHMeshBuilder = MHMeshBuilder.new()
	cone.frustum(0.0, 1.0, 0.5, 0.0, 6, WHITE, WHITE, false, false)
	assert_int(cone.tri_count()).is_equal(6)
	var cone_base: MHMeshBuilder = MHMeshBuilder.new()
	cone_base.frustum(0.0, 1.0, 0.5, 0.0, 6, WHITE, WHITE, true, true)
	assert_int(cone_base.tri_count()).is_equal(12)


func test_capped_frustum_faces_point_away_from_axis_centre() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.frustum(0.0, 1.0, 0.5, 0.4, 7, WHITE, WHITE, true, true)
	assert_bool(_outward_ok(b, Vector3(0.0, 0.5, 0.0))).is_true()


func test_tube_runs_between_its_end_points() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.tube(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 2.0, 0.0), 0.1, 0.1, 5, WHITE, WHITE)
	var box: AABB = MHMeshBuilder.mesh_bounds(b.to_mesh())
	assert_float(box.position.y).is_equal_approx(0.0, 0.0001)
	assert_float(box.end.y).is_equal_approx(2.0, 0.0001)
	var d: MHMeshBuilder = MHMeshBuilder.new()
	d.tube(Vector3(1.0, 1.0, 1.0), Vector3(3.0, 4.0, 5.0), 0.1, 0.05, 4, WHITE, WHITE, true, true)
	assert_bool(_outward_ok(d, Vector3(2.0, 2.5, 3.0))).is_true()


func test_tube_restores_the_transform() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var t: Transform3D = Transform3D(Basis(), Vector3(5.0, 0.0, 0.0))
	b.set_xf(t)
	b.tube(Vector3.ZERO, Vector3(0.0, 1.0, 0.0), 0.1, 0.1, 4, WHITE, WHITE)
	assert_bool(b.xf == t).is_true()
	var box: AABB = MHMeshBuilder.mesh_bounds(b.to_mesh())
	assert_float(box.position.x).is_greater(4.8)


func test_two_sided_helpers_double_the_triangles() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.tri_two_sided(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(0, 1, 0), WHITE, WHITE, WHITE)
	assert_int(b.tri_count()).is_equal(2)
	var q: MHMeshBuilder = MHMeshBuilder.new()
	q.quad_two_sided(Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0), WHITE, WHITE)
	assert_int(q.tri_count()).is_equal(4)
	# The two copies face opposite ways.
	var n0: Vector3 = b.normals[0]
	var n1: Vector3 = b.normals[3]
	assert_float(n0.dot(n1)).is_equal_approx(-1.0, 0.0001)


func test_degenerate_triangles_are_dropped() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.tri(Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(2, 0, 0), WHITE, WHITE, WHITE, Vector3(0, -1, 0))
	assert_int(b.tri_count()).is_equal(0)
	assert_int(b.to_mesh().get_surface_count()).is_equal(0)


func test_disc_and_blob_shadow_counts() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.disc(Vector3(1.0, 0.5, 2.0), 1.0, 8, WHITE, true)
	assert_int(b.tri_count()).is_equal(8)
	for n in b.normals:
		assert_float((n as Vector3).y).is_equal_approx(1.0, 0.0001)
	var down: MHMeshBuilder = MHMeshBuilder.new()
	down.disc(Vector3.ZERO, 1.0, 6, WHITE, false)
	assert_float((down.normals[0] as Vector3).y).is_equal_approx(-1.0, 0.0001)
	assert_int(MHSkySetup.blob_shadow_mesh(1.0, 10).get_surface_count()).is_equal(1)
	assert_int(MHMeshBuilder.mesh_tri_count(MHSkySetup.blob_shadow_mesh(1.0, 10))).is_equal(30)


func test_transform_moves_geometry() -> void:
	var a: MHMeshBuilder = MHMeshBuilder.new()
	var b: MHMeshBuilder = MHMeshBuilder.new()
	a.box(Vector3.ZERO, Vector3.ONE, WHITE, WHITE, WHITE)
	b.set_xf(Transform3D(Basis(), Vector3(0.0, 5.0, 0.0)))
	b.box(Vector3.ZERO, Vector3.ONE, WHITE, WHITE, WHITE)
	assert_bool(a.geometry_hash() != b.geometry_hash()).is_true()
	assert_float(b.verts[0].y - a.verts[0].y).is_equal_approx(5.0, 0.0001)
	b.reset_xf()
	assert_bool(b.xf == Transform3D.IDENTITY).is_true()


func test_non_uniform_scale_keeps_outward_normals() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.set_xf(Transform3D(Basis.from_scale(Vector3(2.0, 1.0, 0.5)), Vector3.ZERO))
	b.blob(Vector3.ZERO, Vector3.ONE, 3, 8, WHITE, WHITE, 1, 0.0)
	assert_bool(_outward_ok(b, Vector3.ZERO)).is_true()


func test_mesh_output_is_one_indexed_surface_and_hash_matches() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.box(Vector3.ZERO, Vector3.ONE, WHITE, WHITE, WHITE)
	b.blob(Vector3(0, 2, 0), Vector3.ONE, 3, 6, WHITE, WHITE, 1, 0.1)
	var m: ArrayMesh = b.to_mesh()
	assert_int(m.get_surface_count()).is_equal(1)
	assert_int(MHMeshBuilder.mesh_tri_count(m)).is_equal(b.tri_count())
	assert_int(MHMeshBuilder.hash_mesh(m)).is_equal(b.geometry_hash())


func test_empty_builder_gives_empty_mesh() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var m: ArrayMesh = b.to_mesh()
	assert_int(m.get_surface_count()).is_equal(0)
	assert_int(MHMeshBuilder.mesh_tri_count(m)).is_equal(0)
	assert_int(MHMeshBuilder.hash_mesh(m)).is_equal(2166136261)
	assert_int(b.geometry_hash()).is_equal(2166136261)


func test_basis_y_along_is_orthonormal_for_any_direction() -> void:
	var dirs: Array = [Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0),
		Vector3(1, 1, 1).normalized(), Vector3(0.95, 0.1, 0.1).normalized()]
	for d: Variant in dirs:
		var dir: Vector3 = d
		var bs: Basis = MHMeshBuilder.basis_y_along(dir)
		assert_float(bs.y.distance_to(dir)).is_less(0.0001)
		assert_float(bs.x.length()).is_equal_approx(1.0, 0.0001)
		assert_float(bs.z.length()).is_equal_approx(1.0, 0.0001)
		assert_float(bs.x.dot(bs.y)).is_equal_approx(0.0, 0.0001)
		assert_float(bs.x.dot(bs.z)).is_equal_approx(0.0, 0.0001)
		assert_float(bs.determinant()).is_equal_approx(1.0, 0.0001)


func test_materials_and_instances_build() -> void:
	var mat: StandardMaterial3D = MHArtMaterials.vertex_color()
	assert_bool(mat.vertex_color_use_as_albedo).is_true()
	var two: StandardMaterial3D = MHArtMaterials.vertex_color(true)
	assert_int(two.cull_mode).is_equal(BaseMaterial3D.CULL_DISABLED)
	var b: MHMeshBuilder = MHMeshBuilder.new()
	b.box(Vector3.ZERO, Vector3.ONE, WHITE, WHITE, WHITE)
	var mi: MeshInstance3D = MHArtMaterials.make_instance(b.to_mesh(), mat, false)
	auto_free(mi)
	assert_int(mi.cast_shadow).is_equal(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var tf: Array = [Transform3D(Basis(), Vector3(1, 0, 0)), Transform3D(Basis(), Vector3(2, 0, 0))]
	var mm: MultiMeshInstance3D = MHArtMaterials.make_multimesh(b.to_mesh(), mat, tf)
	auto_free(mm)
	assert_int(mm.multimesh.instance_count).is_equal(2)
	assert_bool(mm.multimesh.use_colors).is_false()
