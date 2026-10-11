extends GdUnitTestSuite
## MHPlayerSettings (analytics consent, opt-in default false), MHJsonFile, MHAccountDeletion. NOT YET RUN in Godot.

const Fixture = preload("res://tests/save/save_fixture.gd")
const DIR: String = "user://mh_test_settings"
const SAVES: String = "user://mh_test_settings_saves"


func before_test() -> void:
	Fixture.wipe_dir(DIR)
	Fixture.wipe_dir(SAVES)


func after_test() -> void:
	Fixture.wipe_dir(DIR)
	Fixture.wipe_dir(SAVES)


func test_consent_defaults_to_false_and_is_asked_once() -> void:
	var s := MHPlayerSettings.new(DIR + "/settings.json")
	assert_bool(s.analytics_consent).is_false()
	assert_bool(s.needs_consent_prompt()).is_true()
	s.set_consent(false)
	assert_bool(s.analytics_consent).is_false()
	assert_bool(s.needs_consent_prompt()).is_false()


func test_first_launch_load_keeps_safe_defaults() -> void:
	var s := MHPlayerSettings.new(DIR + "/settings.json")
	var r: MHSaveResult = s.load_from_disk()
	assert_int(r.code).is_equal(MHSaveResult.Code.NOT_FOUND)
	assert_bool(s.analytics_consent).is_false()
	assert_bool(s.needs_consent_prompt()).is_true()


func test_save_and_load_round_trip() -> void:
	var path: String = DIR + "/settings.json"
	var s := MHPlayerSettings.new(path)
	s.set_consent(true)
	s.install_id = "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d"
	assert_int(s.save()).is_equal(OK)
	var t := MHPlayerSettings.new(path)
	assert_bool(t.load_from_disk().is_ok()).is_true()
	assert_bool(t.analytics_consent).is_true()
	assert_bool(t.consent_asked).is_true()
	assert_str(t.install_id).is_equal("9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d")


func test_damaged_file_falls_back_to_bak_then_to_defaults() -> void:
	var path: String = DIR + "/settings.json"
	var s := MHPlayerSettings.new(path)
	s.set_consent(true)
	s.save()
	s.set_consent(false)
	s.save()
	MHSaveFile.write_plain(path, "{broken".to_utf8_buffer())
	var t := MHPlayerSettings.new(path)
	assert_bool(t.load_from_disk().is_ok()).is_true()
	assert_bool(t.analytics_consent).is_false() # stale backup must never re-enable analytics
	assert_bool(t.consent_asked).is_true()
	assert_str(t.install_id).is_equal("")
	MHSaveFile.write_plain(path + ".bak", "{broken".to_utf8_buffer())
	var u := MHPlayerSettings.new(path)
	assert_bool(u.load_from_disk().is_ok()).is_false()
	assert_bool(u.analytics_consent).is_false()


func test_non_boolean_consent_value_is_not_consent() -> void:
	var s := MHPlayerSettings.new(DIR + "/settings.json")
	s.from_dict({"analytics_consent": 1, "consent_asked": "yes"})
	assert_bool(s.analytics_consent).is_false()
	assert_bool(s.consent_asked).is_false()


func test_settings_are_never_part_of_a_save_document() -> void:
	var doc: Dictionary = Fixture.make_doc()
	assert_bool(doc.has("analytics_consent")).is_false()
	doc["analytics_consent"] = true
	MHSaveGame.seal(doc)
	assert_bool(MHSaveGame.validate(doc).is_empty()).is_false()


func test_uuid_formatting() -> void:
	var bytes: PackedByteArray = PackedByteArray([0, 1, 2, 3, 4, 5, 255, 7, 255, 9, 10, 11, 12, 13, 14, 15])
	assert_str(MHPlayerSettings.uuid_from_bytes(bytes)).is_equal("00010203-0405-4f07-bf09-0a0b0c0d0e0f")
	var id: String = MHPlayerSettings.generate_install_id()
	assert_int(id.length()).is_equal(36)
	assert_str(id.substr(14, 1)).is_equal("4")


func test_ensure_install_id_is_stable() -> void:
	var s := MHPlayerSettings.new(DIR + "/settings.json")
	var a: String = s.ensure_install_id()
	assert_str(s.ensure_install_id()).is_equal(a)


func test_account_deletion_request_lists_server_data_and_keeps_purchases() -> void:
	var req: Dictionary = MHAccountDeletion.build_request("abc")
	assert_str(String(req["install_id"])).is_equal("abc")
	assert_bool((req["delete"] as Array).has("cloud_saves")).is_true()
	assert_bool((req["delete"] as Array).has("analytics_events")).is_true()
	assert_bool((req["keep"] as Array).has("store_purchases")).is_true()


func test_account_deletion_keeps_local_saves_by_default() -> void:
	var settings := MHPlayerSettings.new(DIR + "/settings.json")
	settings.set_consent(true)
	settings.install_id = "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d"
	settings.save()
	var store := MHSaveStore.new(SAVES)
	store.save_slot(1, Fixture.make_doc(), Fixture.make_blob(1))
	var r: MHSaveResult = MHAccountDeletion.delete_local(settings, store, false)
	assert_bool(r.is_ok()).is_true()
	assert_int(int((r.value as Dictionary)["slots_deleted"])).is_equal(0)
	assert_bool(settings.analytics_consent).is_false()
	assert_bool(settings.needs_consent_prompt()).is_true()
	assert_bool(settings.install_id != "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d").is_true()
	assert_bool(store.load_slot(1).is_ok()).is_true()
	# the reset is on disk too
	var back := MHPlayerSettings.new(DIR + "/settings.json")
	back.load_from_disk()
	assert_bool(back.analytics_consent).is_false()


func test_account_deletion_can_also_wipe_local_saves() -> void:
	var settings := MHPlayerSettings.new(DIR + "/settings.json")
	var store := MHSaveStore.new(SAVES)
	store.save_slot(1, Fixture.make_doc(), Fixture.make_blob(1))
	store.save_slot(2, Fixture.make_doc(), Fixture.make_blob(2))
	var r: MHSaveResult = MHAccountDeletion.delete_local(settings, store, true)
	assert_bool(r.is_ok()).is_true()
	assert_int(int((r.value as Dictionary)["slots_deleted"])).is_equal(2)
	assert_int(store.load_slot(1).code).is_equal(MHSaveResult.Code.NOT_FOUND)
	assert_int(store.load_slot(2).code).is_equal(MHSaveResult.Code.NOT_FOUND)
