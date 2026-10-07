extends GdUnitTestSuite
## Official-slot accounting round trips and inconsistent/corrupt checkpoint rejection.
const Fixture = preload("res://tests/save/save_fixture.gd")
const DIR: String = "user://test_live_session_slots"
const LEDGERS: String = "user://test_live_session_ledgers"

func after_test() -> void:
	MHSaveStore.fault_point = MHSaveStore.FaultPoint.NONE
	Fixture.wipe_dir(DIR)
	Fixture.wipe_dir(LEDGERS)

func _document(s: MHGameSession) -> Dictionary:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.session = s
	return scene._new_document()

func _checkpoint(s: MHGameSession) -> Dictionary:
	var result: MHSaveResult = MHSessionSave.capture(s, _document(s))
	assert_bool(result.is_ok()).is_true()
	return result.value as Dictionary

func test_exact_money_clock_land_progress_and_tiers_round_trip() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.cash = 1234567
	s.economy.total_revenue = 7654321
	s.economy.arrears = 123
	s.economy.loan_balance = 98765
	s.economy.members_milli = 12345
	s.economy.carry_milli = 987
	s.advance(1000000, 20000 * 86400)
	s.clock.pause()
	var parcel: int = s.land.recommended_next()
	s.handle_intent(&"buy_parcel", {"parcel": parcel})
	s.handle_intent(&"buy_tier", {"building": "clubhouse", "tier": 1})
	var checkpoint: Dictionary = _checkpoint(s)
	var parsed: MHSaveResult = MHSaveGame.parse_bytes(MHSaveGame.to_bytes(checkpoint))
	assert_bool(parsed.is_ok()).is_true()
	var loaded: MHSaveResult = MHSessionSave.restore(parsed.value as Dictionary, s.ledger)
	assert_bool(loaded.is_ok()).is_true()
	var restored: MHGameSession = loaded.value as MHGameSession
	assert_dict(restored.economy.to_dict()).is_equal(s.economy.to_dict())
	assert_dict(restored.clock.to_dict()).is_equal(s.clock.to_dict())
	assert_array(Array(restored.land.owned_ids())).contains_exactly(Array(s.land.owned_ids()))
	assert_dict(restored.bridge.to_save_progress()).is_equal(s.bridge.to_save_progress())
	assert_dict(restored.customers.to_dict()).is_equal(s.customers.to_dict())
	assert_dict(restored.staff.to_save_block()).is_equal(s.staff.to_save_block())
	assert_int(int(checkpoint["min_reader_version"])).is_equal(6)

func test_future_hour_cash_and_building_disagreements_are_rejected() -> void:
	var s: MHGameSession = MHGameSession.create()
	var base: Dictionary = _checkpoint(s)
	for field: String in ["clock", "cash", "tiers", "land", "world", "parcel"]:
		var doc: Dictionary = base.duplicate(true)
		if field == "clock": doc["runtime"]["clock"]["total_minutes"] = 60
		elif field == "cash": doc["club"]["cash"] += 1
		elif field == "tiers": doc["buildings"][0]["tier"] = 1
		elif field == "land": doc["runtime"]["economy"]["parcels"] = 6
		elif field == "world": doc["world"]["minute_of_day"] = 60
		else: doc["course"]["world"]["parcels"][0]["owned"] = not doc["course"]["world"]["parcels"][0]["owned"]
		MHSaveGame.seal(doc)
		assert_bool(MHSessionSave.restore(doc, s.ledger).is_ok()).is_false()
	assert_int(s.clock.total_minutes()).is_equal(0)

func test_runtime_schema_rejects_bad_types_ranges_and_old_reader() -> void:
	var base: Dictionary = _checkpoint(MHGameSession.create())
	for kind: String in ["fraction", "missing", "negative", "period", "reader", "tokens", "version"]:
		var doc: Dictionary = base.duplicate(true)
		if kind == "fraction": doc["runtime"]["economy"]["cash"] = 1.5
		elif kind == "missing": doc["runtime"]["economy"].erase("arrears")
		elif kind == "negative": doc["runtime"]["economy"]["loan_balance"] = -1
		elif kind == "period": doc["runtime"]["clock"]["real_us_per_day"] = 100
		elif kind == "reader": doc["min_reader_version"] = 1
		elif kind == "tokens": doc["runtime"]["earned"] = 100
		else: doc["runtime"]["v"] = 2
		MHSaveGame.seal(doc)
		assert_bool(MHSessionSave.restore(doc, MHTokenLedger.new()).is_ok()).is_false()

