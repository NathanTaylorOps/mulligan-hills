extends GdUnitTestSuite
## MHSaveStore: atomic writes, fallback loading, torn JSON / terrain-blob pair recovery, listing, import/export,
## migration through the store. Files go to user://mh_test_saves and are removed in after_test. NOT YET RUN in Godot.

const Fixture = preload("res://tests/save/save_fixture.gd")
const DIR: String = "user://mh_test_saves"


func before_test() -> void:
	_reset_faults()
	Fixture.wipe_dir(DIR)


func after_test() -> void:
	_reset_faults()
	Fixture.wipe_dir(DIR)


func _reset_faults() -> void:
	MHSaveFile.fault_point = MHSaveFile.FaultPoint.NONE
	MHSaveFile.fault_action = MHSaveFile.FaultAction.RETURN_ERROR
	MHSaveStore.fault_point = MHSaveStore.FaultPoint.NONE
	MHSaveStore.fault_action = MHSaveFile.FaultAction.RETURN_ERROR


func _store() -> MHSaveStore:
	var s := MHSaveStore.new(DIR)
	s.clock_unix = 1790000100
	return s


func _save(s: MHSaveStore, slot: int, blob_seed: int, cash: int = 18250) -> MHSaveResult:
	var doc: Dictionary = Fixture.make_doc()
	(doc["club"] as Dictionary)["cash"] = cash
	return s.save_slot(slot, doc, Fixture.make_blob(blob_seed))


func _revision_of(r: MHSaveResult) -> int:
	return int((r.value as MHLoadedSave).data["revision"])


func test_save_and_load_round_trip() -> void:
	var s: MHSaveStore = _store()
	var blob: PackedByteArray = Fixture.make_blob(11)
	var w: MHSaveResult = s.save_slot(1, Fixture.make_doc(), blob)
	assert_bool(w.is_ok()).is_true()
	var sum: MHSaveSummary = w.value
	assert_int(sum.revision).is_equal(1)
	assert_int(sum.day).is_equal(17)
	assert_int(sum.cash).is_equal(18250)
	assert_int(sum.holes).is_equal(3)
	assert_int(sum.playtime_s).is_equal(5400)
	var r: MHSaveResult = s.load_slot(1)
	assert_bool(r.is_ok()).is_true()
	var ls: MHLoadedSave = r.value
	assert_bool(ls.recovered).is_false()
	assert_bool(ls.migrated).is_false()
	assert_str(ls.json_source).is_equal("main")
	assert_bool(ls.blob == blob).is_true()
	assert_int(int(ls.data["saved_at_unix"])).is_equal(1790000100)
	assert_str(String(ls.data["slot_kind"])).is_equal("manual")
	# the file on disk is exactly the canonical serialisation of the loaded document
	assert_bool(MHSaveFile.read_all(s.json_path(1)) == MHSaveGame.to_bytes(ls.data)).is_true()
	# no leftover temp file
	assert_bool(MHSaveFile.exists(s.json_path(1) + ".tmp")).is_false()


func test_slot_zero_is_autosave_kind() -> void:
	var s: MHSaveStore = _store()
	assert_bool(_save(s, 0, 1).is_ok()).is_true()
	var ls: MHLoadedSave = s.load_slot(0).value
	assert_str(String(ls.data["slot_kind"])).is_equal("autosave")


func test_revision_increments_and_bak_keeps_previous_generation() -> void:
	var s: MHSaveStore = _store()
	assert_int((_save(s, 1, 11).value as MHSaveSummary).revision).is_equal(1)
	assert_int((_save(s, 1, 12).value as MHSaveSummary).revision).is_equal(2)
	assert_int((_save(s, 1, 13).value as MHSaveSummary).revision).is_equal(3)
	assert_int(_revision_of(s.load_slot(1))).is_equal(3)
	var bak: MHSaveResult = MHSaveGame.parse_bytes(MHSaveFile.read_all(s.json_path(1) + ".bak"))
	assert_bool(bak.is_ok()).is_true()
	assert_int(int((bak.value as Dictionary)["revision"])).is_equal(2)


