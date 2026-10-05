extends GdUnitTestSuite
## MHGameClock golden sequences. Expected values come from an independent Python mirror of the algorithm
## (scratch script, not committed). NOT YET RUN in Godot.


func _run(c: MHGameClock, frames: int, delta_us: int, ledger: MHTokenLedger = null) -> PackedInt32Array:
	var all: PackedInt32Array = PackedInt32Array()
	for i in range(frames):
		all.append_array(c.step(delta_us, ledger))
	return all


func test_one_game_day_is_fifteen_real_minutes() -> void:
	var c: MHGameClock = MHGameClock.new()
	var ev: PackedInt32Array = _run(c, 900, 1000000)
	assert_int(c.total_minutes()).is_equal(660)
	assert_int(c.day()).is_equal(1)
	assert_int(c.minute_of_day()).is_equal(0)
	# 11 hour events + 1 day event = 12 rows of 3 ints
	assert_int(ev.size()).is_equal(36)
	# last two rows: hour 11 of day 0, then rollover into day 1
	assert_int(ev[30]).is_equal(MHGameClock.EV_HOUR)
	assert_int(ev[31]).is_equal(0)
	assert_int(ev[32]).is_equal(11)
	assert_int(ev[33]).is_equal(MHGameClock.EV_DAY)
	assert_int(ev[34]).is_equal(1)
	assert_int(ev[35]).is_equal(0)


func test_exact_accumulator_values() -> void:
	var c: MHGameClock = MHGameClock.new()
	var to_dict_before: Dictionary = c.to_dict()
	assert_int(int(to_dict_before["acc"])).is_equal(0)
	c.step(1000000)
	assert_int(c.total_minutes()).is_equal(0)
	assert_int(int(c.to_dict()["acc"])).is_equal(660000000)
	c.step(1000000)
	assert_int(c.total_minutes()).is_equal(1)
	assert_int(int(c.to_dict()["acc"])).is_equal(420000000)


func test_slicing_does_not_change_the_result() -> void:
	var a: MHGameClock = MHGameClock.new()
	var b: MHGameClock = MHGameClock.new()
	_run(a, 3600, 250000)
	_run(b, 900, 1000000)
	assert_int(a.total_minutes()).is_equal(660)
	assert_int(b.total_minutes()).is_equal(660)
	assert_bool(a.to_dict() == b.to_dict()).is_true()


func test_sixty_fps_for_one_real_hour() -> void:
	var c: MHGameClock = MHGameClock.new()
	_run(c, 216000, 16667)
	assert_int(c.total_minutes()).is_equal(2640)
	assert_int(int(c.to_dict()["acc"])).is_equal(47520000)


func test_hour_events_after_a_partial_day() -> void:
	var c: MHGameClock = MHGameClock.new()
	var ev: PackedInt32Array = _run(c, 240, 1000000)
	# 240 s at 1x = 176 game minutes = 2 full hours (hour 3 ends at minute 180)
	assert_int(c.total_minutes()).is_equal(176)
	assert_int(ev.size()).is_equal(6)
	assert_int(ev[2]).is_equal(1)
	assert_int(ev[5]).is_equal(2)


func test_pause_freezes_everything() -> void:
	var c: MHGameClock = MHGameClock.new()
	c.pause()
	assert_bool(c.is_paused()).is_true()
	var ev: PackedInt32Array = _run(c, 100, 1000000)
	assert_int(ev.size()).is_equal(0)
	assert_int(c.total_minutes()).is_equal(0)
	assert_int(int(c.to_dict()["acc"])).is_equal(0)
	c.resume()
	c.step(2000000)
	assert_int(int(c.to_dict()["acc"])).is_equal(1320000000 % 900000000)
	assert_int(c.total_minutes()).is_equal(1)


func test_request_speed_rules() -> void:
	var c: MHGameClock = MHGameClock.new()
	assert_int(c.request_speed(3, 100)).is_equal(MHGameClock.SPEED_DENIED_INVALID)
	assert_int(c.request_speed(0, 100)).is_equal(MHGameClock.SPEED_DENIED_INVALID)
	assert_int(c.request_speed(2, 0)).is_equal(MHGameClock.SPEED_DENIED_TOKENS)
	assert_int(c.speed()).is_equal(1)
	assert_int(c.request_speed(4, 1)).is_equal(MHGameClock.SPEED_OK)
	assert_int(c.speed()).is_equal(4)
	assert_int(c.request_speed(1, 0)).is_equal(MHGameClock.SPEED_OK)
	assert_int(c.speed()).is_equal(1)