func test_legacy_slot_stays_readable_but_is_not_silently_reinitialized() -> void:
	var doc: Dictionary = Fixture.make_doc()
	MHSaveGame.seal(doc)
	assert_bool(MHSaveGame.parse_bytes(MHSaveGame.to_bytes(doc)).is_ok()).is_true()
	assert_bool(MHSessionSave.restore(doc, MHTokenLedger.new()).is_ok()).is_false()

func test_existing_holes_cannot_be_erased_by_construction_checkpoint() -> void:
	var s: MHGameSession = MHGameSession.create()
	var doc: Dictionary = _document(s)
	doc["course"]["holes"] = [{"hole_no": 1}]
	assert_bool(MHSessionSave.capture(s, doc).is_ok()).is_false()
	assert_int((doc["course"]["holes"] as Array).size()).is_equal(1)

func test_separate_ledger_generations_survive_failed_world_write() -> void:
	var s: MHGameSession = MHGameSession.create()
	var doc: Dictionary = _checkpoint(s)
	var hash_value: String = str(doc["runtime"]["ledger_hash"])
	assert_int(s.ledger.save_to(LEDGERS + "/" + hash_value + ".json")).is_equal(OK)
	var store: MHSaveStore = MHSaveStore.new(DIR)
	var terrain: MHHeightGrid = MHHeightGrid.new(128, 128, 1000)
	var splat: MHSplatMap = MHSplatMap.new(129, 129)
	var blob: PackedByteArray = MHTerrainSave.encode(terrain, splat)
	assert_bool(store.autosave(doc, blob, 12345).is_ok()).is_true()
	# A newer token generation is written, but the next world write fails before committing.
	s.ledger.grant_earned("daily_login", "20000")
	var newer: Dictionary = _checkpoint(s)
	var new_hash: String = str(newer["runtime"]["ledger_hash"])
	assert_int(s.ledger.save_to(LEDGERS + "/" + new_hash + ".json")).is_equal(OK)
	assert_bool(store.autosave(newer, PackedByteArray(), 12346).is_ok()).is_false()
	var loaded: MHSaveResult = store.load_slot(0)
	assert_bool(loaded.is_ok()).is_true()
	var old: MHLoadedSave = loaded.value as MHLoadedSave
	var ledger: MHSaveResult = MHSessionSave.load_ledger(old.data, LEDGERS)
	assert_bool(ledger.is_ok()).is_true()
	assert_bool(MHSessionSave.restore(old.data, ledger.value as MHTokenLedger).is_ok()).is_true()
	assert_bool(MHSessionSave.restore(old.data, s.ledger).is_ok()).is_false()

func test_corrupt_checksum_and_missing_ledger_reject() -> void:
	var s: MHGameSession = MHGameSession.create()
	var doc: Dictionary = _checkpoint(s)
	assert_bool(MHSessionSave.load_ledger(doc, LEDGERS).is_ok()).is_false()
	doc["runtime"]["economy"]["cash"] += 1
	assert_bool(MHSessionSave.restore(doc, s.ledger).is_ok()).is_false()


