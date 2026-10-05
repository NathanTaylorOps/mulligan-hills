extends GdUnitTestSuite
## MHSaveMigrator registry: ordered steps, purity, determinism-state guard, failure cases. NOT YET RUN in Godot.

const Fixture = preload("res://tests/save/save_fixture.gd")


func _v1_to_v2(d: Dictionary) -> Dictionary:
	var club: Dictionary = d["club"]
	club["green_fee"] = int(club["green_fee"]) + 1
	return d


func _v2_to_v3(d: Dictionary) -> Dictionary:
	var club: Dictionary = d["club"]
	club["members"] = int(club["members"]) * 2
	return d


func _changes_seed(d: Dictionary) -> Dictionary:
	var sim: Dictionary = d["sim"]
	sim["rng_seed"] = "0000000000000001"
	return d


func _returns_float(d: Dictionary) -> Dictionary:
	var club: Dictionary = d["club"]
	club["cash"] = 1.5
	return d


func _make(target: int) -> MHSaveMigrator:
	var m := MHSaveMigrator.new()
	m.target_version = target
	return m


func test_default_registry_matches_current_version() -> void:
	var m: MHSaveMigrator = MHSaveMigrator.create_default()
	assert_int(m.target_version).is_equal(MHSaveGame.SAVE_VERSION)
	# every version below the current one needs a registered step, none above
	for v in range(1, MHSaveGame.SAVE_VERSION):
		assert_bool(m.has_step(v)).is_true()
	assert_bool(m.has_step(MHSaveGame.SAVE_VERSION)).is_false()


func test_version_one_document_needs_no_migration_today() -> void:
	var m: MHSaveMigrator = MHSaveMigrator.create_default()
	var doc: Dictionary = Fixture.make_doc()
	assert_bool(m.needs_migration(doc)).is_equal(MHSaveGame.SAVE_VERSION > 1)
	var r: MHSaveResult = m.migrate(doc)
	assert_bool(r.is_ok()).is_true()
	assert_int(m.last_steps_applied).is_equal(0)


func test_single_step_applies_and_does_not_mutate_the_input() -> void:
	var m: MHSaveMigrator = _make(2)
	assert_bool(m.register_step(1, Callable(self, "_v1_to_v2"))).is_true()
	var doc: Dictionary = Fixture.make_doc()
	var before: String = MHSaveGame.canonical_json(doc)
	assert_bool(m.needs_migration(doc)).is_true()
	var r: MHSaveResult = m.migrate(doc)
	assert_bool(r.is_ok()).is_true()
	var out: Dictionary = r.value
	assert_int(int(out["save_version"])).is_equal(2)
	assert_int(int((out["club"] as Dictionary)["green_fee"])).is_equal(36)
	assert_int(m.last_steps_applied).is_equal(1)
	assert_str(MHSaveGame.canonical_json(doc)).is_equal(before)


func test_steps_run_in_order_and_never_skip() -> void:
	var m: MHSaveMigrator = _make(3)
	m.register_step(1, Callable(self, "_v1_to_v2"))
	m.register_step(2, Callable(self, "_v2_to_v3"))
	assert_array(m.registered_versions()).contains_exactly([1, 2])
	var r: MHSaveResult = m.migrate(Fixture.make_doc())
	assert_bool(r.is_ok()).is_true()
	var out: Dictionary = r.value
	assert_int(int(out["save_version"])).is_equal(3)
	assert_int(int((out["club"] as Dictionary)["green_fee"])).is_equal(36)
	assert_int(int((out["club"] as Dictionary)["members"])).is_equal(24)
	assert_int(m.last_steps_applied).is_equal(2)
	# a gap in the registry fails instead of skipping
	var gap: MHSaveMigrator = _make(3)
	gap.register_step(2, Callable(self, "_v2_to_v3"))
	assert_int(gap.migrate(Fixture.make_doc()).code).is_equal(MHSaveResult.Code.MIGRATION_FAILED)


func test_migration_is_deterministic() -> void:
	var m: MHSaveMigrator = _make(3)
	m.register_step(1, Callable(self, "_v1_to_v2"))
	m.register_step(2, Callable(self, "_v2_to_v3"))
	var a: Dictionary = m.migrate(Fixture.make_doc()).value
	var b: Dictionary = m.migrate(Fixture.make_doc()).value
	assert_str(MHSaveGame.canonical_json(a)).is_equal(MHSaveGame.canonical_json(b))


func test_step_may_not_change_determinism_state() -> void:
	var m: MHSaveMigrator = _make(2)
	m.register_step(1, Callable(self, "_changes_seed"))
	assert_int(m.migrate(Fixture.make_doc()).code).is_equal(MHSaveResult.Code.MIGRATION_FAILED)


func test_step_output_is_normalised_and_checked() -> void:
	var m: MHSaveMigrator = _make(2)
	m.register_step(1, Callable(self, "_returns_float"))
	assert_int(m.migrate(Fixture.make_doc()).code).is_equal(MHSaveResult.Code.MIGRATION_FAILED)


func test_register_step_rules() -> void:
	var m: MHSaveMigrator = _make(2)
	assert_bool(m.register_step(1, Callable(self, "_v1_to_v2"))).is_true()
	assert_bool(m.register_step(1, Callable(self, "_v1_to_v2"))).is_false()
	assert_bool(m.register_step(-1, Callable(self, "_v1_to_v2"))).is_false()
	assert_bool(m.register_step(5, Callable())).is_false()


func test_missing_or_odd_version_fails() -> void:
	var m: MHSaveMigrator = _make(2)
	assert_int(m.migrate({}).code).is_equal(MHSaveResult.Code.MIGRATION_FAILED)
	assert_int(m.migrate({"save_version": "1"}).code).is_equal(MHSaveResult.Code.MIGRATION_FAILED)
	# a file already at or beyond the target is returned unchanged
	var newer: Dictionary = {"save_version": 9, "x": 1}
	var r: MHSaveResult = m.migrate(newer)
	assert_bool(r.is_ok()).is_true()
	assert_int(int((r.value as Dictionary)["save_version"])).is_equal(9)
