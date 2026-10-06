extends GdUnitTestSuite
## MHStaffRoster / MHStaff: hiring rules, firing, area assignment, wages, gate head count. NOT YET RUN in Godot.

const RICH: int = 1000000000

var _defs: MHStaffDefs
var _staff: MHStaff


func before_test() -> void:
	_defs = MHStaffFixture.defs()
	_staff = MHStaff.create(_defs)


func _view(maint: int, clubhouse: int = 1) -> Dictionary:
	return MHStaffFixture.view({"maintenance": maint, "clubhouse": clubhouse}, MHStaffFixture.start_owned())


func test_create_needs_loaded_defs() -> void:
	assert_object(_staff).is_not_null()
	assert_object(MHStaff.create(null)).is_null()
	assert_object(MHStaff.create(MHStaffDefs.new())).is_null()
	assert_int(_staff.head_count()).is_equal(0)
	assert_int(_staff.daily_payroll_cents()).is_equal(0)


func test_hire_refusals_in_order() -> void:
	var v: Dictionary = _view(1)
	assert_str(_staff.check_hire("astronaut", v, RICH)).is_equal("bad_role")
	assert_str(_staff.check_hire("caddie", v, RICH)).is_equal("no_building")
	assert_str(_staff.check_hire("wildlife_ranger", v, RICH)).is_equal("role_cap")
	assert_str(_staff.check_hire("groundskeeper", v, 100)).is_equal("cash")
	assert_str(_staff.check_hire("groundskeeper", v, RICH)).is_equal("")
	var r: Dictionary = _staff.hire("caddie", 0, v, RICH)
	assert_bool(bool(r["ok"])).is_false()
	assert_str(str(r["reason"])).is_equal("no_building")
	assert_int(int(r["cost"])).is_equal(0)
	assert_int(_staff.head_count()).is_equal(0)


func test_cash_needs_cost_plus_reserve() -> void:
	var v: Dictionary = _view(1)
	# first groundskeeper: cost 5 x 2200 = 11000, reserve 3 days x payroll after hire (2200) = 6600
	assert_str(_staff.check_hire("groundskeeper", v, 17599)).is_equal("cash")
	assert_str(_staff.check_hire("groundskeeper", v, 17600)).is_equal("")


func test_hire_returns_cost_and_serials_rise() -> void:
	var v: Dictionary = _view(1)
	var a: Dictionary = _staff.hire("groundskeeper", 4, v, RICH)
	var b: Dictionary = _staff.hire("groundskeeper", 5, v, RICH)
	assert_bool(bool(a["ok"])).is_true()
	assert_int(int(a["serial"])).is_equal(1)
	assert_int(int(b["serial"])).is_equal(2)
	assert_int(int(a["cost"])).is_equal(11000)
	var e: Dictionary = _staff.roster.employee(2)
	assert_int(int(e["hired_day"])).is_equal(5)
	assert_int(int(e["tenure"])).is_equal(0)
	assert_bool((e["areas"] as Array).is_empty()).is_true()
	assert_int(_staff.head_count()).is_equal(2)
	# cap at maintenance tier 1 is 2
	assert_str(_staff.check_hire("groundskeeper", v, RICH)).is_equal("role_cap")
	assert_str(_staff.check_hire("groundskeeper", _view(2), RICH)).is_equal("")


func test_roster_full_uses_the_data_limit() -> void:
	var data: Dictionary = MHStaffFixture.data_dict()
	(data["params"] as Dictionary)["max_employees"] = 2
	var small: MHStaffDefs = MHStaffDefs.new()
	assert_bool(small.load_from_dict(data)).is_true()
	var st: MHStaff = MHStaff.create(small)
	var v: Dictionary = _view(3, 3)
	assert_bool(bool(st.hire("groundskeeper", 0, v, RICH)["ok"])).is_true()
	assert_bool(bool(st.hire("marshal", 0, v, RICH)["ok"])).is_true()
	assert_str(st.check_hire("groundskeeper", v, RICH)).is_equal("roster_full")


func test_fire() -> void:
	var v: Dictionary = _view(1)
	_staff.hire("groundskeeper", 0, v, RICH)
	assert_bool(_staff.fire(9)).is_false()
	assert_bool(_staff.fire(1)).is_true()
	assert_bool(_staff.fire(1)).is_false()
	assert_int(_staff.head_count()).is_equal(0)
	assert_int(_staff.roster.fires).is_equal(1)
	# a serial is never reused
	var again: Dictionary = _staff.hire("groundskeeper", 0, v, RICH)
	assert_int(int(again["serial"])).is_equal(2)


func test_assign_rules_and_no_change_on_error() -> void:
	var v: Dictionary = _view(2, 2)
	_staff.hire("groundskeeper", 0, v, RICH)
	_staff.hire("marshal", 0, v, RICH)
	assert_str(_staff.assign(2, [5], v)).is_equal("not_area_role")
	assert_str(_staff.assign(7, [5], v)).is_equal("no_employee")
	assert_str(_staff.assign(1, [5, 6, 99], v)).is_equal("bad_area")
	assert_str(_staff.assign(1, [5, 5], v)).is_equal("duplicate_area")
	assert_str(_staff.assign(1, [4], v)).is_equal("not_owned")
	assert_str(_staff.assign(1, [5, 6, 8, 9, 10, 0, 1], v)).is_equal("too_many_areas")
	assert_bool((_staff.roster.employee(1)["areas"] as Array).is_empty()).is_true()
	assert_str(_staff.assign(1, [10, 5, 9], v)).is_equal("")
	assert_array(_staff.roster.employee(1)["areas"] as Array).is_equal([5, 9, 10])
	assert_str(_staff.assign(1, [], v)).is_equal("")
	assert_bool((_staff.roster.employee(1)["areas"] as Array).is_empty()).is_true()