func test_paint_only_torn_write_recovers_matching_full_snapshot() -> void:
	var s: MHGameSession = MHGameSession.create()
	var doc: Dictionary = _checkpoint(s)
	var store: MHSaveStore = MHSaveStore.new(DIR)
	var grid: MHHeightGrid = MHHeightGrid.new(128, 128, 1000)
	var splat: MHSplatMap = MHSplatMap.new(129, 129)
	var before: PackedByteArray = MHTerrainSave.encode(grid, splat)
	assert_bool(store.autosave(doc, before, 100).is_ok()).is_true()
	var height_hash: int = grid.hash_fnv1a()
	splat.paint_disc(64, 64, 8, MHSplatMap.Layer.WATER, 1000)
	var painted: PackedByteArray = MHTerrainSave.encode(grid, splat)
	assert_int(grid.hash_fnv1a()).is_equal(height_hash)
	assert_str(MHSaveStore.blob_digest(painted)).is_not_equal(MHSaveStore.blob_digest(before))
	MHSaveStore.fault_point = MHSaveStore.FaultPoint.AFTER_BLOB_WRITTEN
	assert_bool(store.autosave(doc, painted, 101).is_ok()).is_false()
	MHSaveStore.fault_point = MHSaveStore.FaultPoint.NONE
	var loaded: MHSaveResult = store.load_slot(0)
	assert_bool(loaded.is_ok()).is_true()
	var recovered: MHLoadedSave = loaded.value as MHLoadedSave
	assert_bool(recovered.recovered).is_true()
	assert_bool(recovered.blob == before).is_true()
	assert_int(int(recovered.data["saved_at_unix"])).is_equal(100)


func test_malformed_capture_sources_reject_without_indexing_bad_shapes() -> void:
	var s: MHGameSession = MHGameSession.create()
	for key: String in ["club", "world", "sim", "progress", "course"]:
		var doc: Dictionary = _document(s)
		doc[key] = []
		assert_bool(MHSessionSave.capture(s, doc).is_ok()).is_false()
	var doc: Dictionary = _document(s)
	doc["course"]["world"] = {}
	assert_bool(MHSessionSave.capture(s, doc).is_ok()).is_false()


func test_live_scene_routes_pause_paint_history_purchase_and_reload() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.shell.push_screen(MHScreenIds.EDITOR)
	scene._on_intent(&"toggle_pause", {})
	assert_bool(scene.session.clock.is_paused()).is_true()
	scene._on_intent(&"editor_tool", {"brush_mode": MHBrush.Mode.PAINT, "radius": 8, "surface_layer": MHSplatMap.Layer.WATER})
	var sink: MHLiveTerrainSink = MHLiveTerrainSink.new(scene.editor)
	sink.begin_stroke()
	sink.apply_brush_at(64, 64)
	sink.end_stroke()
	var painted: int = scene.editor.splat.hash_fnv1a()
	assert_bool(scene.view.can_undo()).is_true()
	scene._on_intent(&"editor_undo", {})
	assert_bool(scene.view.can_redo()).is_true()
	scene._on_intent(&"editor_redo", {})
	assert_int(scene.editor.splat.hash_fnv1a()).is_equal(painted)
	scene._on_intent(&"buy_tier", {"building": "clubhouse", "tier": 1})
	assert_int(int(scene.session.tiers()["clubhouse"])).is_equal(1)
	assert_bool(scene.save_now()).is_true()
	var loaded: MHSaveResult = scene.store.load_slot(0)
	assert_bool(loaded.is_ok()).is_true()
	var saved: MHLoadedSave = loaded.value as MHLoadedSave
	var ledger: MHSaveResult = MHSessionSave.load_ledger(saved.data, LEDGERS)
	assert_bool(ledger.is_ok()).is_true()
	var restored: MHSaveResult = MHSessionSave.restore(saved.data, ledger.value as MHTokenLedger)
	assert_bool(restored.is_ok()).is_true()
	assert_bool((restored.value as MHGameSession).clock.is_paused()).is_true()
	assert_dict((restored.value as MHGameSession).economy.to_dict()).is_equal(scene.session.economy.to_dict())
	var terrain: MHTerrainSave.LoadResult = MHTerrainSave.decode(saved.blob)
	assert_int(terrain.splat.hash_fnv1a()).is_equal(painted)
	scene._active = false


func test_save_refuses_half_finished_craft_stroke() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	assert_bool(scene.craft_hole.begin_stroke()).is_true()
	scene.craft_hole.paint_tile(8, 12, MHCraftHole.Surface.WATER)
	assert_bool(scene.save_now()).is_false()
	scene.craft_hole.cancel_stroke()
	assert_bool(scene.save_now()).is_true()
	scene._active = false