func test_invalid_arguments_are_rejected_without_writing() -> void:
	var s: MHSaveStore = _store()
	assert_int(s.save_slot(9, Fixture.make_doc(), Fixture.make_blob(1)).code).is_equal(MHSaveResult.Code.INVALID_ARGUMENT)
	assert_int(s.save_slot(1, Fixture.make_doc(), PackedByteArray()).code).is_equal(MHSaveResult.Code.INVALID_ARGUMENT)
	assert_int(s.save_slot(1, Fixture.make_doc(), "junk".to_utf8_buffer()).code).is_equal(MHSaveResult.Code.BLOB_CORRUPT)
	var float_doc: Dictionary = Fixture.make_doc()
	(float_doc["club"] as Dictionary)["cash"] = 1.5
	assert_int(s.save_slot(1, float_doc, Fixture.make_blob(1)).code).is_equal(MHSaveResult.Code.BAD_SCHEMA)
	var ironman: Dictionary = Fixture.make_doc()
	ironman["ironman"] = true
	assert_int(s.save_slot(1, ironman, Fixture.make_blob(1)).code).is_equal(MHSaveResult.Code.BAD_SCHEMA)
	assert_bool(MHSaveFile.exists(s.json_path(1))).is_false()
	assert_int(s.load_slot(1).code).is_equal(MHSaveResult.Code.NOT_FOUND)


func test_torn_json_falls_back_to_bak_and_heals() -> void:
	var s: MHSaveStore = _store()
	_save(s, 1, 11)
	_save(s, 1, 11, 20000)
	var good: PackedByteArray = MHSaveFile.read_all(s.json_path(1))
	# a torn main file: half of the bytes
	MHSaveFile.write_plain(s.json_path(1), good.slice(0, good.size() / 2))
	var r: MHSaveResult = s.load_slot(1)
	assert_bool(r.is_ok()).is_true()
	var ls: MHLoadedSave = r.value
	assert_bool(ls.recovered).is_true()
	assert_str(ls.json_source).is_equal("bak")
	assert_int(int(ls.data["revision"])).is_equal(1)
	assert_int(int((ls.data["club"] as Dictionary)["cash"])).is_equal(18250)
	# healed: the main file loads again without recovery
	var again: MHLoadedSave = s.load_slot(1).value
	assert_str(again.json_source).is_equal("main")


func test_all_generations_damaged_fails_and_touches_nothing() -> void:
	var s: MHSaveStore = _store()
	_save(s, 1, 11)
	_save(s, 1, 11)
	var junk: PackedByteArray = "{\"schema\":\"mh.save\",".to_utf8_buffer()
	MHSaveFile.write_plain(s.json_path(1), junk)
	MHSaveFile.write_plain(s.json_path(1) + ".bak", junk)
	var r: MHSaveResult = s.load_slot(1)
	assert_bool(r.is_ok()).is_false()
	assert_int(r.code).is_equal(MHSaveResult.Code.PARSE_ERROR)
	assert_bool(MHSaveFile.read_all(s.json_path(1)) == junk).is_true()
	assert_bool(MHSaveFile.read_all(s.json_path(1) + ".bak") == junk).is_true()


func test_bad_checksum_is_corruption() -> void:
	var s: MHSaveStore = _store()
	_save(s, 1, 11)
	var text: String = MHSaveFile.read_all(s.json_path(1)).get_string_from_utf8().replace('"cash":18250', '"cash":99999')
	MHSaveFile.write_plain(s.json_path(1), text.to_utf8_buffer())
	assert_int(s.load_slot(1).code).is_equal(MHSaveResult.Code.CHECKSUM_MISMATCH)


func test_kill_between_blob_and_json_write_recovers_old_pair() -> void:
	var s: MHSaveStore = _store()
	var blob_a: PackedByteArray = Fixture.make_blob(11)
	var blob_b: PackedByteArray = Fixture.make_blob(12)
	assert_bool(s.save_slot(1, Fixture.make_doc(), blob_a).is_ok()).is_true()
	MHSaveStore.fault_point = MHSaveStore.FaultPoint.AFTER_BLOB_WRITTEN
	var w: MHSaveResult = s.save_slot(1, Fixture.make_doc(), blob_b)
	assert_bool(w.is_ok()).is_false()
	MHSaveStore.fault_point = MHSaveStore.FaultPoint.NONE
	# new blob is in place, old JSON still names the old blob, which now sits in .bak
	assert_bool(MHSaveFile.read_all(s.blob_path(1)) == blob_b).is_true()
	var r: MHSaveResult = s.load_slot(1)
	assert_bool(r.is_ok()).is_true()
	var ls: MHLoadedSave = r.value
	assert_int(int(ls.data["revision"])).is_equal(1)
	assert_bool(ls.blob == blob_a).is_true()
	assert_str(ls.blob_source).is_equal("bak")
	assert_bool(ls.recovered).is_true()
	# healed: the main blob is the matching one again
	assert_bool(MHSaveFile.read_all(s.blob_path(1)) == blob_a).is_true()
	# and the store can save again afterwards
	assert_bool(s.save_slot(1, Fixture.make_doc(), blob_b).is_ok()).is_true()
	assert_int(_revision_of(s.load_slot(1))).is_equal(2)


