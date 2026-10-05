extends GdUnitTestSuite
## Builds every gallery page headless (no scene tree, no camera) and checks counts. Catches null refs and
## bad keys in the code-built content. NOT YET RUN in Godot.


func _gallery() -> MHNatureGallery:
	var g: MHNatureGallery = MHNatureGallery.new()
	auto_free(g)
	return g


func test_scene_file_loads_and_carries_the_script() -> void:
	assert_bool(ResourceLoader.exists(MHNatureGallery.SCENE_PATH)).is_true()
	var scene: PackedScene = load(MHNatureGallery.SCENE_PATH) as PackedScene
	assert_bool(scene != null).is_true()
	var inst: Node = scene.instantiate()
	auto_free(inst)
	assert_bool(inst is MHNatureGallery).is_true()


func test_every_category_builds_at_every_lod_mode() -> void:
	var g: MHNatureGallery = _gallery()
	for cat: Variant in MHNatureGallery.CATEGORIES:
		for mode in range(MHNatureGallery.LOD_LABELS.size()):
			g.category = str(cat)
			g.lod_mode = mode
			g.build_content()
			var msg: String = "%s mode %d" % [str(cat), mode]
			assert_bool(g.tri_total > 0).override_failure_message(msg).is_true()
			assert_bool(g.instance_total > 0).override_failure_message(msg).is_true()
			assert_bool(g.content_root != null and g.content_root.get_child_count() > 0).override_failure_message(msg).is_true()
			assert_bool(g.extent.x > 1.0 and g.extent.y > 1.0).override_failure_message(msg).is_true()


func test_rebuilding_replaces_the_content_instead_of_stacking_it() -> void:
	var g: MHNatureGallery = _gallery()
	g.category = "rocks"
	g.build_content()
	var first_children: int = g.content_root.get_child_count()
	var first_tris: int = g.tri_total
	g.build_content()
	assert_int(g.content_root.get_child_count()).is_equal(first_children)
	assert_int(g.tri_total).is_equal(first_tris)
	assert_int(g.get_child_count()).is_equal(1)


func test_all_lods_mode_shows_three_times_the_rows() -> void:
	var g: MHNatureGallery = _gallery()
	g.category = "rocks"
	g.lod_mode = 0
	g.build_content()
	var one: int = g.instance_total
	g.lod_mode = 3
	g.build_content()
	assert_int(g.instance_total).is_equal(one * MHNatureMeshes.LOD_COUNT)


func test_trees_page_triangles_match_the_meshes_shown() -> void:
	var g: MHNatureGallery = _gallery()
	g.category = "trees"
	g.lod_mode = 0
	g.build_content()
	var want: int = 0
	for k: Variant in MHNatureMeshes.TREE_KINDS:
		for v in range(MHNatureMeshes.VARIANTS):
			want += MHNatureMeshes.build_builder(str(k), 0, v).tri_count()
	assert_int(g.tri_total).is_equal(want)
	assert_int(g.instance_total).is_equal(MHNatureMeshes.TREE_KINDS.size() * MHNatureMeshes.VARIANTS)


func test_stress_page_places_240_trees_in_a_few_multimeshes() -> void:
	var g: MHNatureGallery = _gallery()
	g.category = "stress"
	g.lod_mode = 3
	g.build_content()
	assert_int(g.instance_total).is_equal(MHNatureGallery.STRESS_TREES)
	assert_bool(g.draw_node_total > 0 and g.draw_node_total < 80).is_true()
	var first: int = g.tri_total
	g.build_content()
	assert_int(g.tri_total).is_equal(first)
	# Far LODs make the same forest cheaper than all-LOD0.
	g.lod_mode = 0
	g.build_content()
	assert_bool(g.tri_total > first).is_true()


func test_golfer_page_has_animated_and_baked_rows() -> void:
	var g: MHNatureGallery = _gallery()
	g.category = "golfers"
	g.lod_mode = 0
	g.build_content()
	var figures: int = 0
	for c: Node in g.content_root.get_children():
		var fig: MHGolferFigure = c as MHGolferFigure
		if fig == null:
			continue
		figures += 1
		assert_bool(fig.playing).is_true()
		fig.auto_advance = false
		fig.advance(0.3)
	assert_int(figures).is_equal(MHNatureGallery.GOLFER_LOOKS)
	assert_bool(g.tri_total > MHNatureGallery.GOLFER_LOOKS * 100).is_true()