func test_unfinalized_craft_draft_survives_cold_reopen_exactly() -> void:
	var scene: MHLiveConstruction = MHLiveConstruction.new()
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole.paint_tile(4, 5, MHCraftHole.Surface.OUT_OF_BOUNDS)
	scene.craft_hole.paint_tile(8, 12, MHCraftHole.Surface.WATER)
	scene.craft_hole.set_height_mm_tile(8, 12, 650)
	scene.craft_hole.tees.clear()
	scene.craft_hole.add_tee(12, 1)
	scene.craft_hole.pins.clear()
	scene.craft_hole.add_pin(11, 30)
	scene.craft_hole.add_pin(12, 31)
	var expected: Dictionary = scene.craft_hole.to_dict()
	assert_bool(scene.save_now()).is_true()
	assert_int(int(scene.document["min_reader_version"])).is_equal(6)
	scene._active = false
	scene.queue_free()
	await get_tree().process_frame

	var reopened: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	reopened.store = MHSaveStore.new(DIR)
	reopened.ledger_dir = LEDGERS
	add_child(reopened)
	assert_bool(reopened._active).is_true()
	assert_dict(reopened.craft_hole.to_dict()).is_equal(expected)
	assert_int(reopened.craft_hole.get_height_mm(8, 12)).is_equal(650)
	assert_int(reopened.craft_hole.get_surface(4, 5)).is_equal(MHCraftHole.Surface.OUT_OF_BOUNDS)
	reopened._active = false


func test_live_scene_finalization_can_save_and_reload_practice() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.session.clock.pause()
	scene._open_craft_hole()
	# Make all three authored holes observably different before finalization.
	for i: int in range(3):
		assert_bool(scene.select_craft_hole(i)).is_true()
		scene.craft_hole.set_height_mm_tile(11, 15, (i + 1) * 500)
	var expected_course: Dictionary = scene.craft_course.to_dict()
	scene.one_hole._finalize()
	var defs: Array = scene.session.hole_definitions()
	assert_int(defs.size()).is_equal(3)
	for i: int in range(3):
		assert_int(int((defs[i] as Dictionary)["slot_id"])).is_equal(i)
	assert_int(int(scene.document["min_reader_version"])).is_equal(6)
	scene.one_hole._shoot()
	assert_object(scene.session.practice).is_not_null()
	assert_int(scene.session.practice.strokes).is_greater(0)
	assert_bool(scene.save_now()).is_true()
	var loaded: MHSaveResult = scene.store.load_slot(0)
	assert_bool(loaded.is_ok()).is_true()
	var saved: MHLoadedSave = loaded.value as MHLoadedSave
	var ledger: MHSaveResult = MHSessionSave.load_ledger(saved.data, LEDGERS)
	var restored: MHSaveResult = MHSessionSave.restore(saved.data, ledger.value as MHTokenLedger)
	assert_bool(restored.is_ok()).is_true()
	if restored.is_ok():
		var restored_session: MHGameSession = restored.value
		assert_dict(restored_session.practice.to_dict()).is_equal(scene.session.practice.to_dict())
		assert_int(restored_session.economy.cash).is_equal(scene.session.economy.cash)
		assert_int(restored_session.hole_definitions().size()).is_equal(3)
		assert_dict((saved.data["runtime"] as Dictionary)["craft_course"]).is_equal(expected_course)
	scene._active = false


func test_elevated_live_scene_cold_reopen_accepts_saved_relief() -> void:
	var scene: MHLiveConstruction = MHLiveConstruction.new()
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.craft_hole.set_height_tile(11, 15, 6)
	var expected: Dictionary = scene.canonical_craft_draft()
	assert_bool(expected.has("relief")).is_true()
	assert_bool(scene.one_hole.set_canonical_draft(expected)).is_true()
	scene.one_hole._finalize()
	assert_bool(scene.save_now()).is_true()
	scene._active = false
	scene.queue_free()
	await get_tree().process_frame

	var reopened: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	reopened.store = MHSaveStore.new(DIR)
	reopened.ledger_dir = LEDGERS
	add_child(reopened)
	assert_bool(reopened._active).is_true()
	assert_array(reopened.session.hole_definitions()).contains_exactly([expected])
	assert_bool(MHOneHolePanel.supported(reopened.document["course"] as Dictionary)).is_true()
	reopened._open_craft_hole()
	assert_bool(reopened.one_hole.visible).is_true()
	reopened._active = false


