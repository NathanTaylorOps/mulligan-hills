extends GdUnitTestSuite
## MHDailyState: attempts, counters, history, local board, persistence. NOT YET RUN in Godot.


func test_defaults_match_the_data_file() -> void:
	var s: MHDailyState = MHDailyState.new()
	var c: MHDailyChallenge = MHDailyChallenge.new()
	c.load_from_file("res://data/daily_challenges.json")
	assert_int(s.attempts_per_day).is_equal(c.attempts_per_day())
	assert_int(s.history_days).is_equal(c.history_days())
	assert_int(s.board_cap).is_equal(c.local_board_cap())
	s.attempts_per_day = 1
	s.configure(c)
	assert_int(s.attempts_per_day).is_equal(3)


func test_three_attempts_per_day() -> void:
	var s: MHDailyState = MHDailyState.new()
	assert_int(s.attempts_left(10)).is_equal(3)
	var r1: Dictionary = s.record_attempt(10, false, 400, 500)
	assert_bool(bool(r1["ok"])).is_true()
	assert_bool(bool(r1["first_attempt"])).is_true()
	assert_int(int(r1["attempts_left"])).is_equal(2)
	var r2: Dictionary = s.record_attempt(10, false, 450, 500)
	assert_bool(bool(r2["first_attempt"])).is_false()
	var r3: Dictionary = s.record_attempt(10, false, 300, 500)
	assert_int(int(r3["attempts_left"])).is_equal(0)
	var r4: Dictionary = s.record_attempt(10, true, 900, 900)
	assert_bool(bool(r4["ok"])).is_false()
	assert_str(str(r4["reason"])).is_equal("no_attempts")
	assert_int(s.attempts_used(10)).is_equal(3)
	assert_bool(s.completed_on(10)).is_false()
	assert_int(s.best_score(10)).is_equal(45)


func test_new_day_resets_attempts() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.record_attempt(10, false, 400, 500)
	s.record_attempt(10, false, 400, 500)
	assert_int(s.attempts_left(11)).is_equal(3)
	s.record_attempt(11, false, 100, 100)
	assert_int(s.attempts_left(11)).is_equal(2)
	assert_int(s.attempts_used(10)).is_equal(0)
	assert_int(s.best_score(11)).is_equal(10)
	var h: Array = s.history()
	assert_int(h.size()).is_equal(1)
	assert_int(int((h[0] as Dictionary)["day"])).is_equal(10)
	assert_int(int((h[0] as Dictionary)["attempts"])).is_equal(2)
	assert_int(int((h[0] as Dictionary)["best_pm"])).is_equal(400)


func test_clock_going_back_is_refused() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.record_attempt(10, false, 400, 500)
	var r: Dictionary = s.record_attempt(9, true, 900, 900)
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("past_day")
	assert_str(str(s.record_attempt(-1, true, 900, 900)["reason"])).is_equal("bad_day")
	assert_int(s.completed_days).is_equal(0)


func test_counters_count_days_not_attempts() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.record_attempt(1, false, 100, 100)
	s.record_attempt(1, false, 100, 100)
	assert_int(s.attempted_days).is_equal(1)
	assert_int(s.completed_days).is_equal(0)
	var done: Dictionary = s.record_attempt(1, true, 700, 800)
	assert_bool(bool(done["newly_completed"])).is_true()
	assert_int(s.completed_days).is_equal(1)
	assert_bool(s.completed_on(1)).is_true()
	var s2: MHDailyState = MHDailyState.new()
	s2.record_attempt(2, true, 700, 800)
	s2.attempts_per_day = 5
	var again: Dictionary = s2.record_attempt(2, true, 800, 800)
	assert_bool(bool(again["newly_completed"])).is_false()
	assert_int(s2.completed_days).is_equal(1)
	s2.record_attempt(3, false, 0, 0)
	assert_int(s2.attempted_days).is_equal(2)


