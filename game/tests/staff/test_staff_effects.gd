extends GdUnitTestSuite
## MHStaffEffects and the narrow interfaces to the economy and the tournament gate. NOT YET RUN in Godot.

const RICH: int = 1000000000

var _staff: MHStaff


func before_test() -> void:
	_staff = MHStaffFixture.staff()


func test_fresh_club_demand_and_overlay() -> void:
	var v: Dictionary = MHStaffFixture.view({}, MHStaffFixture.start_owned())
	# condition 700 (+10), pest 100 (-4), no station building (no service term)
	assert_int(_staff.demand_permille(v)).is_equal(1006)
	var ov: Dictionary = _staff.overlay(v)
	assert_int(int(ov["beauty_delta_pm"])).is_equal(10)
	assert_int(int(ov["fairness_delta_pm"])).is_equal(-5)
	assert_int(_staff.condition_penalty_permille(v)).is_equal(0)
	assert_int(_staff.pace_points()).is_equal(0)


func test_service_term_appears_with_a_station_building() -> void:
	var v: Dictionary = MHStaffFixture.view({"clubhouse": 1}, MHStaffFixture.start_owned())
	assert_int(_staff.service_avg(v)).is_equal(0)
	assert_int(_staff.demand_permille(v)).is_equal(976)
	assert_bool(bool(_staff.hire("marshal", 0, v, RICH)["ok"])).is_true()
	assert_int(_staff.service_avg(v)).is_equal(1000)
	assert_int(_staff.demand_permille(v)).is_equal(1036)


func test_floor_division_for_negative_terms() -> void:
	var v: Dictionary = MHStaffFixture.view({}, MHStaffFixture.start_owned())
	for p: int in range(16):
		_staff.grounds.condition[p] = 599
	assert_int(int(_staff.overlay(v)["beauty_delta_pm"])).is_equal(-1)
	for p2: int in range(16):
		_staff.grounds.condition[p2] = 250
	assert_int(int(_staff.overlay(v)["beauty_delta_pm"])).is_equal(-35)
	assert_int(_staff.condition_penalty_permille(v)).is_equal(150)
	for p3: int in range(16):
		_staff.grounds.condition[p3] = 400
	assert_int(_staff.condition_penalty_permille(v)).is_equal(85)


func test_demand_is_clamped() -> void:
	var v: Dictionary = MHStaffFixture.view({"clubhouse": 1}, MHStaffFixture.start_owned())
	for p: int in range(16):
		_staff.grounds.condition[p] = 0
		_staff.grounds.pest[p] = 1000
	assert_int(_staff.demand_permille(v)).is_equal(900)
	for p2: int in range(16):
		_staff.grounds.condition[p2] = 1000
		_staff.grounds.pest[p2] = 0
	var plain: Dictionary = MHStaffFixture.view({}, [5, 6])
	assert_int(_staff.demand_permille(plain)).is_equal(1040)
	assert_int(_staff.demand_permille(plain)).is_less_equal(_staff.defs.param("demand_max"))


func test_pace_points_follow_grades_and_caps() -> void:
	var v: Dictionary = MHStaffFixture.view({"clubhouse": 3, "cart_barn": 2, "maintenance": 2}, MHStaffFixture.start_owned())
	assert_bool(bool(_staff.hire("marshal", 0, v, RICH)["ok"])).is_true()
	assert_bool(bool(_staff.hire("marshal", 0, v, RICH)["ok"])).is_true()
	assert_bool(bool(_staff.hire("caddie", 0, v, RICH)["ok"])).is_true()
	assert_str(_staff.check_hire("caddie", v, RICH)).is_equal("role_cap")
	assert_int(_staff.pace_points()).is_equal(9)
	for day: int in range(1, 21):
		_staff.on_day(day, v, 1)
	assert_int(_staff.pace_points()).is_equal(10)
	for day2: int in range(21, 61):
		_staff.on_day(day2, v, 1)
	assert_int(_staff.pace_points()).is_equal(14)


func test_report_collects_the_numbers() -> void:
	var v: Dictionary = MHStaffFixture.view({"clubhouse": 1}, MHStaffFixture.start_owned())
	_staff.hire("marshal", 0, v, RICH)
	var r: Dictionary = _staff.report(v)
	assert_int(int(r["head_count"])).is_equal(1)
	assert_int(int(r["gate_staff"])).is_equal(0)
	assert_int(int(r["payroll_cents"])).is_equal(2000)
	assert_int(int(r["demand_permille"])).is_equal(1036)
	assert_int(int(r["avg_condition"])).is_equal(700)


func test_tournament_gate_row_uses_the_gate_head_count() -> void:
	var td: MHTournamentDefs = MHTournamentFixture.defs()
	var v: Dictionary = MHStaffFixture.view({"clubhouse": 3, "cart_barn": 2, "maintenance": 2}, MHStaffFixture.start_owned())
	for role: String in ["marshal", "caddie", "groundskeeper", "wildlife_ranger"]:
		assert_bool(bool(_staff.hire(role, 0, v, RICH)["ok"])).is_true()
	var club: Dictionary = MHTournamentFixture.local_view()
	club["staff"] = _staff.gate_staff_count(v)
	assert_bool(MHTournamentRules.entry_report(td, "local", club).row_met("staff")).is_false()
	for day: int in range(1, 4):
		_staff.on_day(day, v, 1)
	club["staff"] = _staff.gate_staff_count(v)
	assert_int(int(club["staff"])).is_equal(4)
	var rep: MHGateReport = MHTournamentRules.entry_report(td, "local", club)
	assert_bool(rep.row_met("staff")).is_true()
	assert_bool(rep.met).is_true()


func test_economy_hooks_wage_and_demand() -> void:
	var eco: MHEconomy = MHEconomy.create_from_defs(MHEconomyParams.load_default(), MHBuildingDefs.load_default())
	var v: Dictionary = MHStaffFixture.view({"maintenance": 2, "clubhouse": 1}, MHStaffFixture.start_owned())
	_staff.hire("groundskeeper", 0, v, RICH)
	_staff.hire("marshal", 0, v, RICH)
	var before: int = eco.cash
	var paid: int = 0
	for h: int in range(MHStaffMath.HOURS_PER_DAY):
		var w: int = _staff.pay_hour(h)
		paid += w
		assert_int(eco.incur_loss(w)).is_equal(MHEconomy.OK)
	assert_int(paid).is_equal(_staff.daily_payroll_cents())
	assert_int(before - eco.cash).is_equal(paid)
	eco.set_demand_modifier(_staff.demand_permille(v))
	assert_int(eco.ext_permille).is_equal(_staff.demand_permille(v))
	assert_int(_staff.demand_permille(v)).is_between(900, 1080)
