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
	assert_int(int(saved.value["min_reader_version"])).is_equal(6)
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


func test_bad_world_version_slot_and_panel_origin_reject() -> void:
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
	assert_bool(MHOneHolePanel.supported(different)).is_true()
	h = _layout()
	h["features"] = [{"t": "fairway", "circle": [0, 30, 10]}]
	encoded = MHCourseLayout.encode([h], source, [[480, 340]])
	assert_bool(encoded.is_ok()).is_true()
	assert_bool(MHOneHolePanel.supported(encoded.value)).is_false()

	var craft: MHCraftHole = MHCraftHole.new(24, 40)
	craft.paint_rect(10, 0, 13, 29, MHCraftHole.Surface.FAIRWAY)
	craft.paint_rect(9, 30, 14, 35, MHCraftHole.Surface.GREEN)
	craft.add_tee(11, 0)
	craft.add_pin(11, 30)
	craft.set_height_tile(11, 15, 6)
	var relief_layout: Dictionary = MHCraftConvert.to_hole_def(craft, 0, 0, 0)
	encoded = MHCourseLayout.encode([relief_layout], source, [[480, 340]])
	assert_bool(encoded.is_ok()).is_true()
	assert_bool(MHOneHolePanel.supported(encoded.value)).is_true()


func test_live_panel_finalizes_exact_canonical_craft_relief_layout() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_one_hole_canonical")
	scene.ledger_dir = "user://test_one_hole_canonical_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.session.clock.pause()
	var craft: MHCraftHole = MHCraftHole.new(24, 40)
	craft.paint_rect(10, 0, 13, 29, MHCraftHole.Surface.FAIRWAY)
	craft.paint_rect(9, 30, 14, 35, MHCraftHole.Surface.GREEN)
	craft.add_tee(11, 0)
	craft.add_pin(11, 30)
	craft.set_height_tile(11, 15, 6)
	scene.craft_hole = craft
	var layout: Dictionary = MHCraftConvert.to_hole_def(craft, 0, 0, 0)
	assert_bool(layout.has("relief")).is_true()
	assert_bool(scene.one_hole.set_canonical_draft(layout)).is_true()
	scene.one_hole._finalize()
	var defs: Array = scene.session.hole_definitions()
	assert_int(defs.size()).is_equal(3)
	assert_dict(defs[0] as Dictionary).is_equal(layout)
	assert_object(scene.session.practice).is_not_null()
	assert_str(scene.session.practice.hole.content_hash()).is_equal(MHRHole.from_def(layout).content_hash())
	var decoded: MHSaveResult = MHCourseLayout.decode(scene.document["course"] as Dictionary)
	assert_bool(decoded.is_ok()).override_failure_message(decoded.message).is_true()
	if decoded.is_ok():
		assert_array(decoded.value as Array).is_equal(defs)
	scene._active = false


func test_canonical_craft_draft_rotates_pins_by_round() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_craft_pin_rotation")
	scene.ledger_dir = "user://test_craft_pin_rotation_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole.pins.clear()
	scene.craft_hole.add_pin(11, 30)
	scene.craft_hole.add_pin(12, 31)
	var p0: Vector2i = scene.craft_hole.tile_centre_yd(11, 30)
	var p1: Vector2i = scene.craft_hole.tile_centre_yd(12, 31)
	var r0: Dictionary = scene.canonical_craft_draft(0)
	var r1: Dictionary = scene.canonical_craft_draft(1)
	var g0: Array = r0["green"] as Array
	var g1: Array = r1["green"] as Array
	assert_int(int(g0[0])).is_equal(p0.x)
	assert_int(int(g0[1])).is_equal(p0.y)
	assert_int(int(g1[0])).is_equal(p1.x)
	assert_int(int(g1[1])).is_equal(p1.y)
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
	var defs: Array = scene.session.hole_definitions()
	assert_int(defs.size()).is_equal(3)
	assert_dict(defs[0] as Dictionary).is_equal(expected)
	scene._active = false


