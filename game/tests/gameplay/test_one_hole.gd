extends GdUnitTestSuite
## Exact primitive geometry + resume regressions. Godot execution is CI-only.

func _layout() -> Dictionary:
	return {"slot_id": 0, "tee": [0, 0], "green": [0, 60, 5],
		"features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}]}

func _source(s: MHGameSession) -> Dictionary:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.session = s
	return scene._new_document()

func test_exact_geometry_roundtrip_and_legacy_preservation() -> void:
	var s: MHGameSession = MHGameSession.create()
	var doc: Dictionary = _source(s)
	var encoded: MHSaveResult = MHCourseLayout.encode([_layout()], doc["course"], [[480, 340]])
	assert_bool(encoded.is_ok()).is_true()
	assert_array(MHCourseLayout.decode(encoded.value).value).is_equal([_layout()])
	assert_int(MHCourseLayout.world_mm(480, 6000)).is_equal(102864)
	assert_int(int(doc["course"]["schema_version"])).is_equal(1)
	doc["course"]["holes"] = [{"hole_no": 1, "green": {"outline": [[0, 0], [1, 0], [0, 1]]}}]
	assert_bool(MHCourseLayout.encode([_layout()], doc["course"], [[480, 340]]).is_ok()).is_false()
	assert_bool((doc["course"]["holes"][0] as Dictionary).has("green")).is_true()

func test_ambiguous_geometry_and_unowned_land_rejected() -> void:
	var s: MHGameSession = MHGameSession.create()
	var course: Dictionary = _source(s)["course"]
	var h: Dictionary = _layout()
	h["features"][0]["circle"] = [0, 20, 5]
	assert_bool(MHCourseLayout.encode([h], course, [[480, 340]]).is_ok()).is_false()
	assert_bool(MHCourseLayout.encode([_layout()], course, [[0, 0]]).is_ok()).is_false()
	h = _layout()
	h["green"][1] = 70 # Crosses into an unowned row on the integration patch.
	assert_bool(MHCourseLayout.encode([h], course, [[480, 340]]).is_ok()).is_false()

func test_finalized_checkpoint_reloads_without_charge_or_award() -> void:
	var s: MHGameSession = MHGameSession.create()
	var doc: Dictionary = _source(s)
	var encoded: MHSaveResult = MHCourseLayout.encode([_layout()], doc["course"], [[480, 340]])
	assert_bool(encoded.is_ok()).is_true()
	assert_bool(s.submit_course([_layout()])["ok"]).is_true()
	doc["course"] = encoded.value
	doc["min_reader_version"] = 3
	s.clock.pause()
	s.practice = MHPracticeRound.create(_layout(), 1234)
	var played: Dictionary = s.practice.play(0, 6000)
	assert_bool(played["ok"]).is_true()
	var cash: int = s.economy.cash
	var tokens: int = s.ledger.earned
	var saved: MHSaveResult = MHSessionSave.capture(s, doc)
	assert_bool(saved.is_ok()).is_true()
	if not saved.is_ok():
		return
	assert_int(int(saved.value["min_reader_version"])).is_equal(3)
	var restored: MHSaveResult = MHSessionSave.restore(saved.value, s.ledger)
	assert_bool(restored.is_ok()).is_true()
	if not restored.is_ok():
		return
	var r: MHGameSession = restored.value
	assert_int(r.economy.cash).is_equal(cash)
	assert_int(r.ledger.earned).is_equal(tokens)
	assert_bool(r.clock.is_paused()).is_true()
	assert_array(r.hole_definitions()).is_equal(s.hole_definitions())
	assert_array(r.hole_results()).is_equal(s.hole_results())
	assert_dict(r.practice.to_dict()).is_equal(s.practice.to_dict())
	assert_dict(r.practice.play(0, 6000)).is_equal(s.practice.play(0, 6000))

func test_practice_uses_same_flight_and_resumes_same_next_shot() -> void:
	var h: Dictionary = _layout()
	var r: MHPracticeRound = MHPracticeRound.create(h, 1234)
	var sim: MHRSim = MHRSim.new(MHRHole.from_def(h), 0, 0, 0)
	var z: PackedInt32Array = MHRParams.z256
	sim.land(0, 0, MHRHole.LIE_TEE, 0, 6000, 500, z[MHRMath.h32d(1234, 0, 1, 0) & 255],
		z[MHRMath.h32d(1234, 0, 1, 1) & 255], MHRMath.h32d(1234, 0, 1, 2) % 1000, MHRMath.h32d(1234, 0, 1, 3))
	assert_bool(r.play(0, 6000)["ok"]).is_true()
	assert_int(r.x).is_equal(-897) # Existing Python rating reference, seed1234/shot1.
	assert_int(r.y).is_equal(5352)
	assert_str(r.hole.content_hash()).is_equal("1e6e5f2349ac540a")
	assert_int(r.x).is_equal(sim.r_x)
	assert_int(r.y).is_equal(sim.r_y)
	assert_int(r.strokes).is_equal(1 + sim.r_pen)
	var restored: MHPracticeRound = MHPracticeRound.restore(h, r.to_dict())
	assert_object(restored).is_not_null()
	assert_dict(restored.play(0, 6000)).is_equal(r.play(0, 6000))
	var changed: Dictionary = h.duplicate(true)
	changed["green"][1] = 61
	assert_object(MHPracticeRound.restore(changed, r.to_dict())).is_null()

func test_individual_putt_can_hole_and_finished_round_cannot_shoot() -> void:
	var r: MHPracticeRound = MHPracticeRound.create(_layout(), 1)
	r.x = 0
	r.y = 5900
	r.lie = MHRHole.LIE_GREEN
	r.strokes = 1
	r.shot = 2
	var result: Dictionary = r.play(0, 6000)
	assert_bool(result["finished"]).is_true()
	assert_bool(result["picked_up"]).is_false()
	assert_int(r.strokes).is_equal(2)
	assert_bool(r.play(0, 6000)["ok"]).is_false()
	assert_object(MHPracticeRound.restore(_layout(), r.to_dict())).is_not_null()

func test_malformed_round_and_forged_state_rejected() -> void:
	var r: MHPracticeRound = MHPracticeRound.create(_layout(), 1)
	var d: Dictionary = r.to_dict()
	d["skill"] = 1001
	assert_object(MHPracticeRound.restore(_layout(), d)).is_null()
	d = r.to_dict()
	d["x"] = 50
	assert_object(MHPracticeRound.restore(_layout(), d)).is_null()
	d = r.to_dict()
	d["finished"] = true
	assert_object(MHPracticeRound.restore(_layout(), d)).is_null()
	d = r.to_dict()
	d["strokes"] = 1.5
	assert_object(MHPracticeRound.restore(_layout(), d)).is_null()


func test_bad_world_version_slot_and_unsupported_panel_profile_reject() -> void:
	var s: MHGameSession = MHGameSession.create()
	var source: Dictionary = _source(s)["course"]
	for key: String in ["schema_version", "world"]:
		var bad: Dictionary = source.duplicate(true)
		bad[key] = {}
		assert_bool(MHCourseLayout.decode(bad).is_ok()).is_false()
	var bad: Dictionary = source.duplicate(true)
	bad["world"]["parcels"][0]["x0"] = {}
	assert_bool(MHCourseLayout.encode([_layout()], bad, [[480, 340]]).is_ok()).is_false()
	var h: Dictionary = _layout()
	h["slot_id"] = {}
	assert_bool(MHCourseLayout.encode([h], source, [[480, 340]]).is_ok()).is_false()
	var encoded: MHSaveResult = MHCourseLayout.encode([_layout()], source, [[480, 340]])
	assert_bool(MHOneHolePanel.supported(encoded.value)).is_true()
	var different: Dictionary = encoded.value.duplicate(true)
	different["holes"][0]["origin_dm"] = [490, 340]
	assert_bool(MHOneHolePanel.supported(different)).is_false()
	h = _layout()
	h["features"] = [{"t": "fairway", "circle": [0, 30, 10]}]
	encoded = MHCourseLayout.encode([h], source, [[480, 340]])
	assert_bool(encoded.is_ok()).is_true()
	assert_bool(MHOneHolePanel.supported(encoded.value)).is_false()


func test_live_panel_finalizes_exact_canonical_craft_relief_layout() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_one_hole_canonical")
	scene.ledger_dir = "user://test_one_hole_canonical_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.session.clock.pause()
	scene.one_hole.open()
	var craft: MHCraftHole = MHCraftHole.new(24, 40)
	craft.paint_rect(10, 0, 13, 29, MHCraftHole.Surface.FAIRWAY)
	craft.paint_rect(11, 30, 12, 31, MHCraftHole.Surface.GREEN)
	craft.add_tee(11, 0)
	craft.add_pin(11, 30)
	craft.set_height_tile(11, 15, 6)
	var layout: Dictionary = MHCraftConvert.to_hole_def(craft, 0, 0, 0)
	assert_bool(layout.has("relief")).is_true()
	assert_bool(scene.one_hole.set_canonical_draft(layout)).is_true()
	scene.one_hole._finalize()
	assert_array(scene.session.hole_definitions()).contains_exactly([layout])
	assert_object(scene.session.practice).is_not_null()
	assert_str(scene.session.practice.hole.content_hash()).is_equal(MHRHole.from_def(layout).content_hash())
	var decoded: MHSaveResult = MHCourseLayout.decode(scene.document["course"] as Dictionary)
	assert_bool(decoded.is_ok()).override_failure_message(decoded.message).is_true()
	if decoded.is_ok():
		assert_array(decoded.value as Array).contains_exactly([layout])
	scene._active = false


func test_live_build_play_entry_uses_owned_canonical_craft_draft() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_one_hole_entry")
	scene.ledger_dir = "user://test_one_hole_entry_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	assert_object(scene.craft_hole).is_not_null()
	scene.craft_hole.set_height_tile(11, 15, 6)
	var expected: Dictionary = scene.canonical_craft_draft()
	assert_bool(expected.has("relief")).is_true()
	scene._open_craft_hole()
	assert_bool(scene.one_hole.visible).is_true()
	assert_dict(scene.one_hole.canonical_draft).is_equal(expected)
	scene.one_hole._finalize()
	assert_array(scene.session.hole_definitions()).contains_exactly([expected])
	scene._active = false


func test_reopening_build_play_does_not_replace_finalized_layout_with_default_craft() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_one_hole_reopen")
	scene.ledger_dir = "user://test_one_hole_reopen_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole.set_height_tile(11, 15, 6)
	var finalized: Dictionary = scene.canonical_craft_draft()
	assert_bool(scene.one_hole.set_canonical_draft(finalized)).is_true()
	scene.one_hole._finalize()
	scene.craft_hole = scene._default_craft_hole()
	scene.one_hole.hide()
	scene._open_craft_hole()
	assert_bool(scene.one_hole.canonical_draft.is_empty()).is_true()
	assert_array(scene.session.hole_definitions()).contains_exactly([finalized])
	scene._active = false


func test_live_craft_controls_mutate_authoritative_hole_and_undo_redo() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_craft_controls")
	scene.ledger_dir = "user://test_craft_controls_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene._open_craft_hole()
	var panel: MHOneHolePanel = scene.one_hole
	panel.craft_mode = &"surface"
	panel.craft_surface = MHCraftHole.Surface.BUNKER
	var before: int = scene.craft_hole.get_surface(8, 12)
	assert_bool(panel.craft_at_tile(8, 12)).is_true()
	assert_int(scene.craft_hole.get_surface(8, 12)).is_equal(MHCraftHole.Surface.BUNKER)
	assert_bool(scene.craft_hole.can_undo()).is_true()
	panel._craft_undo()
	assert_int(scene.craft_hole.get_surface(8, 12)).is_equal(before)
	panel._craft_redo()
	assert_int(scene.craft_hole.get_surface(8, 12)).is_equal(MHCraftHole.Surface.BUNKER)
	panel.craft_mode = &"raise"
	var z: int = scene.craft_hole.get_height(11, 15)
	assert_bool(panel.craft_at_tile(11, 15)).is_true()
	assert_int(scene.craft_hole.get_height(11, 15)).is_equal(z + 1)
	assert_bool(panel.canonical_draft.has("relief")).is_true()
	scene._active = false

func test_live_craft_tee_and_pin_tools_update_canonical_draft() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_craft_markers")
	scene.ledger_dir = "user://test_craft_markers_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene._open_craft_hole()
	var panel: MHOneHolePanel = scene.one_hole
	panel.craft_mode = &"tee"
	assert_bool(panel.craft_at_tile(12, 1)).is_true()
	assert_array(scene.craft_hole.tees).contains_exactly([Vector2i(12, 1)])
	panel.craft_mode = &"pin"
	assert_bool(panel.craft_at_tile(11, 31)).is_true()
	assert_bool(scene.craft_hole.pins.has(Vector2i(11, 31))).is_true()
	assert_bool(panel.canonical_draft.is_empty()).is_false()
	assert_dict(panel.canonical_draft).is_equal(scene.canonical_craft_draft())
	scene._active = false


func test_live_preview_ground_height_matches_rating_relief() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_craft_relief_render")
	scene.ledger_dir = "user://test_craft_relief_render_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole.set_height_tile(11, 15, 6)
	scene._open_craft_hole()
	var layout: Dictionary = scene.canonical_craft_draft()
	var hole: MHRHole = MHRHole.from_def(layout)
	var centre: Vector2i = scene.craft_hole.tile_centre_yd(11, 15)
	var cx: int = centre.x * 100
	var cy: int = centre.y * 100
	assert_float(scene.one_hole._ground_height(cx, cy)).is_equal_approx(float(hole.z_at(cx, cy)) / 1000.0, 0.001)
	assert_float(scene.one_hole._ground_height(cx, cy)).is_equal_approx(6.0, 0.001)
	scene._active = false


func test_craft_preview_builds_surface_meshes_and_positioned_trees() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_craft_mesh")
	scene.ledger_dir = "user://test_craft_mesh_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole.set_height_tile(11, 15, 6)
	scene.craft_hole.add_tree_yd(6, 20)
	scene._open_craft_hole()
	var mesh_count: int = 0
	for child: Node in scene.one_hole._world.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
	assert_bool(mesh_count >= scene.craft_hole.cols * scene.craft_hole.rows).is_true()
	var tree_ground: float = scene.one_hole._ground_height(600, 2000)
	assert_float(tree_ground).is_equal_approx(float(MHRHole.from_def(scene.canonical_craft_draft()).z_at(600, 2000)) / 1000.0, 0.001)
	scene._active = false