func test_json_newer_than_blob_falls_back_to_previous_generation() -> void:
	var s: MHSaveStore = _store()
	var blob_a: PackedByteArray = Fixture.make_blob(11)
	var blob_b: PackedByteArray = Fixture.make_blob(12)
	s.save_slot(1, Fixture.make_doc(), blob_a)
	s.save_slot(1, Fixture.make_doc(), blob_b)
	# the second blob write is lost: put the old blob back in both blob files
	MHSaveFile.write_plain(s.blob_path(1), blob_a)
	MHSaveFile.write_plain(s.blob_path(1) + ".bak", blob_a)
	var r: MHSaveResult = s.load_slot(1)
	assert_bool(r.is_ok()).is_true()
	var ls: MHLoadedSave = r.value
	assert_int(int(ls.data["revision"])).is_equal(1)
	assert_bool(ls.blob == blob_a).is_true()
	assert_bool(ls.recovered).is_true()


func test_blob_problems_are_reported_never_partially_loaded() -> void:
	var s: MHSaveStore = _store()
	s.save_slot(1, Fixture.make_doc(), Fixture.make_blob(11))
	# wrong but valid blob and no backup that matches
	MHSaveFile.write_plain(s.blob_path(1), Fixture.make_blob(99))
	assert_int(s.load_slot(1, false).code).is_equal(MHSaveResult.Code.PAIR_MISMATCH)
	# damaged blob
	MHSaveFile.write_plain(s.blob_path(1), "garbage".to_utf8_buffer())
	assert_int(s.load_slot(1, false).code).is_equal(MHSaveResult.Code.BLOB_CORRUPT)
	# missing blob
	MHSaveFile.remove(s.blob_path(1))
	assert_int(s.load_slot(1, false).code).is_equal(MHSaveResult.Code.BLOB_MISSING)


func test_two_failed_pair_writes_do_not_destroy_last_committed_save() -> void:
	var s: MHSaveStore = _store()
	var blob_a: PackedByteArray = Fixture.make_blob(11)
	var blob_b: PackedByteArray = Fixture.make_blob(12)
	var blob_c: PackedByteArray = Fixture.make_blob(13)
	assert_bool(s.save_slot(1, Fixture.make_doc(), blob_a).is_ok()).is_true()

	MHSaveStore.fault_point = MHSaveStore.FaultPoint.AFTER_BLOB_WRITTEN
	var first: Dictionary = Fixture.make_doc()
	(first["club"] as Dictionary)["cash"] = 20000
	assert_bool(s.save_slot(1, first, blob_b).is_ok()).is_false()

	var second: Dictionary = Fixture.make_doc()
	(second["club"] as Dictionary)["cash"] = 30000
	assert_bool(s.save_slot(1, second, blob_c).is_ok()).is_false()
	MHSaveStore.fault_point = MHSaveStore.FaultPoint.NONE

	var loaded: MHSaveResult = s.load_slot(1)
	assert_bool(loaded.is_ok()).is_true()
	assert_int(int(((loaded.value as MHLoadedSave).data["club"] as Dictionary)["cash"])).is_equal(18250)
	assert_int(_revision_of(loaded)).is_equal(1)


func test_write_killed_mid_temp_write_leaves_old_save_loadable() -> void:
	var s: MHSaveStore = _store()
	_save(s, 1, 11)
	MHSaveFile.fault_point = MHSaveFile.FaultPoint.MID_TEMP_WRITE
	var w: MHSaveResult = _save(s, 1, 11, 5)
	assert_bool(w.is_ok()).is_false()
	MHSaveFile.fault_point = MHSaveFile.FaultPoint.NONE
	var r: MHSaveResult = s.load_slot(1)
	assert_bool(r.is_ok()).is_true()
	assert_int(int(((r.value as MHLoadedSave).data["club"] as Dictionary)["cash"])).is_equal(18250)
	assert_int(_revision_of(r)).is_equal(1)


