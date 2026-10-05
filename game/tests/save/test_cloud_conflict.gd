extends GdUnitTestSuite
## MHCloudConflict (always ask, DEC-058) and MHAutosavePolicy (hourly, DEC-052). NOT YET RUN in Godot.


func _summary(rev: int, checksum: String, install: String, day: int, cash: int, holes: int, play: int, at: int) -> MHSaveSummary:
	var s := MHSaveSummary.new()
	s.slot = 1
	s.revision = rev
	s.checksum = checksum
	s.install_id = install
	s.day = day
	s.cash = cash
	s.holes = holes
	s.playtime_s = play
	s.saved_at_unix = at
	return s


func test_differing_saves_always_prompt() -> void:
	var local: MHSaveSummary = _summary(5, "aa", "phone", 20, 5000, 6, 3600, 100)
	var cloud: MHSaveSummary = _summary(9, "bb", "tablet", 31, 9000, 9, 7200, 200)
	var c: MHCloudConflict = MHCloudConflict.detect(local, cloud)
	assert_int(c.kind).is_equal(MHCloudConflict.Kind.CONFLICT)
	assert_bool(c.needs_prompt()).is_true()
	assert_bool(c.other_device).is_true()
	assert_bool(c.cloud_has_higher_revision).is_true()


func test_a_higher_revision_never_wins_silently() -> void:
	# even when local is far ahead the player is still asked
	var local: MHSaveSummary = _summary(50, "aa", "phone", 90, 99999, 18, 90000, 300)
	var cloud: MHSaveSummary = _summary(2, "bb", "phone", 3, 100, 1, 60, 10)
	var c: MHCloudConflict = MHCloudConflict.detect(local, cloud)
	assert_bool(c.needs_prompt()).is_true()
	assert_bool(c.cloud_has_higher_revision).is_false()
	assert_bool(c.other_device).is_false()


func test_identical_checksums_are_in_sync() -> void:
	var a: MHSaveSummary = _summary(5, "same", "phone", 20, 5000, 6, 3600, 100)
	var b: MHSaveSummary = _summary(5, "same", "phone", 20, 5000, 6, 3600, 100)
	var c: MHCloudConflict = MHCloudConflict.detect(a, b)
	assert_int(c.kind).is_equal(MHCloudConflict.Kind.IN_SYNC)
	assert_bool(c.needs_prompt()).is_false()


func test_missing_sides() -> void:
	var a: MHSaveSummary = _summary(5, "aa", "phone", 20, 5000, 6, 3600, 100)
	assert_int(MHCloudConflict.detect(a, null).kind).is_equal(MHCloudConflict.Kind.LOCAL_ONLY)
	assert_int(MHCloudConflict.detect(null, a).kind).is_equal(MHCloudConflict.Kind.CLOUD_ONLY)
	assert_int(MHCloudConflict.detect(null, null).kind).is_equal(MHCloudConflict.Kind.IN_SYNC)
	assert_bool(MHCloudConflict.detect(a, null).needs_prompt()).is_false()
	assert_int(MHCloudConflict.detect(a, null).rows().size()).is_equal(0)


func test_rows_show_day_cash_holes_and_playtime() -> void:
	var local: MHSaveSummary = _summary(5, "aa", "phone", 20, 5000, 6, 3600, 100)
	var cloud: MHSaveSummary = _summary(9, "bb", "phone", 20, 9000, 9, 7200, 200)
	var rows: Array = MHCloudConflict.detect(local, cloud).rows()
	assert_int(rows.size()).is_equal(5)
	var fields: Array = []
	for r in rows:
		fields.append(String((r as Dictionary)["field"]))
	assert_array(fields).contains_exactly(["day", "cash", "holes", "playtime_s", "saved_at_unix"])
	var day_row: Dictionary = rows[0]
	assert_bool(bool(day_row["differs"])).is_false()
	var cash_row: Dictionary = rows[1]
	assert_int(int(cash_row["local"])).is_equal(5000)
	assert_int(int(cash_row["cloud"])).is_equal(9000)
	assert_bool(bool(cash_row["differs"])).is_true()