func test_screen_aim_projection_sets_target_without_playing_or_charging() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	scene._open_craft_hole()
	scene.one_hole._finalize()
	var before: Dictionary = scene.session.practice.to_dict()
	var cash: int = scene.session.economy.cash
	var screen: Vector2 = scene.controller.camera.unproject_position(Vector3(48.0, 0.0, 79.72))
	assert_bool(scene.one_hole.aim_from_screen(screen)).is_true()
	assert_int(scene.one_hole.aim_x).is_equal(0)
	assert_int(scene.one_hole.aim_y).is_equal(5000)
	assert_dict(scene.session.practice.to_dict()).is_equal(before)
	assert_int(scene.session.economy.cash).is_equal(cash)
	assert_bool(scene.one_hole.blocks_world_tap(scene.one_hole.get_global_rect().get_center())).is_true()
	scene.aim_input.taps.down(0, Vector2.ZERO, false)
	scene.aim_input._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_bool(scene.aim_input.taps.up(0, Vector2.ZERO, false)["aim"]).is_false()
	scene._active = false

func test_camera_follow_and_overview_preserve_gameplay_state() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	scene._open_craft_hole()
	scene.one_hole._finalize()
	var before: Dictionary = scene.session.practice.to_dict()
	var cash: int = scene.session.economy.cash
	scene.one_hole._overview()
	assert_bool(scene.one_hole.follow_ball).is_false()
	assert_float(scene.controller.rig.distance).is_equal(150.0)
	scene.one_hole._back_to_golfer()
	assert_bool(scene.one_hole.follow_ball).is_true()
	assert_float(scene.controller.rig.distance).is_equal(100.0)
	assert_dict(scene.session.practice.to_dict()).is_equal(before)
	assert_int(scene.session.economy.cash).is_equal(cash)
	scene.one_hole._shoot()
	var r: MHPracticeRound = scene.session.practice
	var expected: Vector3 = scene.one_hole._position(r.x, r.y, -20.0)
	assert_bool(scene.controller.rig.target == expected).is_true()
	scene.one_hole._overview()
	var overview: Vector3 = scene.controller.rig.target
	scene.one_hole._shoot()
	assert_bool(scene.controller.rig.target == overview).is_true()
	scene._active = false


func test_elevated_craft_hole_practice_state_survives_checkpoint_exactly() -> void:
	var s: MHGameSession = MHGameSession.create()
	var craft: MHCraftHole = MHCraftHole.new(24, 40)
	craft.paint_rect(10, 0, 13, 29, MHCraftHole.Surface.FAIRWAY)
	craft.paint_rect(11, 30, 12, 31, MHCraftHole.Surface.GREEN)
	craft.add_tee(11, 0)
	craft.add_pin(11, 30)
	craft.set_height_tile(11, 15, 6)
	var layout: Dictionary = MHCraftConvert.to_hole_def(craft, 0, 0, 0)
	assert_bool(layout.has("relief")).is_true()
	assert_bool(s.submit_course([layout])["ok"]).is_true()
	s.practice = MHPracticeRound.create(layout, 123456, 500)
	assert_object(s.practice).is_not_null()
	var shot: Dictionary = s.practice.play(s.practice.hole.gx, s.practice.hole.gy)
	assert_bool(bool(shot["ok"])).is_true()
	var doc: Dictionary = _document(s)
	var encoded: MHSaveResult = MHCourseLayout.encode([layout], doc["course"] as Dictionary, [[100, 100]])
	assert_bool(encoded.is_ok()).override_failure_message(encoded.message).is_true()
	if not encoded.is_ok():
		return
	doc["course"] = encoded.value
	doc["min_reader_version"] = 3
	var captured: MHSaveResult = MHSessionSave.capture(s, doc)
	assert_bool(captured.is_ok()).override_failure_message(captured.message).is_true()
	if not captured.is_ok():
		return
	var restored: MHSaveResult = MHSessionSave.restore(captured.value as Dictionary, s.ledger)
	assert_bool(restored.is_ok()).override_failure_message(restored.message).is_true()
	if restored.is_ok():
		var rs: MHGameSession = restored.value
		assert_array(rs.hole_definitions()).contains_exactly([layout])
		assert_dict(rs.practice.to_dict()).is_equal(s.practice.to_dict())

