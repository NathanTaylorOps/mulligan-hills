extends GdUnitTestSuite
## MHSpeedControl (token-locked speeds), MHRecoveryModel (bankruptcy), MHScoreModel. NOT YET RUN.


func test_one_x_is_always_free() -> void:
	assert_bool(MHSpeedControl.is_locked(1, 0)).is_false()
	assert_bool(MHSpeedControl.can_select(1, 0)).is_true()
	assert_int(MHSpeedControl.minutes_left(0, 1)).is_equal(-1)
	assert_int(MHSpeedControl.tokens_per_minute(1)).is_equal(0)


func test_boosted_speeds_need_a_token() -> void:
	for s: int in [2, 4, 8]:
		assert_bool(MHSpeedControl.is_locked(s, 0)).is_true()
		assert_bool(MHSpeedControl.can_select(s, 0)).is_false()
		assert_bool(MHSpeedControl.can_select(s, 1)).is_true()
	assert_bool(MHSpeedControl.can_select(3, 99)).is_false()
	assert_bool(MHSpeedControl.can_select(0, 99)).is_false()


func test_rates_and_minutes_left() -> void:
	assert_int(MHSpeedControl.tokens_per_minute(2)).is_equal(1)
	assert_int(MHSpeedControl.tokens_per_minute(4)).is_equal(2)
	assert_int(MHSpeedControl.tokens_per_minute(8)).is_equal(4)
	assert_int(MHSpeedControl.minutes_left(5, 2)).is_equal(5)
	assert_int(MHSpeedControl.minutes_left(5, 4)).is_equal(2)
	assert_int(MHSpeedControl.minutes_left(5, 8)).is_equal(1)
	assert_int(MHSpeedControl.minutes_left(-3, 2)).is_equal(0)


func test_effective_speed_falls_back() -> void:
	assert_int(MHSpeedControl.effective_speed(4, 0)).is_equal(1)
	assert_int(MHSpeedControl.effective_speed(4, 3)).is_equal(4)
	assert_int(MHSpeedControl.effective_speed(7, 3)).is_equal(1)


func test_options_rows() -> void:
	var o: Array = MHSpeedControl.options(0, 4)
	assert_int(o.size()).is_equal(4)
	assert_bool(bool((o[0] as Dictionary)["selected"])).is_true()
	assert_bool(bool((o[1] as Dictionary)["locked"])).is_true()
	assert_bool(bool((o[2] as Dictionary)["selected"])).is_false()
	var o2: Array = MHSpeedControl.options(5, 4)
	assert_bool(bool((o2[2] as Dictionary)["selected"])).is_true()
	assert_bool(bool((o2[2] as Dictionary)["locked"])).is_false()
	assert_int(int((o2[3] as Dictionary)["tokens_per_min"])).is_equal(4)


func test_speed_list_matches_the_clock() -> void:
	for s: Variant in MHSpeedControl.SPEEDS:
		assert_bool(MHGameClock.is_valid_speed(int(s))).is_true()


func test_recovery_options() -> void:
	var offer: Dictionary = {"active": true, "shortfall": 1260, "loan_amount": 5000, "reputation_penalty": 15, "token_cost": 5}
	assert_bool(MHRecoveryModel.is_active(offer)).is_true()
	var o: Array = MHRecoveryModel.options(offer, 3)
	assert_int(o.size()).is_equal(3)
	assert_str(str((o[0] as Dictionary)["id"])).is_equal(MHRecoveryModel.OPT_LOAN)
	assert_str(str((o[1] as Dictionary)["id"])).is_equal(MHRecoveryModel.OPT_TOKENS)
	assert_str(str((o[2] as Dictionary)["id"])).is_equal(MHRecoveryModel.OPT_LATER)
	assert_bool(bool((o[0] as Dictionary)["enabled"])).is_true()
	assert_bool(bool((o[1] as Dictionary)["enabled"])).is_false()
	assert_bool(bool((o[2] as Dictionary)["enabled"])).is_true()
	assert_int(MHRecoveryModel.tokens_short(offer, 3)).is_equal(2)
	var o2: Array = MHRecoveryModel.options(offer, 5)
	assert_bool(bool((o2[1] as Dictionary)["enabled"])).is_true()
	assert_int(MHRecoveryModel.tokens_short(offer, 5)).is_equal(0)


func test_recovery_without_offer_numbers() -> void:
	var o: Array = MHRecoveryModel.options({}, 99)
	assert_bool(bool((o[0] as Dictionary)["enabled"])).is_false()
	assert_bool(bool((o[1] as Dictionary)["enabled"])).is_false()
	assert_bool(bool((o[2] as Dictionary)["enabled"])).is_true()
	assert_bool(MHRecoveryModel.is_active({})).is_false()


func test_band_keys() -> void:
	assert_str(MHScoreModel.band_key(0)).is_equal("score.band.poor")
	assert_str(MHScoreModel.band_key(249)).is_equal("score.band.poor")
	assert_str(MHScoreModel.band_key(250)).is_equal("score.band.fair")
	assert_str(MHScoreModel.band_key(399)).is_equal("score.band.fair")
	assert_str(MHScoreModel.band_key(400)).is_equal("score.band.good")
	assert_str(MHScoreModel.band_key(549)).is_equal("score.band.good")
	assert_str(MHScoreModel.band_key(550)).is_equal("score.band.great")
	assert_str(MHScoreModel.band_key(699)).is_equal("score.band.great")
	assert_str(MHScoreModel.band_key(700)).is_equal("score.band.superb")
	assert_str(MHScoreModel.band_key(5000)).is_equal("score.band.superb")


func test_weakest_and_dead() -> void:
	var w: Dictionary = MHScoreModel.weakest([58, 47, 22, 22])
	assert_int(int(w["hole_no"])).is_equal(3)
	assert_int(int(w["score"])).is_equal(22)
	assert_bool(MHScoreModel.weakest([]).is_empty()).is_true()
	assert_int(MHScoreModel.count_dead([58, 24, 25, 0], 25)).is_equal(2)


func test_next_gate() -> void:
	var defs: MHBuildingDefs = MHBuildingDefs.load_default()
	var g: Dictionary = MHScoreModel.next_gate(defs, 46)
	assert_int(int(g["tier"])).is_equal(4)
	assert_int(int(g["need"])).is_equal(52)
	var low: Dictionary = MHScoreModel.next_gate(defs, 10)
	assert_int(int(low["tier"])).is_equal(2)
	assert_int(int(low["need"])).is_equal(32)
	assert_bool(MHScoreModel.next_gate(defs, 70).is_empty()).is_true()
	assert_bool(MHScoreModel.next_gate(null, 10).is_empty()).is_true()
