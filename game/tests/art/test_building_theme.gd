extends GdUnitTestSuite
## MHBuildingTheme and MHBuildingParts: colours are deterministic and readable, parts have the triangle
## cost their comments promise. NOT YET RUN.


func test_theme_is_deterministic_and_opaque() -> void:
	for id: Variant in MHBuildingMeshes.IDS:
		for spec in range(2):
			var a: MHBuildingTheme = MHBuildingTheme.make(str(id), spec)
			var b: MHBuildingTheme = MHBuildingTheme.make(str(id), spec)
			assert_bool(a.wall == b.wall and a.roof == b.roof and a.accent == b.accent).is_true()
			for c: Color in [a.wall, a.wall_alt, a.roof, a.trim, a.accent, a.glass, a.base, a.door]:
				assert_float(c.a).is_equal(1.0)


func test_roof_reads_against_walls() -> void:
	for id: Variant in MHBuildingMeshes.IDS:
		for spec in range(2):
			var t: MHBuildingTheme = MHBuildingTheme.make(str(id), spec)
			var ratio: float = MHPalette.contrast_ratio(t.roof, t.wall)
			assert_bool(ratio >= 1.4).override_failure_message("roof/wall contrast %.2f for %s spec %d" % [ratio, str(id), spec]).is_true()


func test_spec_b_changes_colours() -> void:
	for id: Variant in MHBuildingMeshes.IDS:
		var a: MHBuildingTheme = MHBuildingTheme.make(str(id), 0)
		var b: MHBuildingTheme = MHBuildingTheme.make(str(id), 1)
		var differs: bool = a.roof != b.roof or a.accent != b.accent or a.wall != b.wall
		assert_bool(differs).override_failure_message("spec colours identical for " + str(id)).is_true()


func test_unknown_id_theme_still_valid() -> void:
	var t: MHBuildingTheme = MHBuildingTheme.make("nothing", 0)
	assert_float(t.roof.a).is_equal(1.0)


func _count(fn_id: String) -> int:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var red: Color = Color(0.8, 0.2, 0.2)
	match fn_id:
		"walls":
			MHBuildingParts.walls(b, Vector3.ZERO, Vector3(4.0, 3.0, 3.0), red)
		"slab":
			MHBuildingParts.slab(b, Vector3.ZERO, Vector3(4.0, 1.0, 3.0), red, red)
		"gable":
			MHBuildingParts.gable(b, Vector3.ZERO, 4.0, 3.0, 1.5, 0.3, red, red)
		"hip_pyramid":
			MHBuildingParts.hip(b, Vector3.ZERO, 4.0, 3.0, 1.5, 0.3, 0.0, red)
		"hip_flat":
			MHBuildingParts.hip(b, Vector3.ZERO, 4.0, 3.0, 1.5, 0.3, 0.4, red)
		"shed":
			MHBuildingParts.shed(b, Vector3.ZERO, 4.0, 3.0, 1.0, red)
		"window":
			MHBuildingParts.windows(b, 0.0, 1.0, 1.0, 1.0, 1, 1.0, 1.0, 1.0, red, MHBuildingParts.NO_COLOR, false)
		"window_framed":
			MHBuildingParts.windows(b, 0.0, 1.0, 1.0, 1.0, 1, 1.0, 1.0, 1.0, red, red, false)
		"door":
			MHBuildingParts.door(b, 0.0, 1.0, 1.0, 2.0, red, red)
		"column":
			MHBuildingParts.column(b, 0.0, 0.0, 0.0, 2.0, 0.1, 6, red)
		"shrub":
			MHBuildingParts.shrub(b, Vector3.ZERO, 1.0, 1)
		"flagpole":
			MHBuildingParts.flagpole(b, Vector3.ZERO, 5.0, red)
		"cart":
			MHBuildingParts.cart(b, Vector3.ZERO, 0.0, red, red)
		_:
			pass
	return b.tri_count()


func test_part_triangle_costs() -> void:
	assert_int(_count("walls")).is_equal(8)
	assert_int(_count("slab")).is_equal(10)
	assert_int(_count("gable")).is_equal(6)
	assert_int(_count("hip_pyramid")).is_equal(4)
	assert_int(_count("hip_flat")).is_equal(10)
	assert_int(_count("shed")).is_equal(4)
	assert_int(_count("window")).is_equal(2)
	assert_int(_count("window_framed")).is_equal(4)
	assert_int(_count("door")).is_equal(4)
	assert_int(_count("column")).is_equal(12)
	assert_int(_count("shrub")).is_equal(10)
	assert_int(_count("flagpole")).is_equal(8)
	assert_int(_count("cart")).is_equal(42)


func test_push_pop_restores_frame() -> void:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var saved: Transform3D = MHBuildingParts.push(b, Vector3(5.0, 0.0, 0.0), PI * 0.5)
	MHBuildingParts.pop(b, saved)
	assert_bool(b.xf == Transform3D.IDENTITY).is_true()