func test_three_hole_active_context_follows_practice_slot_not_hole_zero() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene._open_craft_hole()
	scene.one_hole._finalize()
	var defs: Array = scene.session.hole_definitions()
	assert_int(defs.size()).is_equal(3)
	for i: int in range(3):
		scene.one_hole._play_hole_index = i
		scene.session.practice = MHPracticeRound.create(defs[i] as Dictionary,
			MHRatingEngine.seed_for(i, {"save_secret": scene.session.save_secret, "rating_epoch": scene.session.rating_epoch}))
		assert_int(scene.one_hole._active_play_index()).is_equal(i)
		assert_int(int(scene.one_hole._active_play_layout()["slot_id"])).is_equal(i)
		assert_int(scene.one_hole._active_hole_number()).is_equal(i + 1)
	scene._active = false

func test_three_hole_craft_course_survives_cold_reopen_exactly() -> void:
	var scene: MHLiveConstruction = MHLiveConstruction.new()
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	for i: int in range(3):
		assert_bool(scene.select_craft_hole(i)).is_true()
		scene.craft_hole.set_height_mm_tile(8 + i, 12 + i, 250 * (i + 1))
		scene.craft_hole.flowers = 3 + i
	assert_bool(scene.select_craft_hole(2)).is_true()
	var expected: Dictionary = scene.craft_course.to_dict()
	assert_bool(scene.save_now()).is_true()
	scene._active = false
	scene.queue_free()
	await get_tree().process_frame

	var reopened: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	reopened.store = MHSaveStore.new(DIR)
	reopened.ledger_dir = LEDGERS
	add_child(reopened)
	assert_bool(reopened._active).is_true()
	assert_dict(reopened.craft_course.to_dict()).is_equal(expected)
	assert_int(reopened.craft_course.active_index).is_equal(2)
	for i: int in range(3):
		assert_bool(reopened.select_craft_hole(i)).is_true()
		assert_int(reopened.craft_hole.get_height_mm(8 + i, 12 + i)).is_equal(250 * (i + 1))
		assert_int(reopened.craft_hole.flowers).is_equal(3 + i)
	reopened._active = false

func test_practice_checkpoint_never_downgrades_customer_reader_requirement() -> void:
	var s: MHGameSession = MHGameSession.create()
	var craft: MHCraftHole = MHCraftCourse.default_hole(0)
	var layout: Dictionary = MHCraftConvert.to_hole_def(craft, 0, 0, 0)
	assert_bool(s.submit_course([layout])["ok"]).is_true()
	s.practice = MHPracticeRound.create(layout, 12345)
	assert_object(s.practice).is_not_null()
	var captured: MHSaveResult = MHSessionSave.capture(s, _document(s))
	assert_bool(captured.is_ok()).override_failure_message(captured.message).is_true()
	if captured.is_ok():
		var doc: Dictionary = captured.value as Dictionary
		assert_int(int(doc["min_reader_version"])).is_equal(6)
		assert_bool((doc["runtime"] as Dictionary).has("customers")).is_true()
		assert_bool((doc["runtime"] as Dictionary).has("practice")).is_true()
		assert_bool(MHSessionSave.restore(doc, s.ledger).is_ok()).is_true()

func test_reader_requirement_is_monotonic_across_checkpoint_capabilities() -> void:
	var legacy_course: Dictionary = {"schema_version": 1}
	var primitive_course: Dictionary = {"schema_version": 2}
	assert_int(MHSessionSave._required_reader_version(legacy_course, false, false, false, false)).is_equal(2)
	assert_int(MHSessionSave._required_reader_version(primitive_course, false, false, false, false)).is_equal(3)
	assert_int(MHSessionSave._required_reader_version(legacy_course, false, true, false, false)).is_equal(3)
	assert_int(MHSessionSave._required_reader_version(legacy_course, false, true, true, false)).is_equal(4)
	assert_int(MHSessionSave._required_reader_version(legacy_course, false, true, true, true)).is_equal(5)
	assert_int(MHSessionSave._required_reader_version(legacy_course, true, true, true, true)).is_equal(6)
	assert_int(MHSessionSave._required_reader_version(primitive_course, true, true, true, true)).is_equal(6)
