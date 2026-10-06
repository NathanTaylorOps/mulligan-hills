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


func test_live_scene_finalization_can_save_and_reload_practice() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.session.clock.pause()
	scene.one_hole.open()
	scene.one_hole._finalize()
	assert_int(scene.session.hole_definitions().size()).is_equal(1)
	assert_int(int(scene.document["min_reader_version"])).is_equal(3)
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
	scene._active = false


func test_screen_aim_projection_sets_target_without_playing_or_charging() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	scene.one_hole.open()
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
	scene.one_hole.open()
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


func test_first_real_round_status_distinguishes_fresh_and_restored_play() -> void:
	var fresh: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	fresh.store = MHSaveStore.new(DIR)
	fresh.ledger_dir = LEDGERS
	add_child(fresh)
	assert_bool(fresh._active).is_true()
	assert_bool(fresh._resumed_checkpoint).is_false()
	assert_str(fresh._first_round_status()).contains("First Real Round")
	fresh.session.clock.pause()
	fresh.one_hole.open()
	fresh.one_hole._finalize()
	fresh.one_hole._shoot()
	assert_bool(fresh.save_now()).is_true()
	fresh._active = false
	remove_child(fresh)
	fresh.queue_free()

	var resumed: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	resumed.store = MHSaveStore.new(DIR)
	resumed.ledger_dir = LEDGERS
	add_child(resumed)
	assert_bool(resumed._active).is_true()
	assert_bool(resumed._resumed_checkpoint).is_true()
	assert_object(resumed.session.practice).is_not_null()
	assert_str(resumed._first_round_status()).contains("continue your saved round")
	resumed._active = false


func test_first_real_round_flat_terrain_keeps_legacy_no_relief_path() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	var layout: Dictionary = scene.one_hole._layout()
	assert_bool(layout.has("relief")).is_false()
	scene._active = false


func test_first_real_round_terrain_relief_rates_plays_and_survives_save() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	scene.session.clock.pause()
	# Raise terrain under the middle of the authored hole. The exact sampled heightmap, not a cosmetic flag,
	# must become the rating/practice relief grid.
	scene.editor.grid.set_h(48, 62, 6000)
	scene.one_hole.open()
	scene.one_hole._finalize()
	var layouts: Array = scene.session.hole_definitions()
	assert_int(layouts.size()).is_equal(1)
	var layout: Dictionary = layouts[0]
	assert_bool(layout.has("relief")).is_true()
	var parsed: MHRHole = MHRHole.from_def(layout)
	assert_bool(parsed.has_relief).is_true()
	assert_bool(parsed.relief_range > 0).is_true()
	assert_bool(parsed.elev_mm() > 0).is_true()
	assert_object(scene.session.practice).is_not_null()
	assert_bool(scene.session.practice.hole.has_relief).is_true()
	assert_bool(scene.save_now()).is_true()
	var loaded: MHSaveResult = scene.store.load_slot(0)
	assert_bool(loaded.is_ok()).is_true()
	var saved: MHLoadedSave = loaded.value as MHLoadedSave
	var ledger: MHSaveResult = MHSessionSave.load_ledger(saved.data, LEDGERS)
	var restored: MHSaveResult = MHSessionSave.restore(saved.data, ledger.value as MHTokenLedger)
	assert_bool(restored.is_ok()).is_true()
	if restored.is_ok():
		var restored_session: MHGameSession = restored.value
		var restored_layout: Dictionary = restored_session.hole_definitions()[0]
		assert_bool(restored_layout.has("relief")).is_true()
		assert_bool(restored_session.practice.hole.has_relief).is_true()
		assert_str(restored_session.practice.hole.content_hash()).is_equal(scene.session.practice.hole.content_hash())
	scene._active = false