func test_write_killed_after_bak_rotation_recovers_from_complete_tmp() -> void:
	var s: MHSaveStore = _store()
	_save(s, 1, 11)
	MHSaveFile.fault_point = MHSaveFile.FaultPoint.AFTER_BAK_ROTATE
	assert_bool(_save(s, 1, 11, 7777).is_ok()).is_false()
	MHSaveFile.fault_point = MHSaveFile.FaultPoint.NONE
	# the main file is gone: the finished temp file (revision 2) is the newest valid generation
	assert_bool(MHSaveFile.exists(s.json_path(1))).is_false()
	var r: MHSaveResult = s.load_slot(1)
	assert_bool(r.is_ok()).is_true()
	var ls: MHLoadedSave = r.value
	assert_str(ls.json_source).is_equal("tmp")
	assert_int(int(ls.data["revision"])).is_equal(2)
	assert_int(int((ls.data["club"] as Dictionary)["cash"])).is_equal(7777)
	assert_bool(MHSaveFile.exists(s.json_path(1))).is_true()


func test_future_save_needs_app_update_and_is_not_touched() -> void:
	var s: MHSaveStore = _store()
	var doc: Dictionary = Fixture.make_doc()
	doc["slot"] = 2
	doc["min_reader_version"] = MHSaveGame.READER_VERSION + 1
	MHSaveGame.seal(doc)
	var bytes: PackedByteArray = MHSaveGame.to_bytes(doc)
	MHSaveFile.ensure_dir(DIR)
	MHSaveFile.write_plain(s.json_path(2), bytes)
	var r: MHSaveResult = s.load_slot(2)
	assert_int(r.code).is_equal(MHSaveResult.Code.NEEDS_APP_UPDATE)
	var rows: Array[MHSlotInfo] = s.list_slots()
	assert_bool(rows[2].present).is_true()
	assert_bool(rows[2].valid).is_false()
	assert_bool(rows[2].needs_app_update()).is_true()
	assert_bool(MHSaveFile.read_all(s.json_path(2)) == bytes).is_true()


func test_list_slots() -> void:
	var s: MHSaveStore = _store()
	_save(s, 0, 1)
	_save(s, 3, 2, 777)
	MHSaveFile.write_plain(s.json_path(4), "nope".to_utf8_buffer())
	var rows: Array[MHSlotInfo] = s.list_slots(true)
	assert_int(rows.size()).is_equal(MHSaveGame.MAX_SLOTS)
	assert_bool(rows[0].valid).is_true()
	assert_str(rows[0].kind).is_equal("autosave")
	assert_bool(rows[1].present).is_false()
	assert_bool(rows[3].valid).is_true()
	assert_int(rows[3].summary.cash).is_equal(777)
	assert_int(rows[3].summary.day).is_equal(17)
	assert_bool(rows[4].present).is_true()
	assert_bool(rows[4].valid).is_false()
	assert_int(rows[4].error_code).is_equal(MHSaveResult.Code.PARSE_ERROR)


func test_autosave_if_due_follows_game_hours() -> void:
	var s: MHSaveStore = _store()
	var blob: PackedByteArray = Fixture.make_blob(5)
	var r1: MHSaveResult = s.autosave_if_due(Fixture.make_doc(), blob, 0)
	assert_bool(r1.is_ok()).is_true()
	assert_bool(r1.value != null).is_true()
	assert_int(s.last_saved_hour).is_equal(0)
	assert_bool(s.autosave_if_due(Fixture.make_doc(), blob, 30).value == null).is_true()
	assert_bool(s.autosave_if_due(Fixture.make_doc(), blob, 59).value == null).is_true()
	assert_bool(s.autosave_if_due(Fixture.make_doc(), blob, 60).value != null).is_true()
	# fast forward over several hours saves once
	var r4: MHSaveResult = s.autosave_if_due(Fixture.make_doc(), blob, 400)
	assert_int((r4.value as MHSaveSummary).revision).is_equal(3)
	assert_int(s.last_saved_hour).is_equal(6)
	assert_bool(s.autosave_if_due(Fixture.make_doc(), blob, 419).value == null).is_true()
	assert_int(_revision_of(s.load_slot(0))).is_equal(3)


