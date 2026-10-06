extends GdUnitTestSuite
## The vertical slice scene and its golfer manager, driven without engine frames through MHVerticalSlice.tick().
## Covers: buildings drawn at their parcels and updated on tier change, sticky slots, hole building, golfers
## appearing over a game day within the visible caps, and that drawing never changes the sim.
## NOT YET RUN in Godot (no engine where this was written).

const WALL: int = 20000 * 86400


func _scene() -> MHVerticalSlice:
	var scene: MHVerticalSlice = auto_free(MHVerticalSlice.new())
	add_child(scene)
	scene.set_process(false) # Tests call tick() themselves.
	return scene


func _rich(scene: MHVerticalSlice) -> void:
	scene.session.economy.cash = 100000000


func test_scene_file_loads_and_carries_the_script() -> void:
	assert_bool(ResourceLoader.exists(MHVerticalSlice.SCENE_PATH)).is_true()
	var packed: PackedScene = load(MHVerticalSlice.SCENE_PATH) as PackedScene
	assert_bool(packed != null).is_true()
	var inst: Node = packed.instantiate()
	auto_free(inst)
	assert_bool(inst is MHVerticalSlice).is_true()


func test_launcher_lists_the_slice() -> void:
	var found: bool = false
	for e: Variant in MHLauncher.SCENES:
		if str((e as Array)[1]) == MHVerticalSlice.SCENE_PATH:
			found = true
	assert_bool(found).is_true()


func test_starts_with_the_starter_club() -> void:
	var scene: MHVerticalSlice = _scene()
	assert_object(scene.session).is_not_null()
	assert_str(scene.starter_hole_error).is_equal("")
	assert_int(scene.built_slots.size()).is_equal(MHVerticalSlice.STARTER_HOLES)
	assert_int(scene.hole_points.size()).is_equal(MHVerticalSlice.STARTER_HOLES)
	assert_int(scene.session.economy.holes).is_equal(MHVerticalSlice.STARTER_HOLES)
	assert_bool(scene.session.demo).is_equal(not MHVerticalSlice.UNLOCK_FULL_GAME)
	assert_int(scene.building_nodes.size()).is_equal(MHSliceStarter.STARTER_BUILDINGS.size())
	assert_int(scene.nature_group_count).is_between(1, 36)
	assert_int(scene.golfers.near_cap).is_equal(2)


func test_starter_building_appears_at_its_parcel_and_grows_with_its_tier() -> void:
	var scene: MHVerticalSlice = _scene()
	scene.tick(0, WALL, 0.0)
	assert_bool(scene.building_nodes.has("clubhouse")).is_true()
	assert_int(int(scene.building_tiers["clubhouse"])).is_equal(1)
	var slot: int = int(scene.slots["clubhouse"])
	assert_int(MHSliceLayout.slot_parcel(slot)).is_equal(8)
	var node: MeshInstance3D = scene.building_nodes["clubhouse"] as MeshInstance3D
	var expected: Transform3D = MHSliceLayout.building_transform_tier(slot,
		MHBuildingMeshes.bounds("clubhouse", 1, "a"), 1)
	assert_float(node.transform.origin.x).is_equal_approx(expected.origin.x, 0.0001)
	assert_float(node.transform.origin.z).is_equal_approx(expected.origin.z, 0.0001)
	var tris1: int = MHMeshBuilder.mesh_tri_count(node.mesh as ArrayMesh)
	assert_int(tris1).is_equal(MHBuildingMeshes.tri_count("clubhouse", 1, "a"))
	# The tier-2 gate (6 holes) is the session's business; set the tier directly to test the redraw.
	scene.session.economy.set_tier(scene.session.economy.params.building_index("clubhouse"), 2)
	scene.tick(0, WALL, 0.0)
	assert_int(int(scene.building_tiers["clubhouse"])).is_equal(2)
	var tris2: int = MHMeshBuilder.mesh_tri_count(node.mesh as ArrayMesh)
	assert_int(tris2).is_equal(MHBuildingMeshes.tri_count("clubhouse", 2, "a"))
	assert_int(tris2).is_greater(tris1)
	assert_int(scene.building_nodes.size()).is_equal(MHSliceStarter.STARTER_BUILDINGS.size())


func test_all_ten_buildings_get_distinct_places_outside_hole_parcels() -> void:
	var scene: MHVerticalSlice = _scene()
	for id: Variant in MHSliceLayout.ORDER:
		scene.session.economy.set_tier(scene.session.economy.params.building_index(str(id)), 1)
	scene.tick(0, WALL, 0.0)
	assert_int(scene.building_nodes.size()).is_equal(10)
	var seen: Dictionary = {}
	for id2: Variant in scene.slots.keys():
		var slot: int = int(scene.slots[id2])
		assert_bool(seen.has(slot)).is_false()
		seen[slot] = true
		var parcel: int = MHSliceLayout.slot_parcel(slot)
		if parcel >= 0:
			assert_bool(MHSliceLayout.is_reserved(parcel)).is_false()
			assert_bool(scene.session.land.is_owned(parcel)).is_true()