func test_speed_two_drains_one_token_per_minute_then_drops() -> void:
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 1
	assert_int(c.request_speed(2, l.total())).is_equal(MHGameClock.SPEED_OK)
	var ev: PackedInt32Array = _run(c, 61, 1000000, l)
	# 60 s at 2x plus 1 s at 1x = 121 effective seconds = 88 game minutes, acc 660000000
	assert_int(c.total_minutes()).is_equal(88)
	assert_int(int(c.to_dict()["acc"])).is_equal(660000000)
	assert_int(c.speed()).is_equal(1)
	assert_int(l.total()).is_equal(0)
	# one hour event (hour 1), then the speed drop row: [3, day 0, old speed 2]
	var expect: Array = [1, 0, 1, 3, 0, 2]
	assert_int(ev.size()).is_equal(expect.size())
	for i in range(expect.size()):
		assert_int(ev[i]).is_equal(int(expect[i]))


func test_speed_eight_with_earned_then_paid_tokens() -> void:
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 2
	l.paid = 1
	c.request_speed(8, l.total())
	var ev: PackedInt32Array = _run(c, 50, 1000000, l)
	# 3 tokens = 45 s of 8x, then 5 s at 1x: 365 effective seconds
	assert_int(c.total_minutes()).is_equal(267)
	assert_int(int(c.to_dict()["acc"])).is_equal(600000000)
	assert_int(c.speed()).is_equal(1)
	assert_int(l.earned).is_equal(0)
	assert_int(l.paid).is_equal(0)
	var expect: Array = [1, 0, 1, 1, 0, 2, 1, 0, 3, 1, 0, 4, 3, 0, 8]
	assert_int(ev.size()).is_equal(expect.size())
	for i in range(expect.size()):
		assert_int(ev[i]).is_equal(int(expect[i]))


func test_speed_without_ledger_drops_to_one() -> void:
	var c: MHGameClock = MHGameClock.new()
	c.request_speed(8, 5)
	var ev: PackedInt32Array = c.step(1000000, null)
	assert_int(c.speed()).is_equal(1)
	assert_int(int(c.to_dict()["acc"])).is_equal(660000000)
	assert_int(ev.size()).is_equal(3)
	assert_int(ev[0]).is_equal(MHGameClock.EV_SPEED_DROPPED)
	assert_int(ev[2]).is_equal(8)


func test_catch_up_is_capped_and_free() -> void:
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 10
	c.request_speed(8, l.total())
	c.step(10000000, l)
	# 10 s spike: treated as suspension, 1x, no tokens spent, speed unchanged
	assert_int(c.total_minutes()).is_equal(7)
	assert_int(int(c.to_dict()["acc"])).is_equal(300000000)
	assert_int(l.earned).is_equal(10)
	assert_int(c.speed()).is_equal(8)
	assert_bool(c.last_was_catchup).is_true()
	assert_int(c.last_discarded_us).is_equal(0)


func test_offline_progress_is_bounded() -> void:
	var c: MHGameClock = MHGameClock.new()
	var ev: PackedInt32Array = c.step(500000000)
	assert_int(c.total_minutes()).is_equal(88)
	assert_int(c.last_discarded_us).is_equal(380000000)
	assert_int(ev.size()).is_equal(3)
	# a week away still gives the same 88 minutes
	var c2: MHGameClock = MHGameClock.new()
	c2.step(604800000000)
	assert_int(c2.total_minutes()).is_equal(88)


func test_set_time_and_getters() -> void:
	var c: MHGameClock = MHGameClock.new()
	c.set_time(5, 125)
	assert_int(c.day()).is_equal(5)
	assert_int(c.minute_of_day()).is_equal(125)
	assert_int(c.hour_of_day()).is_equal(2)
	assert_int(c.total_minutes()).is_equal(5 * 660 + 125)
	# crossing into day 6 from the last minute: 1.5 s of 1x is 1.1 game minutes
	c.set_time(5, 659)
	var ev: PackedInt32Array = c.step(1500000)
	assert_int(c.day()).is_equal(6)
	assert_int(c.minute_of_day()).is_equal(0)
	assert_int(ev.size()).is_equal(6)
	assert_int(ev[0]).is_equal(MHGameClock.EV_HOUR)
	assert_int(ev[1]).is_equal(5)
	assert_int(ev[2]).is_equal(11)
	assert_int(ev[3]).is_equal(MHGameClock.EV_DAY)
	assert_int(ev[4]).is_equal(6)
	assert_int(ev[5]).is_equal(0)
	ev = c.step(1500000)
	assert_int(ev.size()).is_equal(0)
	assert_int(c.minute_of_day()).is_equal(1)