func test_export_import_round_trip_and_overwrite_confirmation() -> void:
	var s: MHSaveStore = _store()
	_save(s, 1, 11, 4242)
	var ex: MHSaveResult = s.export_slot(1)
	assert_bool(ex.is_ok()).is_true()
	var pack: Dictionary = ex.value
	var json_bytes: PackedByteArray = pack["json"]
	var blob: PackedByteArray = pack["blob"]
	var imp: MHSaveResult = s.import_slot(json_bytes, blob, 3, false)
	assert_bool(imp.is_ok()).is_true()
	var ls: MHLoadedSave = s.load_slot(3).value
	assert_int(int((ls.data["club"] as Dictionary)["cash"])).is_equal(4242)
	assert_int(int(ls.data["slot"])).is_equal(3)
	assert_int(int(ls.data["revision"])).is_equal(1)
	assert_bool(ls.blob == blob).is_true()
	# an occupied slot is never replaced without confirmation
	assert_int(s.import_slot(json_bytes, blob, 3, false).code).is_equal(MHSaveResult.Code.SLOT_OCCUPIED)
	assert_bool(s.import_slot(json_bytes, blob, 3, true).is_ok()).is_true()


func test_import_validates_everything_before_touching_a_slot() -> void:
	var s: MHSaveStore = _store()
	_save(s, 1, 11)
	var pack: Dictionary = s.export_slot(1).value
	var json_bytes: PackedByteArray = pack["json"]
	var other_blob: PackedByteArray = Fixture.make_blob(77)
	assert_int(s.import_slot(json_bytes, other_blob, 2, false).code).is_equal(MHSaveResult.Code.PAIR_MISMATCH)
	assert_int(s.import_slot(json_bytes, "junk".to_utf8_buffer(), 2, false).code).is_equal(MHSaveResult.Code.BLOB_CORRUPT)
	assert_int(s.import_slot("{}".to_utf8_buffer(), PackedByteArray(), 2, false).code).is_equal(MHSaveResult.Code.BAD_SCHEMA)
	assert_int(s.import_slot(json_bytes, pack["blob"], 8, false).code).is_equal(MHSaveResult.Code.INVALID_ARGUMENT)
	assert_bool(MHSaveFile.exists(s.json_path(2))).is_false()
	assert_bool(MHSaveFile.exists(s.blob_path(2))).is_false()


func test_delete_slot_removes_every_file() -> void:
	var s: MHSaveStore = _store()
	_save(s, 2, 11)
	_save(s, 2, 12)
	assert_bool(MHSaveFile.exists(s.json_path(2) + ".bak")).is_true()
	var d: MHSaveResult = s.delete_slot(2)
	assert_bool(d.is_ok()).is_true()
	assert_int(int(d.value)).is_greater(3)
	assert_bool(s.list_slots()[2].present).is_false()
	assert_int(s.load_slot(2).code).is_equal(MHSaveResult.Code.NOT_FOUND)


func _step_v1_to_v2(d: Dictionary) -> Dictionary:
	var club: Dictionary = d["club"]
	club["green_fee"] = int(club["green_fee"]) + 1
	return d


func test_store_migrates_an_old_file_and_keeps_a_premigrate_copy() -> void:
	var s: MHSaveStore = _store()
	_save(s, 1, 11)
	var original: PackedByteArray = MHSaveFile.read_all(s.json_path(1))
	var m := MHSaveMigrator.new()
	m.target_version = 2
	assert_bool(m.register_step(1, Callable(self, "_step_v1_to_v2"))).is_true()
	s.migrator = m
	var r: MHSaveResult = s.load_slot(1)
	assert_bool(r.is_ok()).is_true()
	var ls: MHLoadedSave = r.value
	assert_bool(ls.migrated).is_true()
	assert_int(ls.from_version).is_equal(1)
	assert_int(int(ls.data["save_version"])).is_equal(2)
	assert_int(int((ls.data["club"] as Dictionary)["green_fee"])).is_equal(36)
	assert_bool(MHSaveGame.checksum_ok(ls.data)).is_true()
	assert_bool(MHSaveFile.read_all(s.premigrate_path(1)) == original).is_true()