func test_entering_normal_editor_immediately_owns_world_input() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_editor_input_handoff")
	scene.ledger_dir = "user://test_editor_input_handoff_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.shell.push_screen(MHScreenIds.EDITOR)
	await get_tree().process_frame
	assert_str(scene.shell.current_screen_id()).is_equal(MHScreenIds.EDITOR)
	assert_bool(scene.router.accept_world_input).is_true()
	assert_int(scene.editor.brush_mode).is_equal(MHBrush.Mode.RAISE)
	assert_int(scene.editor.brush_radius).is_equal(MHEditorTools.RADIUS_DEFAULT)
	scene._active = false


func test_one_hole_mode_has_real_panel_area_and_editor_navigation_closes_it() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_one_hole_layout_mode")
	scene.ledger_dir = "user://test_one_hole_layout_mode_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene._open_craft_hole()
	await get_tree().process_frame
	scene._relayout()
	assert_bool(scene.one_hole.visible).is_true()
	assert_bool(scene.one_hole._scroll.visible).is_true()
	assert_float(scene._panel_frame.size.y).is_greater(MHLiveLayout.panel_header_height(scene.shell.ctx.touch_min()))
	assert_float(scene._panel_frame.size.x).is_greater(200.0)
	scene.shell.push_screen(MHScreenIds.EDITOR)
	await get_tree().process_frame
	assert_bool(scene.one_hole.visible).is_false()
	assert_bool(scene.chunks.visible).is_true()
	assert_bool(scene.router.accept_world_input).is_true()
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
	var defs: Array = scene.session.hole_definitions()
	assert_int(defs.size()).is_equal(3)
	assert_dict(defs[0] as Dictionary).is_equal(finalized)
	scene._active = false


func test_normal_editor_and_build_play_share_water_path_and_height() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_shared_craft_world")
	scene.ledger_dir = "user://test_shared_craft_world_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	var tile: Vector2i = Vector2i(8, 12)
	var centre: Vector2i = scene.craft_hole.tile_centre_yd(tile.x, tile.y)
	var origin: Vector2i = scene.craft_origin_dm()
	var sx: int = MHRMath.rdiv(MHCourseLayout.world_mm(origin.x, centre.x * 100), scene.editor.grid.cell_size_mm)
	var sy: int = MHRMath.rdiv(MHCourseLayout.world_mm(origin.y, centre.y * 100), scene.editor.grid.cell_size_mm)

	# Edit through the normal world terrain path.
	scene.editor.set_paint_brush(MHSplatMap.Layer.WATER, 1, 1000)
	scene.editor.begin_stroke()
	scene.editor.apply_brush_at(sx, sy)
	scene.editor.end_stroke()
	scene.editor.set_brush(MHBrush.Mode.RAISE, 1, 700)
	scene.editor.begin_stroke()
	scene.editor.apply_brush_at(sx, sy)
	scene.editor.end_stroke()
	assert_int(scene.craft_hole.get_surface(tile.x, tile.y)).is_equal(MHCraftHole.Surface.WATER)
	assert_int(scene.craft_hole.get_height_mm(tile.x, tile.y)).is_equal(700)

	# Reopening Build/play must show the same authoritative craft state.
	scene._open_craft_hole()
	assert_int(scene.craft_hole.get_surface(tile.x, tile.y)).is_equal(MHCraftHole.Surface.WATER)
	assert_int(roundi(scene.one_hole._ground_height(centre.x * 100, centre.y * 100) * 1000.0)).is_equal(700)

	# Edit back through Build/play; the persisted world splat changes too.
	scene.one_hole.craft_mode = &"surface"
	scene.one_hole.craft_surface = MHCraftHole.Surface.PATH
	assert_bool(scene.one_hole.craft_at_tile(tile.x, tile.y)).is_true()
	assert_int(scene.editor.splat.get_weight(sx, sy, MHSplatMap.Layer.PATH)).is_equal(255)
	assert_int(scene.editor.splat.get_weight(sx, sy, MHSplatMap.Layer.WATER)).is_equal(0)
	scene._active = false