func test_save_round_trip_through_json() -> void:
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 5
	c.request_speed(4, l.total())
	_run(c, 7, 1000000, l)
	var text: String = JSON.stringify(c.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(typeof(parsed) == TYPE_DICTIONARY).is_true()
	var c2: MHGameClock = MHGameClock.new()
	assert_bool(c2.from_dict(parsed as Dictionary)).is_true()
	assert_bool(c2.to_dict() == c.to_dict()).is_true()
	# both continue identically
	var l2: MHTokenLedger = MHTokenLedger.new()
	l2.from_dict(l.to_dict())
	var e1: PackedInt32Array = _run(c, 20, 500000, l)
	var e2: PackedInt32Array = _run(c2, 20, 500000, l2)
	assert_bool(e1 == e2).is_true()
	assert_bool(c.to_dict() == c2.to_dict()).is_true()


func test_from_dict_rejects_bad_data() -> void:
	var c: MHGameClock = MHGameClock.new()
	assert_bool(c.from_dict({})).is_false()
	assert_bool(c.from_dict({"total_minutes": -1})).is_false()
	assert_bool(c.from_dict({"total_minutes": 5, "speed": 3})).is_false()
	assert_bool(c.from_dict({"total_minutes": 5, "acc": 900000000})).is_false()
	assert_int(c.total_minutes()).is_equal(0)


func _expect(ev: PackedInt32Array, expect: Array) -> void:
	assert_int(ev.size()).is_equal(expect.size())
	for i in range(expect.size()):
		assert_int(ev[i]).is_equal(int(expect[i]))


func test_speed_four_mixed_earned_and_paid_golden() -> void:
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 1
	l.paid = 2
	c.request_speed(4, l.total())
	var ev: PackedInt32Array = _run(c, 100, 1000000, l)
	# 3 tokens = 90 s of 4x, then 10 s at 1x: 370 effective seconds = 271 game minutes
	assert_int(c.total_minutes()).is_equal(271)
	assert_int(int(c.to_dict()["acc"])).is_equal(300000000)
	assert_int(c.speed()).is_equal(1)
	assert_int(c.prepaid_credit()).is_equal(0)
	assert_int(l.total()).is_equal(0)
	_expect(ev, [1, 0, 1, 1, 0, 2, 1, 0, 3, 1, 0, 4, 3, 0, 4])


func test_speed_two_with_sixty_fps_frames_golden() -> void:
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 2
	c.request_speed(2, l.total())
	var ev: PackedInt32Array = _run(c, 8000, 16667, l)
	assert_int(c.total_minutes()).is_equal(185)
	assert_int(int(c.to_dict()["acc"])).is_equal(701760000)
	assert_int(c.speed()).is_equal(1)
	assert_int(l.total()).is_equal(0)
	_expect(ev, [1, 0, 1, 1, 0, 2, 3, 0, 2, 1, 0, 3])


func test_speed_eight_is_independent_of_frame_slicing() -> void:
	var a: MHGameClock = MHGameClock.new()
	var la: MHTokenLedger = MHTokenLedger.new()
	la.earned = 5
	a.request_speed(8, la.total())
	var ea: PackedInt32Array = _run(a, 1200, 50000, la)
	var b: MHGameClock = MHGameClock.new()
	var lb: MHTokenLedger = MHTokenLedger.new()
	lb.earned = 5
	b.request_speed(8, lb.total())
	var eb: PackedInt32Array = _run(b, 60, 1000000, lb)
	assert_int(a.total_minutes()).is_equal(352)
	assert_bool(a.to_dict() == b.to_dict()).is_true()
	assert_bool(ea == eb).is_true()
	assert_int(la.total()).is_equal(1)
	assert_int(lb.total()).is_equal(1)
	assert_int(a.speed()).is_equal(8)


func test_one_x_never_touches_the_ledger() -> void:
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 4
	l.paid = 4
	_run(c, 900, 1000000, l)
	assert_int(l.earned).is_equal(4)
	assert_int(l.paid).is_equal(4)
	assert_int(c.prepaid_credit()).is_equal(0)


func test_paused_clock_does_not_drain_tokens() -> void:
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 3
	c.request_speed(8, l.total())
	c.pause()
	_run(c, 100, 1000000, l)
	assert_int(l.earned).is_equal(3)
	assert_int(c.total_minutes()).is_equal(0)


func test_hour_boundary_events_never_skip_when_fast() -> void:
	# one frame of 1 s at 8x is 5.87 game minutes; walk a whole day and count hour events
	var c: MHGameClock = MHGameClock.new()
	var l: MHTokenLedger = MHTokenLedger.new()
	l.earned = 40
	c.request_speed(8, l.total())
	var hours: int = 0
	var days: int = 0
	for i in range(120):
		var ev: PackedInt32Array = c.step(1000000, l)
		for r in range(ev.size() / MHGameClock.EVENT_STRIDE):
			if ev[r * 3] == MHGameClock.EV_HOUR:
				hours += 1
			elif ev[r * 3] == MHGameClock.EV_DAY:
				days += 1
	# 120 s at 8x = 960 s at 1x = 704 game minutes = 1 day and 44 minutes
	assert_int(c.total_minutes()).is_equal(704)
	assert_int(hours).is_equal(11)
	assert_int(days).is_equal(1)