func test_auto_assign_spreads_and_is_deterministic() -> void:
	var v: Dictionary = _view(3)
	for _i: int in range(3):
		_staff.hire("groundskeeper", 0, v, RICH)
	_staff.hire("wildlife_ranger", 0, v, RICH)
	assert_int(_staff.auto_assign(v)).is_equal(4)
	assert_int(_staff.auto_assign(v)).is_equal(0)
	# 5 owned parcels, span 4, 3 keepers: golf parcels 5, 6, 9, 10 come first, the facility parcel 8 last
	assert_array(_staff.roster.employee(1)["areas"] as Array).is_equal([5, 6, 9, 10])
	assert_array(_staff.roster.employee(2)["areas"] as Array).is_equal([5, 6, 8, 9])
	assert_array(_staff.roster.employee(3)["areas"] as Array).is_equal([5, 6, 8, 10])
	assert_array(_staff.roster.employee(4)["areas"] as Array).is_equal([5, 6, 9, 10])
	var other: MHStaff = MHStaffFixture.staff()
	for _j: int in range(3):
		other.hire("groundskeeper", 0, v, RICH)
	other.hire("wildlife_ranger", 0, v, RICH)
	other.auto_assign(v)
	assert_bool(MHStaffFixture.same_list(other.state_list(), _staff.state_list())).is_true()


func test_auto_assign_with_nothing_owned() -> void:
	var v: Dictionary = _view(1)
	_staff.hire("groundskeeper", 0, v, RICH)
	var empty: Dictionary = MHStaffFixture.view({"maintenance": 1}, [])
	assert_int(_staff.auto_assign(empty)).is_equal(0)


func test_wages_follow_grade_and_split_exactly() -> void:
	var v: Dictionary = _view(1)
	_staff.hire("groundskeeper", 0, v, RICH)
	assert_int(_staff.daily_payroll_cents()).is_equal(2200)
	var total: int = 0
	for h: int in range(MHStaffMath.HOURS_PER_DAY):
		total += _staff.hour_wage_cents(h)
	assert_int(total).is_equal(2200)
	for day: int in range(1, 21):
		_staff.on_day(day, v, 5)
	assert_int(_staff.roster.employee(1)["tenure"] as int).is_equal(20)
	assert_int(_staff.daily_payroll_cents()).is_equal(2750)
	for day2: int in range(21, 61):
		_staff.on_day(day2, v, 5)
	assert_int(_staff.daily_payroll_cents()).is_equal(3300)


func test_pay_hour_counts_in_stats_and_hour_wage_does_not() -> void:
	var v: Dictionary = _view(1)
	_staff.hire("groundskeeper", 0, v, RICH)
	_staff.hour_wage_cents(0)
	assert_int(_staff.roster.wages_cents).is_equal(0)
	var paid: int = 0
	for h: int in range(MHStaffMath.HOURS_PER_DAY):
		paid += _staff.pay_hour(h)
	assert_int(paid).is_equal(2200)
	assert_int(_staff.roster.wages_cents).is_equal(2200)


func test_wage_split_matches_the_economy_split() -> void:
	for daily: int in [0, 1, 7, 10, 12345, 999999, 101100]:
		for h: int in range(11):
			assert_int(MHStaffMath.split_hour(daily, h)).is_equal(MHEconomyModel.split_hour(daily, h))
	assert_int(MHStaffMath.HOURS_PER_DAY).is_equal(MHEconomyParams.HOURS_PER_DAY)


func test_gate_count_needs_tenure_and_building() -> void:
	var v: Dictionary = _view(2, 3)
	_staff.hire("marshal", 0, v, RICH)
	_staff.hire("groundskeeper", 0, v, RICH)
	assert_int(_staff.gate_staff_count(v)).is_equal(0)
	for day: int in range(1, 3):
		_staff.on_day(day, v, 5)
	assert_int(_staff.gate_staff_count(v)).is_equal(0)
	_staff.on_day(3, v, 5)
	assert_int(_staff.gate_staff_count(v)).is_equal(2)
	# a view where the clubhouse is gone (never happens in play) drops the marshal
	assert_int(_staff.gate_staff_count(MHStaffFixture.view({"maintenance": 2}, MHStaffFixture.start_owned()))).is_equal(1)


func test_legacy_counts_sum_to_head_count() -> void:
	var v: Dictionary = MHStaffFixture.view(MHStaffFixture.all_tiers(5), range(16))
	for rid: Variant in _defs.role_ids():
		for _i: int in range(9):
			_staff.hire(str(rid), 0, v, RICH)
	var lc: Dictionary = _staff.legacy_counts()
	var sum: int = 0
	for k: Variant in lc.keys():
		sum += int(lc[k])
		assert_int(int(lc[k])).is_between(0, 200)
	assert_int(sum).is_equal(_staff.head_count())
	assert_int(sum).is_equal(30)
	assert_int(int(lc["greenkeepers"])).is_equal(12)
	assert_int(int(lc["marshals"])).is_equal(4)
	assert_int(int(lc["pro_shop_staff"])).is_equal(4)
	assert_int(int(lc["caterers"])).is_equal(10)