func test_fresh_scene_stamps_all_starter_holes_into_shared_world() -> void:
	var run_id: String = str(Time.get_ticks_usec())
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_multi_hole_world_seed_" + run_id)
	scene.ledger_dir = "user://test_multi_hole_world_seed_ledger_" + run_id
	add_child(scene)
	assert_bool(scene._active).is_true()
	for i: int in range(MHCraftCourse.NIGHT_SLICE_HOLES):
		assert_bool(scene.select_craft_hole(i)).is_true()
		var fairway_tile: Vector2i = Vector2i(-1, -1)
		for r: int in range(scene.craft_hole.rows):
			for col: int in range(scene.craft_hole.cols):
				if scene.craft_hole.get_surface(col, r) == MHCraftHole.Surface.FAIRWAY:
					fairway_tile = Vector2i(col, r)
					break
			if fairway_tile.x >= 0:
				break
		assert_bool(fairway_tile.x >= 0).is_true()
		var centre: Vector2i = scene.craft_hole.tile_centre_yd(fairway_tile.x, fairway_tile.y)
		var origin: Vector2i = scene.craft_origin_dm()
		var sx: int = MHRMath.rdiv(MHCourseLayout.world_mm(origin.x, centre.x * 100), scene.editor.grid.cell_size_mm)
		var sy: int = MHRMath.rdiv(MHCourseLayout.world_mm(origin.y, centre.y * 100), scene.editor.grid.cell_size_mm)
		assert_int(scene.editor.splat.get_weight(sx, sy, MHSplatMap.Layer.FAIRWAY)).is_equal(255)
	scene._active = false


func test_repairing_water_at_pin_keeps_existing_green_inside_owned_land() -> void:
	var run_id: String = str(Time.get_ticks_usec())
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_green_repair_" + run_id)
	scene.ledger_dir = "user://test_green_repair_ledger_" + run_id
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene._open_craft_hole()
	var original_radius: int = MHCraftConvert.green_radius_yd(scene.craft_hole)
	assert_int(original_radius).is_equal(6)
	var pin: Vector2i = scene.craft_hole.pins[0] as Vector2i
	scene.one_hole.craft_mode = &"surface"
	scene.one_hole.craft_surface = MHCraftHole.Surface.WATER
	assert_bool(scene.one_hole.craft_at_tile(pin.x, pin.y)).is_true()
	assert_bool(MHCraftConvert.problems(scene.craft_hole).has("pin_not_on_green")).is_true()
	scene.one_hole._repair_hole_markers()
	assert_int(MHCraftConvert.green_radius_yd(scene.craft_hole)).is_equal(original_radius)
	assert_array(MHCraftConvert.problems(scene.craft_hole)).is_empty()
	var layout: Dictionary = scene.canonical_craft_draft()
	var origin: Vector2i = scene.craft_origin_dm()
	var encoded: MHSaveResult = MHCourseLayout.encode([layout],
		scene.document["course"] as Dictionary, [[origin.x, origin.y]])
	assert_bool(encoded.is_ok()).override_failure_message(encoded.message).is_true()
	scene.one_hole._finalize()
	assert_int(scene.session.hole_definitions().size()).is_equal(3)
	scene._active = false


