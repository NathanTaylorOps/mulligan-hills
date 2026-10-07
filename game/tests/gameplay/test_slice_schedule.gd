extends GdUnitTestSuite
## MHSliceSchedule: golfer groups and tee times. Integer logic. NOT YET RUN in Godot.


func test_split_groups_is_even_and_covers_everyone() -> void:
	assert_int(MHSliceSchedule.split_groups(0, 3).size()).is_equal(0)
	assert_int(MHSliceSchedule.split_groups(-4, 3).size()).is_equal(0)
	assert_array(MHSliceSchedule.split_groups(1, 3)).contains_exactly([1])
	assert_array(MHSliceSchedule.split_groups(4, 3)).contains_exactly([2, 2])
	assert_array(MHSliceSchedule.split_groups(7, 3)).contains_exactly([3, 2, 2])
	assert_array(MHSliceSchedule.split_groups(9, 3)).contains_exactly([3, 3, 3])
	for n: int in range(1, 40):
		var total: int = 0
		for size: Variant in MHSliceSchedule.split_groups(n, 4):
			assert_int(int(size)).is_between(1, 4)
			total += int(size)
		assert_int(total).is_equal(n)


func test_add_hour_carries_the_remainder() -> void:
	var s: MHSliceSchedule = MHSliceSchedule.new()
	assert_int(s.add_hour(1500)).is_equal(1)
	assert_int(s.carry_milli).is_equal(500)
	assert_int(s.add_hour(1500)).is_equal(2)
	assert_int(s.carry_milli).is_equal(0)
	assert_int(s.add_hour(-5)).is_equal(0)
	assert_int(s.add_hour(999)).is_equal(0)
	assert_int(s.carry_milli).is_equal(999)
	assert_int(s.queue.size()).is_equal(2)
	assert_int(s.waiting_golfers()).is_equal(3)


func test_release_gives_one_group_per_tee_slot() -> void:
	var s: MHSliceSchedule = MHSliceSchedule.new()
	s.add_hour(9000) # 9 golfers, 3 groups of 3
	assert_int(s.queue.size()).is_equal(3)
	var first: Array = s.release(0)
	assert_int(first.size()).is_equal(1)
	assert_int(int((first[0] as Dictionary)["serial"])).is_equal(0)
	assert_int(int((first[0] as Dictionary)["tee_minute"])).is_equal(0)
	assert_int(s.release(11).size()).is_equal(0)
	var rest: Array = s.release(30)
	assert_int(rest.size()).is_equal(2)
	assert_int(int((rest[0] as Dictionary)["tee_minute"])).is_equal(12)
	assert_int(int((rest[1] as Dictionary)["tee_minute"])).is_equal(24)
	assert_int(s.queue.size()).is_equal(0)


func test_unused_tee_slots_are_skipped_not_banked() -> void:
	var s: MHSliceSchedule = MHSliceSchedule.new()
	assert_int(s.release(100).size()).is_equal(0)
	assert_int(s.next_tee_minute).is_equal(108)
	s.add_hour(3000)
	assert_int(s.release(100).size()).is_equal(0)
	var out: Array = s.release(108)
	assert_int(out.size()).is_equal(1)
	assert_int(int((out[0] as Dictionary)["tee_minute"])).is_equal(108)


func test_queue_is_capped() -> void:
	var s: MHSliceSchedule = MHSliceSchedule.new()
	s.add_hour(100000) # 100 golfers, 34 groups
	assert_int(s.queue.size()).is_equal(MHSliceSchedule.MAX_QUEUE)
	assert_int(s.dropped_groups).is_equal(34 - MHSliceSchedule.MAX_QUEUE)


func test_same_inputs_give_the_same_schedule() -> void:
	var a: MHSliceSchedule = MHSliceSchedule.new()
	var b: MHSliceSchedule = MHSliceSchedule.new()
	var log_a: Array = []
	var log_b: Array = []
	for hour: int in range(22):
		var milli: int = 700 + (hour * 811) % 3300
		a.add_hour(milli)
		b.add_hour(milli)
		for g: Variant in a.release(hour * 60):
			log_a.append([int((g as Dictionary)["serial"]), int((g as Dictionary)["size"]), int((g as Dictionary)["tee_minute"])])
		for g2: Variant in b.release(hour * 60):
			log_b.append([int((g2 as Dictionary)["serial"]), int((g2 as Dictionary)["size"]), int((g2 as Dictionary)["tee_minute"])])
	assert_int(log_a.size()).is_equal(log_b.size())
	for i: int in range(log_a.size()):
		assert_array(log_a[i] as Array).contains_exactly(log_b[i] as Array)