func test_choices_and_actions() -> void:
	var local: MHSaveSummary = _summary(5, "aa", "phone", 20, 5000, 6, 3600, 100)
	var cloud: MHSaveSummary = _summary(9, "bb", "phone", 21, 9000, 9, 7200, 200)
	var c: MHCloudConflict = MHCloudConflict.detect(local, cloud)
	assert_str(String((c.resolve(MHCloudConflict.Choice.KEEP_LOCAL).value as Dictionary)["action"])).is_equal("keep_local")
	assert_str(String((c.resolve(MHCloudConflict.Choice.USE_CLOUD).value as Dictionary)["action"])).is_equal("import_cloud_overwrite")
	assert_str(String((c.resolve(MHCloudConflict.Choice.KEEP_BOTH).value as Dictionary)["action"])).is_equal("import_cloud_new_slot")
	assert_str(String((c.resolve(MHCloudConflict.Choice.CANCEL).value as Dictionary)["action"])).is_equal("none")
	assert_bool(c.resolve(99).is_ok()).is_false()
	# without a conflict only CANCEL is legal
	var sync: MHCloudConflict = MHCloudConflict.detect(local, local)
	assert_bool(sync.resolve(MHCloudConflict.Choice.USE_CLOUD).is_ok()).is_false()
	assert_bool(sync.resolve(MHCloudConflict.Choice.CANCEL).is_ok()).is_true()


func test_summary_dict_round_trip_for_the_cloud_service() -> void:
	var s: MHSaveSummary = _summary(5, "aa", "phone", 20, 5000, 6, 3600, 100)
	var parsed: Variant = JSON.parse_string(JSON.stringify(s.to_dict()))
	var back: MHSaveSummary = MHSaveSummary.from_dict(parsed as Dictionary)
	assert_bool(back.to_dict() == s.to_dict()).is_true()


func test_free_manual_slot_skips_used_slots_and_slot_zero() -> void:
	var rows: Array[MHSlotInfo] = []
	for i in range(MHSaveGame.MAX_SLOTS):
		var info := MHSlotInfo.new()
		info.slot = i
		info.present = i == 0 or i == 1 or i == 3
		rows.append(info)
	assert_int(MHCloudConflict.free_manual_slot(rows)).is_equal(2)
	rows[2].present = true
	rows[4].present = true
	assert_int(MHCloudConflict.free_manual_slot(rows)).is_equal(-1)


func test_autosave_policy_hours() -> void:
	assert_int(MHAutosavePolicy.hour_of(0)).is_equal(0)
	assert_int(MHAutosavePolicy.hour_of(59)).is_equal(0)
	assert_int(MHAutosavePolicy.hour_of(60)).is_equal(1)
	assert_int(MHAutosavePolicy.hour_of(660)).is_equal(11)
	assert_int(MHAutosavePolicy.hour_of(-5)).is_equal(-1)
	assert_bool(MHAutosavePolicy.should_autosave(0, -1)).is_true()
	assert_bool(MHAutosavePolicy.should_autosave(59, 0)).is_false()
	assert_bool(MHAutosavePolicy.should_autosave(60, 0)).is_true()
	assert_bool(MHAutosavePolicy.should_autosave(500, 3)).is_true()
	assert_bool(MHAutosavePolicy.should_autosave(500, 8)).is_false()
	assert_bool(MHAutosavePolicy.should_autosave(-1, -1)).is_false()
	# loading an older save: nothing due until the hour passes the last saved one
	assert_bool(MHAutosavePolicy.should_autosave(120, 9)).is_false()


func test_autosave_policy_matches_clock_hour_events() -> void:
	# one real game day at 1x: the policy fires exactly once per clock hour event
	var clock: MHGameClock = MHGameClock.new()
	var last_hour: int = -1
	var saves: int = 0
	for i in range(900):
		clock.step(1000000)
		if MHAutosavePolicy.should_autosave(clock.total_minutes(), last_hour):
			saves += 1
			last_hour = MHAutosavePolicy.hour_of(clock.total_minutes())
	# hour 0 at the first minute, then hours 1 to 11 (minute 660 is hour 11)
	assert_int(saves).is_equal(12)