func test_buying_land_does_not_move_placed_buildings() -> void:
	var scene: MHVerticalSlice = _scene()
	_rich(scene)
	for id: String in ["clubhouse", "driving_range"]:
		scene.session.economy.set_tier(scene.session.economy.params.building_index(id), 1)
	scene.tick(0, WALL, 0.0)
	var before: Dictionary = scene.slots.duplicate()
	var origin: Vector3 = (scene.building_nodes["driving_range"] as Node3D).transform.origin
	assert_str(scene.buy_next_parcel()).is_equal("")
	scene.tick(0, WALL, 0.0)
	for id2: Variant in before.keys():
		assert_int(int(scene.slots[id2])).is_equal(int(before[id2]))
	var after: Vector3 = (scene.building_nodes["driving_range"] as Node3D).transform.origin
	assert_float(after.x).is_equal(origin.x)
	assert_float(after.z).is_equal(origin.z)
	# Parcel 7 (bought first) lies under hole corridors, so a new heavy building takes the free cell on parcel 6.
	scene.session.economy.set_tier(scene.session.economy.params.building_index("pool_spa"), 1)
	scene.tick(0, WALL, 0.0)
	assert_int(MHSliceLayout.slot_parcel(int(scene.slots["pool_spa"]))).is_equal(6)


func test_holes_need_their_parcels_before_they_can_be_built() -> void:
	var scene: MHVerticalSlice = _scene()
	_rich(scene)
	assert_int(scene.built_slots.size()).is_equal(3)
	assert_str(scene.build_next_hole()).is_not_equal("") # slots 3 and 4 need parcels 7 and 11
	assert_str(scene.buy_next_parcel()).is_equal("") # parcel 7
	assert_str(scene.buy_next_parcel()).is_equal("") # parcel 11
	assert_str(scene.build_next_hole()).is_equal("")
	assert_str(scene.build_next_hole()).is_equal("")
	scene.tick(0, WALL, 0.0)
	assert_int(scene.built_slots.size()).is_equal(5)
	assert_int(scene.hole_points.size()).is_equal(5)
	assert_str(scene.build_next_hole()).is_not_equal("") # slots 5 and 6 need parcels 0 and 4
	assert_int(scene.session.economy.holes).is_equal(5)


func test_golfers_appear_within_the_caps_over_one_game_day() -> void:
	var scene: MHVerticalSlice = _scene()
	var most_alive: int = 0
	for i: int in range(1500):
		scene.tick(1000000, WALL, 0.1)
		most_alive = maxi(most_alive, scene.golfers.golfer_count())
		assert_int(scene.golfers.last_figures).is_less_equal(scene.golfers.near_cap)
		assert_int(scene.golfers.last_figures + scene.golfers.last_baked).is_less_equal(scene.golfers.total_cap)
	assert_int(scene.session.clock.day()).is_equal(1)
	assert_int(scene.schedule.next_serial).is_greater(0)
	assert_int(most_alive).is_greater(0)


func test_drawing_never_changes_the_sim() -> void:
	var scene: MHVerticalSlice = _scene()
	var bare: MHGameSession = MHGameSession.create()
	bare.demo = not MHVerticalSlice.UNLOCK_FULL_GAME
	assert_str(MHSliceStarter.setup(bare, MHLiveGameStateView.new(bare))).is_equal("")
	for i: int in range(600):
		scene.tick(1000000, WALL, 0.05)
		bare.advance(1000000, WALL)
	var a: PackedInt64Array = scene.session.economy.state_list()
	var b: PackedInt64Array = bare.economy.state_list()
	assert_int(a.size()).is_equal(b.size())
	for i: int in range(a.size()):
		assert_int(a[i]).override_failure_message("state index %d" % i).is_equal(b[i])
	assert_int(scene.session.clock.total_minutes()).is_equal(bare.clock.total_minutes())
	assert_int(scene.session.economy.total_revenue).is_equal(bare.economy.total_revenue)


func test_pause_freezes_the_golfers() -> void:
	var scene: MHVerticalSlice = _scene()
	scene.golfers.spawn_group(0, 3, Vector2(10.0, 10.0), Vector2(10.0, 70.0))
	scene.session.handle_intent(&"toggle_pause", {})
	scene.tick(1000000, WALL, 1.0)
	assert_float(float((scene.golfers.golfers[0] as Dictionary)["t"])).is_equal(0.0)
	scene.session.handle_intent(&"toggle_pause", {})
	scene.tick(1000000, WALL, 1.0)
	assert_float(float((scene.golfers.golfers[0] as Dictionary)["t"])).is_equal_approx(1.0, 0.0001)


func test_quality_button_cycles_the_caps() -> void:
	var scene: MHVerticalSlice = _scene()
	assert_int(scene.golfers.total_cap).is_equal(int(MHSliceVisibility.caps_for_tier("low")["total"]))
	scene._on_quality()
	assert_str(scene.tier_name).is_equal("medium")
	assert_int(scene.golfers.near_cap).is_equal(int(MHSliceVisibility.caps_for_tier("medium")["near"]))
	scene._on_quality()
	assert_int(scene.golfers.near_cap).is_equal(int(MHSliceVisibility.caps_for_tier("high")["near"]))
	scene._on_quality()
	assert_str(scene.tier_name).is_equal("low")


func test_menu_rows_show_state_and_buy_buttons() -> void:
	var scene: MHVerticalSlice = _scene()
	_rich(scene)
	scene._on_toggle_menu()
	assert_bool(scene._menu_panel.visible).is_true()
	var clubhouse: Dictionary = scene._menu_rows["clubhouse"] as Dictionary
	assert_bool((clubhouse["label"] as Label).text.begins_with("Clubhouse")).is_true()
	assert_bool((clubhouse["label"] as Label).text.contains("T1")).is_true()
	assert_bool((clubhouse["button"] as MHTapButton).text.begins_with("T2")).is_true()
	assert_bool((clubhouse["button"] as MHTapButton).disabled).is_true() # tier 2 needs 6 holes
	var homes: Dictionary = scene._menu_rows["homes"] as Dictionary
	assert_bool((homes["button"] as MHTapButton).disabled).is_true()
