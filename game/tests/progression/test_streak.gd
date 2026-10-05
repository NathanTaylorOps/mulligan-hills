extends GdUnitTestSuite
## MHStreak: grace days, soft resume, milestones, persistence. NOT YET RUN in Godot.


func _run(s: MHStreak, days: Array) -> void:
	for d: Variant in days:
		s.record_active(int(d))


func test_configured_from_data() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	assert_int(s.grace).is_equal(1)
	assert_int(s.grace_max).is_equal(2)
	assert_int(s.regain_every_days).is_equal(7)
	assert_int(s.max_bridge_days).is_equal(2)
	assert_int(s.resume_percent).is_equal(50)
	assert_int(s.milestones.size()).is_equal(6)


func test_first_day_starts_the_streak() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	var r: Dictionary = s.record_active(100)
	assert_bool(bool(r["changed"])).is_true()
	assert_int(int(r["streak"])).is_equal(1)
	assert_int(s.best).is_equal(1)
	assert_int(s.active_days).is_equal(1)
	assert_int(s.last_day).is_equal(100)


func test_same_day_and_earlier_day_do_nothing() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	_run(s, [10, 11])
	assert_bool(bool(s.record_active(11)["changed"])).is_false()
	assert_bool(bool(s.record_active(5)["changed"])).is_false()
	assert_bool(bool(s.record_active(-3)["changed"])).is_false()
	assert_int(s.current).is_equal(2)
	assert_int(s.active_days).is_equal(2)
	assert_int(s.last_day).is_equal(11)


func test_consecutive_days_extend_and_pay_milestones_once() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	s.record_active(0)
	s.record_active(1)
	var r3: Dictionary = s.record_active(2)
	assert_int(int(r3["streak"])).is_equal(3)
	assert_int(int(r3["milestone_points"])).is_equal(10)
	assert_int((r3["milestone_days"] as Array).size()).is_equal(1)
	assert_int(int((r3["milestone_days"] as Array)[0])).is_equal(3)
	assert_int(int(s.record_active(3)["milestone_points"])).is_equal(0)
	assert_int(s.milestone_points_total()).is_equal(10)


func test_grace_bridges_one_gap() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	_run(s, [0, 1, 2, 3])
	assert_int(s.current).is_equal(4)
	var r: Dictionary = s.record_active(5)
	assert_bool(bool(r["used_grace"])).is_true()
	assert_bool(bool(r["resumed"])).is_false()
	assert_int(s.current).is_equal(5)
	assert_int(s.grace).is_equal(0)


func test_gap_of_two_missed_days_can_still_be_bridged() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	_run(s, [0, 1, 2])
	var r: Dictionary = s.record_active(5)
	assert_bool(bool(r["used_grace"])).is_true()
	assert_int(s.current).is_equal(4)


func test_without_grace_the_streak_resumes_at_half_never_zero() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	_run(s, [0, 1, 2, 3, 5])
	# grace now spent, streak 5; miss day 6, play day 7
	var r: Dictionary = s.record_active(7)
	assert_bool(bool(r["resumed"])).is_true()
	assert_bool(bool(r["used_grace"])).is_false()
	assert_int(s.current).is_equal(3)
	assert_int(s.best).is_equal(5)
	# milestone 3 was already paid: a second climb through 3 pays nothing
	assert_int(int(r["milestone_points"])).is_equal(0)


func test_long_gap_resumes_even_with_grace() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	_run(s, [0, 1, 2])
	var r: Dictionary = s.record_active(6)
	assert_bool(bool(r["resumed"])).is_true()
	assert_int(s.grace).is_equal(1)
	assert_int(s.current).is_equal(2)


func test_resume_from_one_is_one() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	s.record_active(0)
	s.record_active(50)
	assert_int(s.current).is_equal(1)
	assert_bool(s.current > 0).is_true()


func test_grace_is_regained_every_seven_days_up_to_the_max() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	for day: int in range(7):
		s.record_active(day)
	assert_int(s.current).is_equal(7)
	assert_int(s.grace).is_equal(2)
	for day2: int in range(7, 14):
		s.record_active(day2)
	assert_int(s.current).is_equal(14)
	assert_int(s.grace).is_equal(2)
	assert_int(s.milestone_points_total()).is_equal(75)


func test_milestone_table_pays_each_step() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	var total: int = 0
	for day: int in range(100):
		total += int(s.record_active(day)["milestone_points"])
	# 10 + 25 + 40 + 75 + 120 + 200
	assert_int(total).is_equal(470)
	assert_int(s.milestone_points_total()).is_equal(470)
	assert_int(s.claimed_milestones().size()).is_equal(6)
	assert_int(s.best).is_equal(100)


func test_display_streak() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	assert_int(s.display_streak(5)).is_equal(0)
	_run(s, [0, 1, 2, 3])
	assert_int(s.display_streak(3)).is_equal(4)
	assert_int(s.display_streak(4)).is_equal(4)
	# one missed day and a grace available: still alive
	assert_int(s.display_streak(5)).is_equal(4)
	# too long a gap: shows the value it would resume from
	assert_int(s.display_streak(20)).is_equal(2)


func test_round_trip() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	_run(s, [0, 1, 2, 3, 5, 6])
	var d: Dictionary = s.to_dict()
	var t: MHStreak = MHProgressionFixture.streak()
	assert_bool(t.from_dict(d)).is_true()
	assert_bool(t.to_dict() == d).is_true()
	assert_int(t.current).is_equal(s.current)
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var u: MHStreak = MHProgressionFixture.streak()
	assert_bool(u.from_dict(parsed as Dictionary)).is_true()
	assert_bool(u.to_dict() == d).is_true()
	var bad: Dictionary = d.duplicate(true)
	bad["v"] = 9
	assert_bool(MHProgressionFixture.streak().from_dict(bad)).is_false()
	var bad2: Dictionary = d.duplicate(true)
	bad2["claimed"] = [0]
	assert_bool(MHProgressionFixture.streak().from_dict(bad2)).is_false()


func test_configure_rejects_bad_blocks() -> void:
	var s: MHStreak = MHStreak.new()
	assert_bool(s.configure({})).is_false()
	var raw: Dictionary = MHDataJson.load_file(MHProgressionFixture.PROGRESSION_PATH)["value"]
	var blk: Dictionary = raw["streak"]
	blk["grace_regain_every_days"] = 0
	assert_bool(s.configure(blk)).is_false()
	var raw2: Dictionary = MHDataJson.load_file(MHProgressionFixture.PROGRESSION_PATH)["value"]
	var blk2: Dictionary = raw2["streak"]
	(blk2["milestones"] as Array).reverse()
	assert_bool(s.configure(blk2)).is_false()


func test_save_block_round_trip_has_no_version_tag() -> void:
	var s: MHStreak = MHProgressionFixture.streak()
	_run(s, [0, 1, 2, 3, 5, 6])
	var blk: Dictionary = s.to_save_block()
	assert_bool(blk.has("v")).is_false()
	for key: String in ["current", "best", "grace", "active_days", "last_day", "claimed"]:
		assert_bool(blk.has(key)).is_true()
	var parsed: Variant = JSON.parse_string(JSON.stringify(blk))
	var t: MHStreak = MHProgressionFixture.streak()
	assert_bool(t.from_save_block(parsed as Dictionary)).is_true()
	assert_bool(t.to_save_block() == blk).is_true()
	var bad: Dictionary = blk.duplicate(true)
	bad.erase("best")
	assert_bool(MHProgressionFixture.streak().from_save_block(bad)).is_false()