func test_paid_customer_admissions_are_presentation_only_and_do_not_charge_again() -> void:
	var s: MHGameSession = MHGameSession.create()
	assert_object(s).is_not_null()
	var hole: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 60, 5],
		"features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}]}
	var submitted: Dictionary = s.submit_course([hole])
	assert_bool(bool(submitted["ok"])).is_true()
	var cash_before: int = s.economy.cash
	var tick: Dictionary = s.economy.tick_hour()
	s._queue_pending_customers(tick)
	s._resolve_customer_hour()
	var cash_after_tick: int = s.economy.cash
	var admissions: Array = s.take_customer_outcomes(999)
	assert_int(s.economy.cash).is_equal(cash_after_tick)
	assert_bool(cash_after_tick != cash_before or int(tick["golfers"]) == 0).is_true()
	assert_int(admissions.size()).is_equal(int(tick["golfers"]))
	for v: Variant in admissions:
		var customer: Dictionary = v
		assert_int(int(customer["paid_fee"])).is_equal(s.economy.green_fee())


func test_golfer_identity_history_survives_session_checkpoint() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	scene.session.clock.pause()
	var identity: Dictionary = scene.session.golfer_roster.identity_for_admission(scene.session.save_secret, 0, 1)
	scene.session.golfer_roster.record_visit(int(identity["id"]), 1, 90, "Favorite elevated hole")
	scene.session._customer_serial = 5
	scene.session.customer_feedback_sum = 90
	scene.session.customer_feedback_count = 1
	assert_bool(scene.save_now()).is_true()
	var loaded: MHSaveResult = scene.store.load_slot(0)
	assert_bool(loaded.is_ok()).is_true()
	var saved: MHLoadedSave = loaded.value as MHLoadedSave
	var ledger: MHSaveResult = MHSessionSave.load_ledger(saved.data, LEDGERS)
	var restored: MHSaveResult = MHSessionSave.restore(saved.data, ledger.value as MHTokenLedger)
	assert_bool(restored.is_ok()).is_true()
	if restored.is_ok():
		var s: MHGameSession = restored.value
		assert_dict(s.golfer_roster.to_dict()).is_equal(scene.session.golfer_roster.to_dict())
		assert_int(s._customer_serial).is_equal(5)
		assert_int(s.customer_feedback_average()).is_equal(90)
	scene._active = false


func test_post_round_facility_choice_requires_owned_building() -> void:
	var s: MHGameSession = MHGameSession.create()
	assert_object(s).is_not_null()
	var identity: Dictionary = {"favorite_facility": "restaurant"}
	# Fresh economy has no purchased facility tier.
	assert_str(s.choose_post_round_facility(identity)).is_equal("")
	s.economy.set_tier(0, 1) # clubhouse
	assert_str(s.choose_post_round_facility(identity)).is_equal("clubhouse")
	s.economy.set_tier(3, 1) # restaurant
	assert_str(s.choose_post_round_facility(identity)).is_equal("restaurant")


