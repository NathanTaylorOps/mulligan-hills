extends GdUnitTestSuite
## MHBuildingGallery smoke test: builds under a tree headless, shows five tiers, buttons logic works.
## NOT YET RUN.


func test_gallery_builds_five_tiers_for_every_building_and_spec() -> void:
	var g: MHBuildingGallery = MHBuildingGallery.new()
	auto_free(g)
	add_child(g)
	assert_int(g.shown_count()).is_equal(5)
	for i in range(MHBuildingMeshes.IDS.size()):
		g.select(i)
		assert_str(g.current_id()).is_equal(str(MHBuildingMeshes.IDS[i]))
		assert_int(g.shown_count()).is_equal(5)
		g.set_spec("b")
		assert_int(g.shown_count()).is_equal(5)
		g.set_spec("a")
	g.rotate_view()


func test_gallery_select_wraps() -> void:
	var g: MHBuildingGallery = MHBuildingGallery.new()
	auto_free(g)
	add_child(g)
	g.select(-1)
	assert_str(g.current_id()).is_equal(str(MHBuildingMeshes.IDS[MHBuildingMeshes.IDS.size() - 1]))
	g.select(MHBuildingMeshes.IDS.size())
	assert_str(g.current_id()).is_equal(str(MHBuildingMeshes.IDS[0]))


func test_scene_file_exists() -> void:
	assert_bool(ResourceLoader.exists("res://art/mh_building_gallery.tscn")).is_true()
