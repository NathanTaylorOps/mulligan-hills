extends GdUnitTestSuite
## MHStaffGrounds: cell to parcel mapping, personal work, daily decay and pests, incidents. NOT YET RUN in Godot.

const RICH: int = 1000000000

var _defs: MHStaffDefs
var _staff: MHStaff
var _view: Dictionary


func before_test() -> void:
	_defs = MHStaffFixture.defs()
	_staff = MHStaff.create(_defs)
	_view = MHStaffFixture.view({}, MHStaffFixture.start_owned())


func test_parcel_of_cell_golden() -> void:
	var g: Dictionary = MHStaffFixture.golden()
	for row: Variant in (g["parcel_of_cell"] as Array):
		var r: Array = row
		assert_int(MHStaffGrounds.parcel_of_cell(int(r[0]), int(r[1]), int(r[2]), int(r[3]), 4, 4)).is_equal(int(r[4]))


func test_128_patch_gives_every_parcel_1024_cells() -> void:
	var counts: Array = []
	for _i: int in range(16):
		counts.append(0)
	for cy: int in range(128):
		for cx: int in range(128):
			var p: int = MHStaffGrounds.parcel_of_cell(cx, cy, 128, 128, 4, 4)
			counts[p] = int(counts[p]) + 1
	for c: Variant in counts:
		assert_int(int(c)).is_equal(1024)
	assert_int(MHStaffGrounds.parcel_of_cell(5, 5, 0, 128, 4, 4)).is_equal(-1)


func test_fresh_state_uses_the_start_values() -> void:
	for p: int in range(16):
		assert_int(_staff.condition_of(p)).is_equal(700)
		assert_int(_staff.pest_of(p)).is_equal(100)
	assert_int(_staff.condition_of(-1)).is_equal(0)
	assert_int(_staff.condition_of(16)).is_equal(0)


func test_personal_mow_caps_and_resets() -> void:
	_staff.grounds.condition[5] = 100
	assert_int(_staff.personal_mow(5, 100, 1024, _view)).is_equal(29)
	assert_int(_staff.personal_mow(5, 1024, 1024, _view)).is_equal(300)
	assert_int(_staff.personal_mow(5, 1024, 1024, _view)).is_equal(271)
	assert_int(_staff.personal_mow(5, 1024, 1024, _view)).is_equal(0)
	assert_int(_staff.condition_of(5)).is_equal(700)
	_staff.on_day(1, _view, 5)
	assert_int(_staff.personal_mow(5, 1024, 1024, _view)).is_greater(0)


func test_personal_mow_ignores_bad_input() -> void:
	assert_int(_staff.personal_mow(4, 1024, 1024, _view)).is_equal(0)
	assert_int(_staff.personal_mow(-1, 1024, 1024, _view)).is_equal(0)
	assert_int(_staff.personal_mow(16, 1024, 1024, _view)).is_equal(0)
	assert_int(_staff.personal_mow(5, 0, 1024, _view)).is_equal(0)
	assert_int(_staff.personal_mow(5, -10, 1024, _view)).is_equal(0)
	assert_int(_staff.personal_mow(5, 100, 0, _view)).is_equal(0)
	_staff.grounds.condition[5] = 1000
	assert_int(_staff.personal_mow(5, 1024, 1024, _view)).is_equal(0)


func test_personal_patrol() -> void:
	_staff.grounds.pest[6] = 300
	assert_int(_staff.personal_patrol(6, 1024, 1024, _view)).is_equal(200)
	assert_int(_staff.personal_patrol(6, 1024, 1024, _view)).is_equal(100)
	assert_int(_staff.personal_patrol(6, 1024, 1024, _view)).is_equal(0)
	assert_int(_staff.pest_of(6)).is_equal(0)
	assert_int(_staff.personal_patrol(4, 1024, 1024, _view)).is_equal(0)


func test_untended_course_sinks_to_the_hard_floor_and_pests_to_their_cap() -> void:
	for day: int in range(1, 31):
		_staff.on_day(day, _view, 1)
		if day == 1:
			assert_int(_staff.condition_of(5)).is_equal(635)
			assert_int(_staff.condition_of(8)).is_equal(665)
			assert_int(_staff.pest_of(5)).is_equal(135)
	for p: int in [5, 6, 8, 9, 10]:
		assert_int(_staff.condition_of(p)).is_equal(250)
		assert_int(_staff.pest_of(p)).is_equal(500)
	# parcels the club does not own are never touched
	assert_int(_staff.condition_of(0)).is_equal(700)
	assert_int(_staff.pest_of(0)).is_equal(100)
	assert_int(_staff.demand_permille(_view)).is_equal(945)