func test_from_economy_reads_group_size_and_interval() -> void:
	var session: MHGameSession = MHGameSession.create()
	assert_object(session).is_not_null()
	var sched: MHSliceSchedule = MHSliceSchedule.from_economy(session.economy)
	assert_int(sched.interval_min).is_equal(12)
	assert_int(sched.group_size).is_equal(3)


func test_expected_hour_matches_the_economy_tick() -> void:
	var e: MHEconomy = MHGameSession.create().economy
	e.set_course(4, 40, 5)
	e.carry_milli = 0
	for hour: int in range(MHEconomy.HOURS_PER_DAY):
		e.carry_milli = 0
		var expected: int = MHSliceSchedule.hour_golfers_expected_milli(e, e.hour)
		var tick: Dictionary = e.tick_hour()
		assert_int(int(tick["golfers"])).override_failure_message("hour %d" % hour).is_equal(expected / 1000)


func test_expected_hour_does_not_change_the_economy() -> void:
	var e: MHEconomy = MHGameSession.create().economy
	var before: Dictionary = e.to_dict()
	MHSliceSchedule.hour_golfers_expected_milli(e, 3)
	var after: Dictionary = e.to_dict()
	for k: Variant in before.keys():
		if k == "tiers":
			continue
		assert_int(int(after[k])).is_equal(int(before[k]))


func test_look_index_is_stable_and_in_range() -> void:
	for serial: int in range(30):
		for member: int in range(4):
			var a: int = MHSliceSchedule.look_index(serial, member, 12)
			assert_int(a).is_between(0, 11)
			assert_int(MHSliceSchedule.look_index(serial, member, 12)).is_equal(a)
	assert_int(MHSliceSchedule.look_index(5, 1, 0)).is_equal(0)

func test_booked_customer_ids_stay_attached_when_split_into_groups() -> void:
	var sched: MHSliceSchedule = MHSliceSchedule.new()
	var ids: Array = [11, 22, 33, 44, 55, 66, 77]
	assert_int(sched.add_booked_golfers(ids.size(), ids)).is_equal(7)
	assert_int(sched.queue.size()).is_equal(3)
	var rebuilt: Array = []
	for row_value: Variant in sched.queue:
		var row: Dictionary = row_value as Dictionary
		assert_int((row["customer_ids"] as Array).size()).is_equal(int(row["size"]))
		rebuilt.append_array(row["customer_ids"] as Array)
	assert_array(rebuilt).contains_exactly(ids)

func test_booked_queue_does_not_touch_legacy_fractional_carry() -> void:
	var sched: MHSliceSchedule = MHSliceSchedule.new()
	sched.carry_milli = 777
	sched.add_booked_golfers(4, [1, 2, 3, 4])
	assert_int(sched.carry_milli).is_equal(777)
	assert_int(sched.waiting_golfers()).is_equal(4)

func test_authoritative_bookings_are_lossless_even_past_visual_queue_cap() -> void:
	var sched: MHSliceSchedule = MHSliceSchedule.new()
	var ids: Array = []
	for i: int in range(80):
		ids.append(i % MHGolferCustomers.COUNT)
	sched.add_booked_golfers(ids.size(), ids)
	assert_int(sched.waiting_golfers()).is_equal(ids.size())
	assert_int(sched.dropped_groups).is_equal(0)

func test_authoritative_groups_carry_their_actual_tee_wait() -> void:
	var schedule: MHSliceSchedule = MHSliceSchedule.new()
	schedule.group_size = 3
	schedule.interval_min = 12
	schedule.add_booked_golfers(6, [1, 2, 3, 4, 5, 6], 0)
	var released: Array = schedule.release(12)
	assert_int(released.size()).is_equal(2)
	assert_int(int((released[0] as Dictionary)["tee_minute"])).is_equal(0)
	assert_int(int((released[0] as Dictionary)["wait_minutes"])).is_equal(0)
	assert_int(int((released[1] as Dictionary)["tee_minute"])).is_equal(12)
	assert_int(int((released[1] as Dictionary)["wait_minutes"])).is_equal(12)
	assert_array((released[1] as Dictionary)["customer_ids"] as Array).is_equal([4, 5, 6])