func test_green_repair_expands_only_a_genuinely_small_green() -> void:
	var run_id: String = str(Time.get_ticks_usec())
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_small_green_repair_" + run_id)
	scene.ledger_dir = "user://test_small_green_repair_ledger_" + run_id
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole = MHCraftHole.new(24, 40)
	scene.craft_hole.paint_rect(10, 0, 13, 29, MHCraftHole.Surface.FAIRWAY)
	scene.craft_hole.paint_rect(11, 30, 12, 31, MHCraftHole.Surface.GREEN)
	scene.craft_hole.add_tee(11, 0)
	scene.craft_hole.add_pin(11, 30)
	scene.one_hole.enter_craft_draft()
	assert_int(MHCraftConvert.green_radius_yd(scene.craft_hole)).is_equal(2)
	scene.one_hole._repair_hole_markers()
	assert_bool(MHCraftConvert.green_radius_yd(scene.craft_hole) >= 5).is_true()
	assert_array(MHCraftConvert.problems(scene.craft_hole)).is_empty()
	var layout: Dictionary = scene.canonical_craft_draft()
	var origin: Vector2i = scene.craft_origin_dm()
	var encoded: MHSaveResult = MHCourseLayout.encode([layout],
		scene.document["course"] as Dictionary, [[origin.x, origin.y]])
	assert_bool(encoded.is_ok()).override_failure_message(encoded.message).is_true()
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


func test_relief_aware_screen_pick_hits_the_visible_craft_tile() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_craft_relief_pick")
	scene.ledger_dir = "user://test_craft_relief_pick_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole.set_height_tile(11, 15, 6)
	scene._open_craft_hole()
	var centre: Vector2i = scene.craft_hole.tile_centre_yd(11, 15)
	var world: Vector3 = scene.one_hole._position_on_ground(centre.x * 100, centre.y * 100, 0.0)
	var screen: Vector2 = scene.controller.camera.unproject_position(world)
	assert_bool(scene.one_hole._craft_tile_from_screen(screen) == Vector2i(11, 15)).is_true()
	scene._active = false


func test_drag_craft_edit_is_one_undoable_stroke() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_craft_drag_stroke")
	scene.ledger_dir = "user://test_craft_drag_stroke_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene._open_craft_hole()
	var panel: MHOneHolePanel = scene.one_hole
	panel.craft_mode = &"surface"
	panel.craft_surface = MHCraftHole.Surface.BUNKER
	var a: Vector2i = scene.craft_hole.tile_centre_yd(8, 12)
	var b: Vector2i = scene.craft_hole.tile_centre_yd(10, 12)
	var sa: Vector2 = scene.controller.camera.unproject_position(panel._position_on_ground(a.x * 100, a.y * 100, 0.0))
	var sb: Vector2 = scene.controller.camera.unproject_position(panel._position_on_ground(b.x * 100, b.y * 100, 0.0))
	var before_undo: int = scene.craft_hole.undo_count()
	assert_bool(panel.craft_stroke_begin_from_screen(sa)).is_true()
	assert_bool(panel.craft_stroke_move_from_screen(sb)).is_true()
	assert_bool(panel.craft_stroke_end()).is_true()
	assert_int(scene.craft_hole.undo_count()).is_equal(before_undo + 1)
	assert_int(scene.craft_hole.get_surface(8, 12)).is_equal(MHCraftHole.Surface.BUNKER)
	assert_int(scene.craft_hole.get_surface(10, 12)).is_equal(MHCraftHole.Surface.BUNKER)
	assert_bool(scene.craft_hole.undo()).is_true()
	assert_bool(scene.craft_hole.get_surface(8, 12) != MHCraftHole.Surface.BUNKER).is_true()
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
	assert_bool(mesh_count > 0).is_true()
	assert_bool(mesh_count < scene.craft_hole.cols * scene.craft_hole.rows).is_true()
	var tree_ground: float = scene.one_hole._ground_height(600, 2000)
	assert_float(tree_ground).is_equal_approx(float(MHRHole.from_def(scene.canonical_craft_draft()).z_at(600, 2000)) / 1000.0, 0.001)
	scene._active = false


