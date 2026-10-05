extends GdUnitTestSuite
## MHFormat: pure formatting. NOT YET RUN.


func test_group_thousands() -> void:
	assert_str(MHFormat.group_thousands(0)).is_equal("0")
	assert_str(MHFormat.group_thousands(999)).is_equal("999")
	assert_str(MHFormat.group_thousands(1000)).is_equal("1,000")
	assert_str(MHFormat.group_thousands(1234567)).is_equal("1,234,567")
	assert_str(MHFormat.group_thousands(-1234)).is_equal("-1,234")


func test_money() -> void:
	assert_str(MHFormat.money(1234)).is_equal("$1,234")
	assert_str(MHFormat.money(0)).is_equal("$0")
	assert_str(MHFormat.money(-50)).is_equal("-$50")


func test_money_compact() -> void:
	assert_str(MHFormat.money_compact(9999)).is_equal("$9,999")
	assert_str(MHFormat.money_compact(12345)).is_equal("$12.3K")
	assert_str(MHFormat.money_compact(999999)).is_equal("$999.9K")
	assert_str(MHFormat.money_compact(1250000)).is_equal("$1.25M")
	assert_str(MHFormat.money_compact(-12345)).is_equal("-$12.3K")


func test_clock() -> void:
	assert_str(MHFormat.clock(570)).is_equal("9:30 AM")
	assert_str(MHFormat.clock(0)).is_equal("12:00 AM")
	assert_str(MHFormat.clock(720)).is_equal("12:00 PM")
	assert_str(MHFormat.clock(780)).is_equal("1:00 PM")
	assert_str(MHFormat.clock(570, true)).is_equal("09:30")
	assert_str(MHFormat.clock(1500)).is_equal("1:00 AM")


func test_game_clock_runs_seven_to_six() -> void:
	assert_str(MHFormat.game_clock(0)).is_equal("7:00 AM")
	assert_str(MHFormat.game_clock(215)).is_equal("10:35 AM")
	assert_str(MHFormat.game_clock(659)).is_equal("5:59 PM")
	assert_str(MHFormat.game_clock(9999)).is_equal("5:59 PM")
	assert_str(MHFormat.game_clock(-5)).is_equal("7:00 AM")


func test_day_helpers() -> void:
	assert_int(MHFormat.day_number(0)).is_equal(1)
	assert_int(MHFormat.day_number(11)).is_equal(12)
	assert_int(MHFormat.day_number(-3)).is_equal(1)
	assert_int(MHFormat.day_progress_percent(0)).is_equal(0)
	assert_int(MHFormat.day_progress_percent(330)).is_equal(50)
	assert_int(MHFormat.day_progress_percent(660)).is_equal(100)
	assert_int(MHFormat.day_progress_percent(9999)).is_equal(100)


func test_duration_minutes() -> void:
	assert_str(MHFormat.duration_minutes(75)).is_equal("1h 15m")
	assert_str(MHFormat.duration_minutes(65)).is_equal("1h 05m")
	assert_str(MHFormat.duration_minutes(45)).is_equal("45m")
	assert_str(MHFormat.duration_minutes(120)).is_equal("2h")
	assert_str(MHFormat.duration_minutes(0)).is_equal("0m")
	assert_str(MHFormat.duration_minutes(-5)).is_equal("0m")


func test_distance_and_height() -> void:
	assert_int(MHFormat.yards_to_metres(100)).is_equal(91)
	assert_int(MHFormat.yards_to_metres(0)).is_equal(0)
	assert_str(MHFormat.distance(372, true)).is_equal("340 m")
	assert_str(MHFormat.distance(372, false)).is_equal("372 yd")
	assert_str(MHFormat.height_mm(1200, true)).is_equal("1.2 m")
	assert_str(MHFormat.height_mm(1200, false)).is_equal("3.9 ft")
	assert_str(MHFormat.height_mm(-1200, true)).is_equal("-1.2 m")
	assert_str(MHFormat.height_mm(0, true)).is_equal("0.0 m")


func test_multiplier_and_percent() -> void:
	assert_str(MHFormat.multiplier_pm(1000)).is_equal("x1.00")
	assert_str(MHFormat.multiplier_pm(940)).is_equal("x0.94")
	assert_str(MHFormat.multiplier_pm(1250)).is_equal("x1.25")
	assert_str(MHFormat.multiplier_pm(-5)).is_equal("x0.00")
	assert_str(MHFormat.percent_pm(875)).is_equal("87%")
	assert_str(MHFormat.percent_pm(1500)).is_equal("100%")
	assert_str(MHFormat.percent_pm(-1)).is_equal("0%")
	assert_int(MHFormat.ratio_percent(1, 3)).is_equal(33)
	assert_int(MHFormat.ratio_percent(5, 0)).is_equal(0)
	assert_int(MHFormat.ratio_percent(7, 5)).is_equal(100)


func test_payback_days_rounds_up() -> void:
	assert_int(MHFormat.payback_days(7200, 900)).is_equal(8)
	assert_int(MHFormat.payback_days(7201, 900)).is_equal(9)
	assert_int(MHFormat.payback_days(100, 0)).is_equal(-1)
	assert_int(MHFormat.payback_days(0, 5)).is_equal(-1)


func test_score_formats() -> void:
	assert_int(MHFormat.score_from_pm(0)).is_equal(0)
	assert_int(MHFormat.score_from_pm(487)).is_equal(49)
	assert_int(MHFormat.score_from_pm(994)).is_equal(99)
	assert_int(MHFormat.score_from_pm(1000)).is_equal(100)
	assert_int(MHFormat.score_from_pm(1200)).is_equal(100)
	assert_int(MHFormat.score_from_pm(-3)).is_equal(0)
	assert_str(MHFormat.score_x10(487)).is_equal("48.7")
	assert_str(MHFormat.score_x10(0)).is_equal("0.0")
	assert_str(MHFormat.score_x10(1000)).is_equal("100.0")
	assert_str(MHFormat.score_x10(2000)).is_equal("100.0")
	assert_str(MHFormat.speed_label(2)).is_equal("2x")
	assert_str(MHFormat.speed_label(0)).is_equal("1x")
