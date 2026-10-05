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