func test_craft_relief_normal_is_not_flat_on_slope() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new("user://test_craft_normals")
	scene.ledger_dir = "user://test_craft_normals_ledgers"
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole.set_height_tile(11, 15, 6)
	scene._open_craft_hole()
	var hole: MHRHole = MHRHole.from_def(scene.canonical_craft_draft())
	var centre: Vector2i = scene.craft_hole.tile_centre_yd(11, 15)
	var n: Vector3 = scene.one_hole._craft_normal(hole, centre.x * 100, centre.y * 100)
	assert_bool(n.is_normalized()).is_true()
	assert_bool(absf(n.x) > 0.001 or absf(n.z) > 0.001).is_true()
	assert_bool(n.y > 0.0).is_true()
	scene._active = false

func test_craft_water_material_is_transparent_and_low_roughness() -> void:
	var panel: MHOneHolePanel = auto_free(MHOneHolePanel.new())
	var material: StandardMaterial3D = panel._craft_material(MHCraftHole.Surface.WATER)
	assert_int(material.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_bool(material.albedo_color.a < 1.0).is_true()
	assert_bool(material.roughness < 0.5).is_true()


func test_visual_quality_tiers_preserve_gameplay() -> void:
	var low: Dictionary = MHVisualQuality.settings(MHVisualQuality.Tier.LOW)
	var medium: Dictionary = MHVisualQuality.settings(MHVisualQuality.Tier.MEDIUM)
	var high: Dictionary = MHVisualQuality.settings(MHVisualQuality.Tier.HIGH)
	assert_bool(bool(low["mowing"])).is_true()
	assert_int(int(low["tree_layers"])).is_less(int(medium["tree_layers"]))
	assert_int(int(medium["tree_layers"])).is_less_equal(int(high["tree_layers"]))
	assert_bool(bool(low["shadows"])).is_false()
	assert_bool(bool(medium["shadows"])).is_true()
	assert_str(MHVisualQuality.name_for(MHVisualQuality.Tier.HIGH)).is_equal("High")


func test_course_dressing_meshes_fit_mobile_budgets() -> void:
	for kind: String in ["bush", "rock_cluster", "flower_patch", "reeds"]:
		for lod: int in range(MHNatureMeshes.LOD_COUNT):
			var mesh: ArrayMesh = MHNatureMeshes.build(kind, lod, 0)
			assert_bool(mesh.get_surface_count() > 0).is_true()
			assert_int(MHMeshBuilder.mesh_tri_count(mesh)).is_less_equal(MHNatureMeshes.budget(kind, lod))
	for kind: String in ["flag", "tee_marker", "sign", "bench", "bin"]:
		for lod: int in range(MHPropMeshes.LOD_COUNT):
			var mesh: ArrayMesh = MHPropMeshes.build(kind, lod, 0)
			assert_bool(mesh.get_surface_count() > 0).is_true()
			assert_int(MHMeshBuilder.mesh_tri_count(mesh)).is_less_equal(MHPropMeshes.budget(kind, lod))


func test_visual_quality_keeps_course_readability_features() -> void:
	var low: Dictionary = MHVisualQuality.settings(MHVisualQuality.Tier.LOW)
	var medium: Dictionary = MHVisualQuality.settings(MHVisualQuality.Tier.MEDIUM)
	var high: Dictionary = MHVisualQuality.settings(MHVisualQuality.Tier.HIGH)
	assert_bool(bool(low["mowing"])).is_true()
	assert_bool(bool(low["edge_accents"])).is_false()
	assert_bool(bool(medium["edge_accents"])).is_true()
	assert_bool(bool(high["terrain_detail"])).is_true()
	assert_bool(float(low["decor_density"]) < float(medium["decor_density"])).is_true()
	assert_bool(float(medium["decor_density"]) < float(high["decor_density"])).is_true()

func test_three_craft_holes_have_distinct_persisted_world_origins() -> void:
	var course: MHCraftCourse = MHCraftCourse.new()
	course.ensure_holes(3)
	var origins: Dictionary = {}
	for i: int in range(3):
		var origin: Vector2i = course.origin(i)
		assert_bool(origins.has(origin)).is_false()
		origins[origin] = true
	var restored: MHCraftCourse = MHCraftCourse.from_dict(course.to_dict())
	assert_object(restored).is_not_null()
	for i: int in range(3):
		assert_bool(restored.origin(i) == course.origin(i)).is_true()

func test_legacy_craft_course_migrates_to_distinct_default_origins() -> void:
	var course: MHCraftCourse = MHCraftCourse.new()
	course.ensure_holes(3)
	var raw: Dictionary = course.to_dict()
	raw["v"] = MHCraftCourse.LEGACY_VERSION
	raw.erase("origins_dm")
	var restored: MHCraftCourse = MHCraftCourse.from_dict(raw)
	assert_object(restored).is_not_null()
	assert_bool(restored.origin(0) != restored.origin(1)).is_true()
	assert_bool(restored.origin(1) != restored.origin(2)).is_true()

func test_three_default_holes_encode_on_owned_land_without_overlap() -> void:
	var session: MHGameSession = MHGameSession.create()
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.session = session
	var course_doc: Dictionary = scene._new_document()["course"] as Dictionary
	var craft: MHCraftCourse = MHCraftCourse.new()
	craft.ensure_holes(3)
	var defs: Array = craft.valid_hole_defs()
	var origins: Array = []
	for i: int in range(3):
		var origin: Vector2i = craft.origin(i)
		origins.append([origin.x, origin.y])
	var encoded: MHSaveResult = MHCourseLayout.encode(defs, course_doc, origins)
	assert_bool(encoded.is_ok()).override_failure_message(encoded.message).is_true()
	if encoded.is_ok():
		assert_array(MHCourseLayout.origins(encoded.value as Dictionary)).is_equal(origins)

func test_six_default_holes_fit_initially_owned_golf_land_without_overlap() -> void:
	var session: MHGameSession = MHGameSession.create()
	assert_int(session.land.hole_capacity()).is_equal(6)
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.session = session
	var course_doc: Dictionary = scene._new_document()["course"] as Dictionary
	# Exclude the starter facility parcel from this geometry proof: the six holes must fit golf land alone.
	for parcel_value: Variant in (course_doc["world"] as Dictionary)["parcels"]:
		var parcel: Dictionary = parcel_value as Dictionary
		var parcel_id: int = int(parcel["parcel_id"])
		parcel["owned"] = session.land.is_owned(parcel_id) and session.land.kind_of(parcel_id) == "golf"
	var craft: MHCraftCourse = MHCraftCourse.new()
	craft.ensure_holes(6)
	var defs: Array = craft.valid_hole_defs()
	var origins: Array = []
	for i: int in range(craft.count()):
		var origin: Vector2i = craft.origin(i)
		origins.append([origin.x, origin.y])
	var encoded: MHSaveResult = MHCourseLayout.encode(defs, course_doc, origins)
	assert_bool(encoded.is_ok()).override_failure_message(encoded.message).is_true()


func test_all_eighteen_default_holes_fit_golf_land_without_overlap() -> void:
	var session: MHGameSession = MHGameSession.create()
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.session = session
	var course_doc: Dictionary = scene._new_document()["course"] as Dictionary
	# Isolate the geometry contract: only golf parcels count as buildable here.
	# Facility and homes parcels remain unowned so a default hole cannot depend on them accidentally.
	for parcel_value: Variant in (course_doc["world"] as Dictionary)["parcels"]:
		var parcel: Dictionary = parcel_value as Dictionary
		parcel["owned"] = session.land.kind_of(int(parcel["parcel_id"])) == "golf"
	var craft: MHCraftCourse = MHCraftCourse.new()
	craft.ensure_holes(MHCraftCourse.MAX_HOLES)
	var defs: Array = craft.valid_hole_defs()
	assert_int(defs.size()).is_equal(MHCraftCourse.MAX_HOLES)
	var origins: Array = []
	for i: int in range(craft.count()):
		var origin: Vector2i = craft.origin(i)
		origins.append([origin.x, origin.y])
	var encoded: MHSaveResult = MHCourseLayout.encode(defs, course_doc, origins)
	assert_bool(encoded.is_ok()).override_failure_message(encoded.message).is_true()
	if encoded.is_ok():
		assert_array(MHCourseLayout.origins(encoded.value as Dictionary)).is_equal(origins)


func test_course_codec_rejects_overlapping_hole_geometry() -> void:
	var session: MHGameSession = MHGameSession.create()
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.session = session
	var course_doc: Dictionary = scene._new_document()["course"] as Dictionary
	var craft: MHCraftCourse = MHCraftCourse.new()
	craft.ensure_holes(2)
	var defs: Array = craft.valid_hole_defs()
	var origin: Vector2i = craft.origin(0)
	var encoded: MHSaveResult = MHCourseLayout.encode(defs, course_doc,
		[[origin.x, origin.y], [origin.x, origin.y]])
	assert_bool(encoded.is_ok()).is_false()
	assert_str(encoded.message).is_equal("hole geometry overlaps another hole")

func test_legacy_terrain_expansion_preserves_existing_samples_exactly() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	var old_grid: MHHeightGrid = MHHeightGrid.new(128, 128, 1000)
	var old_splat: MHSplatMap = MHSplatMap.new(old_grid.samples_x, old_grid.samples_y)
	old_grid.set_h(17, 23, 1450)
	var texel: int = 23 * old_splat.samples_x + 17
	for layer: int in range(MHSplatMap.LAYER_COUNT):
		old_splat.bytes[texel * MHSplatMap.LAYER_COUNT + layer] = 0
	old_splat.bytes[texel * MHSplatMap.LAYER_COUNT + MHSplatMap.Layer.WATER] = 255
	var expanded: Dictionary = scene._expand_legacy_terrain(old_grid, old_splat)
	var grid: MHHeightGrid = expanded["grid"] as MHHeightGrid
	var splat: MHSplatMap = expanded["splat"] as MHSplatMap
	assert_int(grid.cells_x).is_equal(MHLiveConstruction.CELLS)
	assert_int(grid.cells_y).is_equal(MHLiveConstruction.CELLS)
	assert_int(grid.get_h(17, 23)).is_equal(1450)
	assert_int(splat.get_weight(17, 23, MHSplatMap.Layer.WATER)).is_equal(255)
	assert_int(splat.get_weight(17, 23, MHSplatMap.Layer.ROUGH)).is_equal(0)
	# Newly-added land is clean rough, not a stretched copy of an old edge.
	assert_int(grid.get_h(180, 180)).is_equal(0)
	assert_int(splat.get_weight(180, 180, MHSplatMap.Layer.ROUGH)).is_equal(255)

func test_legacy_stacked_finalized_course_remains_readable_but_cannot_be_reencoded_overlapping() -> void:
	var session: MHGameSession = MHGameSession.create()
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.session = session
	var course: Dictionary = scene._new_document()["course"] as Dictionary
	var craft: MHCraftCourse = MHCraftCourse.new()
	craft.ensure_holes(3)
	var defs: Array = craft.valid_hole_defs()
	course["schema_version"] = 2
	course["rating_engine_version"] = MHRatingEngine.RATING_VERSION
	course["holes"] = []
	for i: int in range(defs.size()):
		course["holes"].append({"hole_no": i + 1, "origin_dm": [960, 560],
			"layout": (defs[i] as Dictionary).duplicate(true)})
	assert_bool(MHCourseLayout.decode(course).is_ok()).is_true()
	var rejected: MHSaveResult = MHCourseLayout.encode(defs, course,
		[[960, 560], [960, 560], [960, 560]])
	assert_bool(rejected.is_ok()).is_false()
	assert_str(rejected.message).is_equal("hole geometry overlaps another hole")