func test_best_score_uses_fairness_to_break_ties() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.record_attempt(5, false, 600, 300)
	var r: Dictionary = s.record_attempt(5, false, 600, 700)
	assert_int(int(r["best_pm"])).is_equal(600)
	var b: Array = s.board()
	assert_int(int((b[0] as Dictionary)["fairness_pm"])).is_equal(700)
	assert_int(int((b[1] as Dictionary)["fairness_pm"])).is_equal(300)


func test_scores_are_clamped() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.record_attempt(5, false, 5000, -4)
	assert_int(int((s.board()[0] as Dictionary)["score_pm"])).is_equal(1000)
	assert_int(int((s.board()[0] as Dictionary)["fairness_pm"])).is_equal(0)


func test_board_is_sorted_and_capped() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.board_cap = 4
	s.attempts_per_day = 10
	var scores: Array = [500, 900, 100, 700, 300, 800]
	for v: Variant in scores:
		s.record_attempt(1, false, int(v), 500)
	var b: Array = s.board()
	assert_int(b.size()).is_equal(4)
	assert_int(int((b[0] as Dictionary)["score_pm"])).is_equal(900)
	assert_int(int((b[1] as Dictionary)["score_pm"])).is_equal(800)
	assert_int(int((b[2] as Dictionary)["score_pm"])).is_equal(700)
	assert_int(int((b[3] as Dictionary)["score_pm"])).is_equal(500)


func test_board_ties_prefer_the_earlier_day() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.record_attempt(8, false, 500, 500)
	s.record_attempt(9, false, 500, 500)
	var b: Array = s.board()
	assert_int(int((b[0] as Dictionary)["day"])).is_equal(8)
	assert_int(int((b[1] as Dictionary)["day"])).is_equal(9)


func test_history_is_capped() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.history_days = 5
	for day: int in range(0, 12):
		s.record_attempt(day, false, 100 + day, 500)
	var h: Array = s.history()
	assert_int(h.size()).is_equal(5)
	assert_int(int((h[0] as Dictionary)["day"])).is_equal(6)
	assert_int(int((h[4] as Dictionary)["day"])).is_equal(10)


func test_round_trip_and_json_round_trip() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.record_attempt(40, false, 420, 610)
	s.record_attempt(41, true, 750, 800)
	s.record_attempt(41, false, 300, 100)
	var d: Dictionary = s.to_dict()
	var s2: MHDailyState = MHDailyState.new()
	assert_bool(s2.from_dict(d)).is_true()
	assert_bool(s2.to_dict() == d).is_true()
	assert_int(s2.attempts_left(41)).is_equal(1)
	assert_int(s2.completed_days).is_equal(1)
	var parsed: Variant = JSON.parse_string(JSON.stringify(d))
	var s3: MHDailyState = MHDailyState.new()
	assert_bool(s3.from_dict(parsed as Dictionary)).is_true()
	assert_bool(s3.to_dict() == d).is_true()


func test_bad_data_is_rejected() -> void:
	var s: MHDailyState = MHDailyState.new()
	s.record_attempt(5, false, 100, 100)
	var good: Dictionary = s.to_dict()
	var t: MHDailyState = MHDailyState.new()
	var bad1: Dictionary = good.duplicate(true)
	bad1["v"] = 7
	assert_bool(t.from_dict(bad1)).is_false()
	var bad2: Dictionary = good.duplicate(true)
	bad2["best_pm"] = 5000
	assert_bool(t.from_dict(bad2)).is_false()
	var bad3: Dictionary = good.duplicate(true)
	bad3["board"] = [{"day": 1}]
	assert_bool(t.from_dict(bad3)).is_false()
	var bad4: Dictionary = good.duplicate(true)
	bad4["used"] = 1.5
	assert_bool(t.from_dict(bad4)).is_false()
	assert_int(t.current_day()).is_equal(-1)
	assert_bool(t.from_dict(good)).is_true()
	assert_int(t.current_day()).is_equal(5)