func test_grouped_admissions_never_exceed_paid_golfer_count() -> void:
	var s: MHGameSession = MHGameSession.create()
	var hole: Dictionary = {"slot_id": 0, "tee": [0, 0], "green": [0, 60, 5],
		"features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}]}
	assert_bool(bool(s.submit_course([hole])["ok"])).is_true()
	var tick: Dictionary = s.economy.tick_hour()
	s._queue_pending_customers(tick)
	s._resolve_customer_hour()
	var admissions: Array = s.take_customer_outcomes(999)
	assert_int(admissions.size()).is_equal(int(tick["golfers"]))
	for v: Variant in admissions:
		var customer: Dictionary = v
		assert_bool(int(customer.get("group_size", 0)) >= 1 and int(customer.get("group_size", 0)) <= 4).is_true()


func test_corrupt_building_placement_checkpoint_is_rejected() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.set_tier(0, 1)
	var placed: Dictionary = {"ok": true, "center_mm": [30000, 42000], "size_m": [18, 14],
		"ground_mm": 1250, "rotation_quarters": 0}
	assert_bool(s.set_building_placement("clubhouse", placed)).is_true()
	var base: Dictionary = _checkpoint(s)
	for kind: String in ["outside", "bad_rotation", "bad_size", "unknown", "unpurchased"]:
		var doc: Dictionary = base.duplicate(true)
		if kind == "outside":
			var key: Variant = (doc["runtime"]["building_placements"] as Dictionary).keys()[0]
			doc["runtime"]["building_placements"][key]["center_mm"] = [-1000, 42000]
		elif kind == "bad_rotation":
			var key: Variant = (doc["runtime"]["building_placements"] as Dictionary).keys()[0]
			doc["runtime"]["building_placements"][key]["rotation_quarters"] = 9
		elif kind == "bad_size":
			var key: Variant = (doc["runtime"]["building_placements"] as Dictionary).keys()[0]
			doc["runtime"]["building_placements"][key]["size_m"] = [0, 14]
		elif kind == "unknown":
			var key: Variant = (doc["runtime"]["building_placements"] as Dictionary).keys()[0]
			doc["runtime"]["building_placements"]["mystery"] = doc["runtime"]["building_placements"][key].duplicate(true)
			doc["runtime"]["building_placements"]["mystery"]["building_id"] = "mystery"
			doc["runtime"]["building_placements"]["mystery"]["instance_id"] = "mystery"
		else:
			doc["runtime"]["economy"]["tiers"][0] = 0
			doc["buildings"][0]["tier"] = 0
		MHSaveGame.seal(doc)
		assert_bool(MHSessionSave.restore(doc, s.ledger).is_ok()).is_false()


func test_building_placement_survives_checkpoint_exactly() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.set_tier(0, 1)
	var placed: Dictionary = {"ok": true, "center_mm": [30000, 42000], "size_m": [18, 14],
		"ground_mm": 1250, "rotation_quarters": 1}
	assert_bool(s.set_building_placement("clubhouse", placed)).is_true()
	var doc: Dictionary = _checkpoint(s)
	var restored: MHSaveResult = MHSessionSave.restore(doc, s.ledger)
	assert_bool(restored.is_ok()).is_true()
	if restored.is_ok():
		var loaded: MHGameSession = restored.value
		assert_dict(loaded.building_placements).is_equal(s.building_placements)
		assert_bool(loaded.building_position("clubhouse").is_equal_approx(Vector3(30.0, 1.25, 42.0))).is_true()


func test_multiple_building_instances_keep_distinct_identity() -> void:
	var s: MHGameSession = MHGameSession.create()
	s.economy.set_tier(0, 1)
	var first: Dictionary = {"ok": true, "center_mm": [30000, 42000], "size_m": [18, 14],
		"ground_mm": 1000, "rotation_quarters": 0, "instance_id": "clubhouse_a"}
	var second: Dictionary = {"ok": true, "center_mm": [60000, 42000], "size_m": [18, 14],
		"ground_mm": 1200, "rotation_quarters": 0, "instance_id": "clubhouse_b"}
	assert_bool(s.set_building_placement("clubhouse", first)).is_true()
	assert_bool(s.set_building_placement("clubhouse", second)).is_true()
	assert_int(s.building_placements.size()).is_equal(2)
	assert_bool(s.building_placements.has("clubhouse_a")).is_true()
	assert_bool(s.building_placements.has("clubhouse_b")).is_true()



func test_staff_roster_round_trips_through_live_session_checkpoint() -> void:
	var s: MHGameSession = MHGameSession.create()
	var view: Dictionary = s.staff_view()
	var role: String = str(s.staff_system.defs.role_ids()[0])
	var building: String = s.staff_system.defs.role_building(role)
	var bi: int = s.economy.params.building_index(building)
	if bi >= 0:
		s.economy.set_tier(bi, 1)
	view = s.staff_view()
	var hired: Dictionary = s.staff_system.hire(role, s.economy.day, view, 1000000000)
	assert_bool(bool(hired.get("ok", false))).is_true()
	var checkpoint: Dictionary = _checkpoint(s)
	var loaded: MHSaveResult = MHSessionSave.restore(checkpoint, s.ledger)
	assert_bool(loaded.is_ok()).is_true()
	var restored: MHGameSession = loaded.value as MHGameSession
	assert_array(Array(restored.staff_system.state_list())).contains_exactly(Array(s.staff_system.state_list()))
	assert_dict(restored.staff_system.legacy_counts()).is_equal(s.staff_system.legacy_counts())


func test_staff_roster_and_legacy_count_disagreement_is_rejected() -> void:
	var s: MHGameSession = MHGameSession.create()
	var checkpoint: Dictionary = _checkpoint(s)
	var staff_counts: Dictionary = checkpoint["club"]["staff"] as Dictionary
	var key: String = str(staff_counts.keys()[0])
	staff_counts[key] = int(staff_counts[key]) + 1
	MHSaveGame.seal(checkpoint)
	assert_bool(MHSessionSave.restore(checkpoint, s.ledger).is_ok()).is_false()


func test_customer_resolution_does_not_replay_pending_admissions() -> void:
	var s: MHGameSession = MHGameSession.create()
	s._holes = [{"par": 3}]
	s._ratings = [{"par": 3}]
	s._pending_customers = [{"serial": 1, "identity": s.golfer_roster.identity_for_admission(s.save_secret, 1, 0), "hole_slot": 0}]
	s._resolve_customer_hour()
	var outcomes: int = s.customer_outcomes.size()
	var feedback: int = s.customer_feedback_count
	s._resolve_customer_hour()
	assert_int(s.customer_outcomes.size()).is_equal(outcomes)
	assert_int(s.customer_feedback_count).is_equal(feedback)
	assert_int(s._pending_customers.size()).is_equal(0)


func test_pending_paid_customers_round_trip_through_checkpoint() -> void:
	var s: MHGameSession = MHGameSession.create()
	var identity: Dictionary = s.golfer_roster.identity_for_admission(s.save_secret, 91, s.economy.day)
	s._pending_customers = [{"serial": 91, "identity": identity, "group_size": 1, "paid_fee": 2500,
		"ancillary": 300, "admitted_day": s.economy.day, "admitted_hour": s.economy.hour, "hole_slot": 0}]
	var checkpoint: Dictionary = _checkpoint(s)
	var loaded: MHSaveResult = MHSessionSave.restore(checkpoint, s.ledger)
	assert_bool(loaded.is_ok()).is_true()
	var restored: MHGameSession = loaded.value as MHGameSession
	assert_array(restored._pending_customers).contains_exactly(s._pending_customers)


func test_management_difficulty_round_trips_and_rejects_invalid_value() -> void:
	var s: MHGameSession = MHGameSession.create()
	assert_bool(s.set_management_difficulty("tycoon")).is_true()
	assert_bool(s.set_management_difficulty("nightmare")).is_false()
	var checkpoint: Dictionary = _checkpoint(s)
	var loaded: MHSaveResult = MHSessionSave.restore(checkpoint, s.ledger)
	assert_bool(loaded.is_ok()).is_true()
	assert_str((loaded.value as MHGameSession).management_difficulty).is_equal("tycoon")
	var bad: Dictionary = checkpoint.duplicate(true)
	(bad["runtime"] as Dictionary)["management_difficulty"] = "nightmare"
	assert_bool(MHSessionSave.restore(bad, s.ledger).is_ok()).is_false()


func test_full_management_state_round_trips_through_checkpoint() -> void:
	var s: MHGameSession = MHGameSession.create()
	var maintenance_index: int = s.economy.params.building_index("maintenance")
	s.economy.set_tier(maintenance_index, 2)
	assert_bool(s.set_management_difficulty("tycoon")).is_true()
	var hired: Dictionary = s.hire_staff("groundskeeper")
	assert_bool(bool(hired["ok"])).is_true()
	var employee: int = int(hired["serial"])
	assert_bool(bool(s.assign_staff(employee, [5, 6, 9])["ok"])).is_true()
	var bought: Dictionary = s.buy_staff_equipment("greens_mower")
	assert_bool(bool(bought["ok"])).is_true()
	var equipment_serial: int = int(bought["serial"])
	assert_bool(s.assign_staff_equipment(equipment_serial, employee)).is_true()
	# Exercise the machine so cumulative equipment costs and condition are non-default state.
	s.staff_system.on_day(s.economy.day + 1, s.staff_view(), s.save_secret, s.management_difficulty)
	var before: Dictionary = s.staff_system.to_save_block()
	var checkpoint: Dictionary = _checkpoint(s)
	var loaded: MHSaveResult = MHSessionSave.restore(checkpoint, s.ledger)
	assert_bool(loaded.is_ok()).is_true()
	if loaded.is_ok():
		var restored: MHGameSession = loaded.value
		assert_str(restored.management_difficulty).is_equal("tycoon")
		assert_dict(restored.staff_system.to_save_block()).is_equal(before)
		var report: Dictionary = restored.management_report()
		assert_int(int(report["head_count"])).is_equal(1)
		assert_int(int(report["equipment_units"])).is_equal(1)
		assert_array((report["employees"][0] as Dictionary)["areas"] as Array).contains_exactly([5, 6, 9])
		assert_int(int((report["equipment"][0] as Dictionary)["assigned_employee"])).is_equal(employee)


func test_live_scene_starts_authoritative_customer_playback_once() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	scene.session._holes = [{"slot_id": 4, "tee": [10, 20], "green": [40, 80, 5]}]
	# Live presentation resolves the authoritative hole-local geometry through its saved world origin.
	(scene.document["course"] as Dictionary)["holes"] = [{"hole_no": 5, "origin_dm": [100, 200],
		"layout": scene.session._holes[0]}]
	var customers: Array = []
	for serial: int in range(77, 80):
		customers.append({"serial": serial, "party_id": 77, "hole_slot": 4, "group_size": 3,
			"identity": {"id": serial}, "round": {"events": [], "strokes": 3, "flags": 0}})
	scene.session.customer_playback.admit(customers, scene.session._holes[0], {}, {})
	assert_int(scene._visible_golfers.golfer_count()).is_equal(0)
	scene._advance_customer_playback(0.1)
	assert_int(scene._visible_golfers.golfer_count()).is_equal(3)
	scene._advance_customer_playback(0.1)
	assert_int(scene._visible_golfers.golfer_count()).is_equal(3)
	scene._active = false


func test_live_facility_walker_starts_visit_only_after_arrival() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	var clubhouse_index: int = scene.session.economy.params.building_index("clubhouse")
	scene.session.economy.set_tier(clubhouse_index, 1)
	assert_bool(scene.session.set_building_placement("clubhouse", {"ok": true, "center_mm": [1000, 0],
		"size_m": [18, 14], "ground_mm": 0, "rotation_quarters": 0})).is_true()
	var facility_id: String = str(MHClubPedestrian.instance_ids_for_type(scene.session, "clubhouse")[0])
	var customer: Dictionary = {"serial": 91, "identity": {"id": 1, "favorite_hole_slot": -1}}
	scene.session.customer_playback.queue_facility_visit(customer, facility_id, 0.0)
	assert_int(scene.session.customer_playback.facility_visits.size()).is_equal(0)
	scene._advance_facility_walkers(0.1)
	assert_int(scene._facility_walkers.size()).is_equal(1)
	assert_int(scene.session.customer_playback.facility_visits.size()).is_equal(0)
	for _i: int in range(20):
		scene._advance_facility_walkers(0.1)
	assert_int(scene._facility_walkers.size()).is_equal(0)
	assert_int(scene.session.customer_playback.pending_facility_visits.size()).is_equal(0)
	assert_int(scene.session.customer_playback.facility_visits.size()).is_equal(1)
	scene._active = false


func test_facility_travel_is_queued_only_after_playback_finish() -> void:
	var scene: MHLiveConstruction = auto_free(MHLiveConstruction.new())
	scene.store = MHSaveStore.new(DIR)
	scene.ledger_dir = LEDGERS
	add_child(scene)
	assert_bool(scene._active).is_true()
	var clubhouse_index: int = scene.session.economy.params.building_index("clubhouse")
	scene.session.economy.set_tier(clubhouse_index, 1)
	assert_bool(scene.session.set_building_placement("clubhouse", {"ok": true, "center_mm": [1000, 0],
		"size_m": [18, 14], "ground_mm": 0, "rotation_quarters": 0})).is_true()
	var customer: Dictionary = {"serial": 31, "satisfaction": 80,
		"identity": {"favorite_facility": "clubhouse", "party_size": 1},
		"round": {"events": [{"kind": "putt", "shot": 1, "strokes": 1, "x0": 0, "y0": 0, "x1": 0, "y1": 0}]}}
	scene.session.customer_playback.admit([customer], {}, {}, {})
	assert_int(scene.session.customer_playback.pending_facility_visits.size()).is_equal(0)
	scene._advance_customer_playback(0.1)
	assert_int(scene.session.customer_playback.pending_facility_visits.size()).is_equal(0)
	var started: Dictionary = scene.session.customer_playback.active
	started["started_s"] = -1000.0
	scene._advance_customer_playback(0.1)
	assert_int(scene.session.customer_playback.pending_facility_visits.size()).is_equal(1)
	scene._active = false


func test_management_hire_availability_includes_payroll_reserve() -> void:
	var s: MHGameSession = MHGameSession.create()
	var clubhouse_index: int = s.economy.params.building_index("clubhouse")
	s.economy.set_tier(clubhouse_index, 1)
	var probe: Dictionary = s.staff_system.hire("marshal", s.economy.day, s.staff_view(), 1000000000)
	assert_bool(bool(probe.get("ok", false))).is_true()
	var upfront: int = int(probe["cost"])
	# Restore the probe mutation so availability is checked against a fresh roster.
	s.staff_system = MHStaff.create(s.staff_system.defs)
	s.economy.cash = upfront
	var report: Dictionary = s.management_report()
	var marshal_option: Dictionary = {}
	for option_v: Variant in report.get("hire_options", []):
		var option: Dictionary = option_v
		if str(option.get("role", "")) == "marshal":
			marshal_option = option
			break
	assert_bool(marshal_option.is_empty()).is_false()
	assert_bool(bool(marshal_option.get("available", true))).is_false()
	assert_bool(bool(s.hire_staff("marshal").get("ok", true))).is_false()


func test_customer_resolution_builds_one_authoritative_record_per_course_hole() -> void:
	var s: MHGameSession = MHGameSession.create()
	var holes: Array = [
		{"slot_id": 2, "tee": [0, 0], "green": [0, 60, 5], "features": [{"t": "fairway", "rect": [-8, 0, 8, 60]}]},
		{"slot_id": 5, "tee": [0, 0], "green": [0, 90, 5], "features": [{"t": "fairway", "rect": [-8, 0, 8, 90]}]},
	]
	assert_bool(bool(s.submit_course(holes)["ok"])).is_true()
	var identity: Dictionary = s.golfer_roster.identity_for_admission(s.save_secret, 50, s.economy.day)
	s._pending_customers = [{"serial": 50, "party_id": 50, "identity": identity, "group_size": 1,
		"paid_fee": 2500, "ancillary": 0, "admitted_day": s.economy.day, "admitted_hour": s.economy.hour, "hole_slot": 2}]
	s._resolve_customer_hour()
	assert_int(s.customer_outcomes.size()).is_equal(1)
	var customer: Dictionary = s.customer_outcomes[0]
	var course_round: Array = customer["course_round"] as Array
	assert_int(course_round.size()).is_equal(2)
	assert_int(int((course_round[0] as Dictionary)["hole_slot"])).is_equal(2)
	assert_int(int((course_round[1] as Dictionary)["hole_slot"])).is_equal(5)
	assert_dict(customer["round"] as Dictionary).is_equal((course_round[0] as Dictionary)["round"] as Dictionary)
	assert_int(s.customer_feedback_count).is_equal(1)