func test_keepers_hold_condition_and_rangers_hold_pests() -> void:
	var v: Dictionary = MHStaffFixture.view({"maintenance": 3}, MHStaffFixture.start_owned())
	_staff.hire("groundskeeper", 0, v, RICH)
	_staff.hire("groundskeeper", 0, v, RICH)
	_staff.assign(1, [5, 6, 9], v)
	_staff.assign(2, [10, 8], v)
	for day: int in range(1, 11):
		_staff.on_day(day, v, 1)
	assert_int(_staff.condition_of(5)).is_equal(793)
	assert_int(_staff.condition_of(8)).is_equal(987)
	assert_int(_staff.condition_of(10)).is_equal(987)
	assert_int(_staff.condition_of(0)).is_equal(700)
	# a ranger on the same parcels drives the pest pressure to zero
	var ranger: Dictionary = _staff.hire("wildlife_ranger", 10, v, RICH)
	assert_bool(bool(ranger["ok"])).is_true()
	_staff.assign(int(ranger["serial"]), [5, 6, 9], v)
	for day2: int in range(11, 31):
		_staff.on_day(day2, v, 1)
	assert_int(_staff.pest_of(5)).is_equal(0)
	assert_int(_staff.pest_of(10)).is_equal(500)
	assert_int(_staff.condition_of(5)).is_equal(1000)


func test_staff_on_unowned_areas_do_nothing() -> void:
	var v: Dictionary = MHStaffFixture.view({"maintenance": 3}, MHStaffFixture.start_owned())
	var wide: Dictionary = MHStaffFixture.view({"maintenance": 3}, [1, 5, 6, 8, 9, 10])
	_staff.hire("groundskeeper", 0, wide, RICH)
	assert_str(_staff.assign(1, [1, 5], wide)).is_equal("")
	_staff.on_day(1, v, 1)
	# parcel 1 is not owned in v: parcel 5 gets the keeper's whole 240 points, parcel 1 stays untouched
	assert_int(_staff.condition_of(1)).is_equal(700)
	assert_int(_staff.condition_of(5)).is_equal(875)


func test_on_day_is_idempotent_and_ordered() -> void:
	var first: Dictionary = _staff.on_day(5, _view, 9)
	assert_bool(bool(first["ran"])).is_true()
	var snapshot: PackedInt64Array = _staff.state_list()
	var again: Dictionary = _staff.on_day(5, _view, 9)
	assert_bool(bool(again["ran"])).is_false()
	assert_bool((again["incidents"] as Array).is_empty()).is_true()
	assert_bool(MHStaffFixture.same_list(snapshot, _staff.state_list())).is_true()
	var older: Dictionary = _staff.on_day(3, _view, 9)
	assert_bool(bool(older["ran"])).is_false()
	assert_int(_staff.grounds.last_day).is_equal(5)


func test_incidents_are_bounded_and_deterministic() -> void:
	# a huge neglected course: at most incident_max_per_day negative incidents a day, same result on replay
	var v: Dictionary = MHStaffFixture.view({}, range(16))
	var a: MHStaff = MHStaffFixture.staff()
	var b: MHStaff = MHStaffFixture.staff()
	var total_a: int = 0
	for day: int in range(1, 121):
		var ra: Dictionary = a.on_day(day, v, 31337)
		var rb: Dictionary = b.on_day(day, v, 31337)
		assert_int((ra["incidents"] as Array).size()).is_equal((rb["incidents"] as Array).size())
		var negatives: int = 0
		for i: Variant in (ra["incidents"] as Array):
			var inc: Dictionary = i
			if not bool(inc["positive"]):
				negatives += 1
				assert_bool(bool(inc["handled"])).is_false()
			assert_int(int(inc["parcel"])).is_between(0, 15)
		assert_int(negatives).is_less_equal(3)
		total_a += negatives
	assert_int(total_a).is_greater(0)
	assert_bool(MHStaffFixture.same_list(a.state_list(), b.state_list())).is_true()
	assert_int(a.grounds.incidents_hit).is_equal(total_a)
	for p: int in range(16):
		assert_int(a.condition_of(p)).is_between(0, 1000)
		assert_int(a.pest_of(p)).is_between(0, 1000)


func test_secret_changes_the_incident_rolls() -> void:
	var v: Dictionary = MHStaffFixture.view({}, range(16))
	var a: MHStaff = MHStaffFixture.staff()
	var b: MHStaff = MHStaffFixture.staff()
	var differs: bool = false
	for day: int in range(1, 100):
		a.on_day(day, v, 1)
		b.on_day(day, v, 2)
		if not MHStaffFixture.same_list(a.state_list(), b.state_list()):
			differs = true
	assert_bool(differs).is_true()


func test_h32_matches_the_python_vectors() -> void:
	var g: Dictionary = MHStaffFixture.golden()
	for row: Variant in (g["h32"] as Array):
		var r: Array = row
		assert_int(MHRMath.h32d(int(r[0]), int(r[1]), int(r[2]), MHStaffGrounds.INCIDENT_SALT)).is_equal(int(r[3]))
