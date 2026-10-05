extends GdUnitTestSuite
## MHEconomy state machine: cash, fee, hourly tick, upkeep, bankruptcy, free bank loan, token recovery hook, save.
## Scenarios replay golden traces from tools/reference/economy/gen_golden.py. NOT YET RUN in Godot (CI validates).

const GOLDEN_PATH: String = "res://tests/economy/golden/economy_golden.json"

var _p: MHEconomyParams
var _defs: MHBuildingDefs
var _g: Dictionary = {}


func before_test() -> void:
	_p = MHEconomyParams.load_default()
	_defs = MHBuildingDefs.load_default()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		_g = parsed
	else:
		_g = {}


func _new_eco() -> MHEconomy:
	var e: MHEconomy = MHEconomy.create_from_defs(_p, _defs)
	assert_object(e).is_not_null()
	return e


func _check_state(e: MHEconomy, want: Array) -> void:
	var got: PackedInt64Array = e.state_list()
	assert_int(got.size()).is_equal(want.size())
	for i: int in range(want.size()):
		assert_int(got[i]).is_equal(int(want[i]))


func _replay(e: MHEconomy, rows: Array) -> void:
	for r: Variant in rows:
		var row: Dictionary = r
		var out: Dictionary = e.tick_hour()
		assert_int(int(out["revenue"])).is_equal(int(row["rev"]))
		assert_int(int(out["golfers"])).is_equal(int(row["golfers"]))
		assert_int(int(out["upkeep_paid"])).is_equal(int(row["paid"]))
		_check_state(e, row["state"])


func _same_dict(a: Dictionary, want: Dictionary) -> void:
	for k: Variant in want.keys():
		if str(k) == "tiers":
			var wt: Array = want[k]
			var gt: Array = a[k]
			assert_int(gt.size()).is_equal(wt.size())
			for i: int in range(wt.size()):
				assert_int(int(gt[i])).is_equal(int(wt[i]))
		else:
			assert_int(int(a[k])).is_equal(int(want[k]))


func test_start_state() -> void:
	var e: MHEconomy = _new_eco()
	assert_int(e.cash).is_equal(_p.c("start_cash_cents"))
	assert_int(e.green_fee()).is_equal(_p.c("fee_start_cents"))
	assert_int(e.holes).is_equal(6)
	assert_int(e.parcels).is_equal(5)
	assert_bool(e.is_bankrupt()).is_false()
	assert_int(e.members()).is_equal(0)
	assert_int(e.daily_upkeep()).is_equal(6 * _p.c("hole_upkeep_cents") + 5 * _p.c("parcel_upkeep_cents"))


func test_create_rejects_bad_inputs() -> void:
	assert_object(MHEconomy.create(_p, PackedInt32Array([1, 2, 3]))).is_null()
	assert_object(MHEconomy.create(null, PackedInt32Array())).is_null()
	assert_object(MHEconomy.create(MHEconomyParams.new(), PackedInt32Array())).is_null()


func test_spend_and_earn_rules() -> void:
	var e: MHEconomy = _new_eco()
	var start: int = _p.c("start_cash_cents")
	assert_int(e.spend(-1)).is_equal(MHEconomy.ERR_INVALID)
	assert_int(e.cash).is_equal(start)
	assert_int(e.spend(start + 1)).is_equal(MHEconomy.ERR_INSUFFICIENT)
	assert_int(e.cash).is_equal(start)
	assert_bool(e.can_afford(start)).is_true()
	assert_bool(e.can_afford(start + 1)).is_false()
	assert_int(e.spend(start)).is_equal(MHEconomy.OK)
	assert_int(e.cash).is_equal(0)
	assert_int(e.earn(-5)).is_equal(MHEconomy.ERR_INVALID)
	assert_int(e.earn(250)).is_equal(MHEconomy.OK)
	assert_int(e.cash).is_equal(250)


func test_cash_never_negative_by_spending() -> void:
	var e: MHEconomy = _new_eco()
	for i: int in range(60):
		e.spend(137000 + i)
		assert_bool(e.cash >= 0).is_true()


func test_fee_clamps_to_range() -> void:
	var e: MHEconomy = _new_eco()
	assert_int(e.set_green_fee(100)).is_equal(500)
	assert_int(e.set_green_fee(999999)).is_equal(25000)
	assert_int(e.set_green_fee(4200)).is_equal(4200)
	assert_int(e.green_fee()).is_equal(4200)
	assert_int(e.set_green_fee(-7)).is_equal(500)


func test_suggested_fee_is_inside_range_and_beats_extremes() -> void:
	var e: MHEconomy = _new_eco()
	e.set_course(10, 42, 8)
	var f: int = e.suggest_fee()
	assert_bool(f >= 500 and f <= 25000).is_true()
	var best: int = 0
	e.set_green_fee(f)
	best = int(e.estimate_day()["fees"])
	e.set_green_fee(500)
	assert_bool(best >= int(e.estimate_day()["fees"])).is_true()
	e.set_green_fee(25000)
	assert_bool(best >= int(e.estimate_day()["fees"])).is_true()


func test_tick_hour_advances_clock_and_rolls_day() -> void:
	var e: MHEconomy = _new_eco()
	for i: int in range(MHEconomy.HOURS_PER_DAY - 1):
		var out: Dictionary = e.tick_hour()
		assert_bool(bool(out["day_rolled"])).is_false()
	assert_int(e.hour).is_equal(10)
	var last: Dictionary = e.tick_hour()
	assert_bool(bool(last["day_rolled"])).is_true()
	assert_int(e.day).is_equal(1)
	assert_int(e.hour).is_equal(0)


func test_day_ledger_sums_to_cash_change() -> void:
	var e: MHEconomy = _new_eco()
	e.set_course(8, 40, 7)
	e.set_tier(0, 2)
	e.set_tier(1, 1)
	e.set_green_fee(e.suggest_fee())
	var start_cash: int = e.cash
	var revenue: int = 0
	var paid: int = 0
	for i: int in range(MHEconomy.HOURS_PER_DAY * 3):
		var out: Dictionary = e.tick_hour()
		revenue += int(out["revenue"])
		paid += int(out["upkeep_paid"])
		assert_int(int(out["revenue"])).is_equal(int(out["fees"]) + int(out["ancillary"]) + int(out["flat"]))
	assert_int(e.cash).is_equal(start_cash + revenue - paid)
	assert_int(e.total_revenue).is_equal(revenue)
	assert_int(e.total_upkeep_paid).is_equal(paid)


func test_daily_upkeep_is_paid_exactly_over_a_day() -> void:
	var e: MHEconomy = _new_eco()
	e.set_course(6, 34, 5)
	e.set_tier(2, 1)
	e.set_demand_modifier(0)
	e.set_tier(4, 1)
	var up: int = e.daily_upkeep()
	var paid: int = 0
	for i: int in range(MHEconomy.HOURS_PER_DAY):
		var out: Dictionary = e.tick_hour()
		paid += int(out["upkeep_paid"])
	assert_int(paid).is_equal(up)


func test_golden_day_cycle() -> void:
	var sc: Dictionary = _g["scenario_day_cycle"]
	var e: MHEconomy = _new_eco()
	assert_bool(e.from_dict(sc["init"])).is_true()
	_replay(e, sc["rows"])
	_same_dict(e.to_dict(), sc["final"])


func test_golden_bankruptcy_and_free_loan() -> void:
	var sc: Dictionary = _g["scenario_loan"]
	var e: MHEconomy = _new_eco()
	assert_bool(e.from_dict(sc["init"])).is_true()
	var rows: Array = sc["rows"]
	assert_int(rows.size()).is_equal(int(sc["bankrupt_tick"]) + 1)
	for i: int in range(rows.size()):
		assert_bool(e.is_bankrupt()).is_false()
		var row: Dictionary = rows[i]
		e.tick_hour()
		_check_state(e, row["state"])
	assert_bool(e.is_bankrupt()).is_true()
	# a bankrupt club cannot spend
	assert_int(e.spend(1)).is_equal(MHEconomy.ERR_BANKRUPT)
	assert_bool(e.can_afford(1)).is_false()
	assert_int(e.recovery_options(0)).is_equal(int(sc["options_no_tokens"]))
	assert_int(e.recovery_options(5)).is_equal(int(sc["options_tokens5"]))
	var rep_before: int = e.reputation
	var lent: int = e.take_bank_loan()
	assert_int(lent).is_equal(int(sc["loan"]))
	assert_bool(e.reputation < rep_before).is_true()
	assert_int(e.reputation).is_equal(rep_before - _p.c("loan_rep_penalty_permille"))
	_same_dict(e.to_dict(), sc["after_loan"])
	assert_bool(e.is_bankrupt()).is_false()
	e.set_course(10, 40, 8)
	e.set_demand_modifier(1000)
	e.set_green_fee(900)
	_replay(e, sc["rows_after"])
	_same_dict(e.to_dict(), sc["final"])


func test_loan_is_limited_and_needs_bankruptcy() -> void:
	var e: MHEconomy = _new_eco()
	assert_int(e.take_bank_loan()).is_equal(-MHEconomy.ERR_NOT_AVAILABLE)
	assert_int(e.recovery_options(99)).is_equal(0)
	var sc: Dictionary = _g["scenario_loan"]
	assert_bool(e.from_dict(sc["init"])).is_true()
	for i: int in range(80):
		e.tick_hour()
		if e.is_bankrupt():
			break
	assert_bool(e.is_bankrupt()).is_true()
	e.loans_taken = _p.c("loan_max_taken")
	assert_int(e.recovery_options(0) & MHEconomy.OPT_LOAN).is_equal(0)
	assert_int(e.take_bank_loan()).is_equal(-MHEconomy.ERR_NOT_AVAILABLE)


func test_golden_token_recovery_through_ledger() -> void:
	var sc: Dictionary = _g["scenario_tokens"]
	var e: MHEconomy = _new_eco()
	assert_bool(e.from_dict(sc["init"])).is_true()
	var ledger: MHTokenLedger = MHTokenLedger.new()
	# not bankrupt yet: nothing happens and no tokens are spent
	ledger.grant_earned("daily_login", "a")
	ledger.grant_earned("daily_login", "b")
	assert_int(ledger.total()).is_equal(4)
	assert_int(e.recover_with_tokens(ledger)).is_equal(MHEconomy.ERR_NOT_AVAILABLE)
	assert_int(ledger.total()).is_equal(4)
	var rows: Array = sc["rows"]
	for r: Variant in rows:
		e.tick_hour()
	assert_bool(e.is_bankrupt()).is_true()
	# too few tokens: refused, balance untouched
	var poor: MHTokenLedger = MHTokenLedger.new()
	assert_int(e.recover_with_tokens(poor)).is_equal(MHEconomy.ERR_INSUFFICIENT)
	assert_int(e.recover_with_tokens(null)).is_equal(MHEconomy.ERR_INSUFFICIENT)
	assert_bool(e.is_bankrupt()).is_true()
	var cash_before: int = e.cash
	assert_int(e.recover_with_tokens(ledger)).is_equal(int(sc["result"]))
	assert_int(ledger.total()).is_equal(4 - int(sc["token_cost"]))
	# the token path grants no cash
	assert_int(e.cash).is_equal(cash_before)
	_same_dict(e.to_dict(), sc["after"])
	e.set_course(10, 40, 8)
	e.set_demand_modifier(1000)
	e.set_green_fee(900)
	_replay(e, sc["rows_after"])
	_same_dict(e.to_dict(), sc["final"])


func test_speed_hook_is_pure_token_arithmetic() -> void:
	var e: MHEconomy = _new_eco()
	var ledger: MHTokenLedger = MHTokenLedger.new()
	assert_bool(e.can_afford_speed(ledger, 1)).is_false()
	assert_bool(e.can_afford_speed(null, 1)).is_false()
	ledger.grant_earned("daily_login", "x")
	ledger.grant_earned("challenge_complete", "c1")
	ledger.grant_earned("tournament_result", "t1", 1)
	assert_int(ledger.total()).is_equal(15)
	assert_bool(e.can_afford_speed(ledger, 2)).is_true()
	assert_bool(e.can_afford_speed(ledger, 3)).is_false()
	# checking never spends
	assert_int(ledger.total()).is_equal(15)
	assert_int(e.cash).is_equal(e.params.c("start_cash_cents"))


func test_purchase_tier_charges_the_payback_price() -> void:
	var e: MHEconomy = _new_eco()
	var price: int = e.price_cents(1, 1)
	assert_bool(price > 0).is_true()
	assert_int(e.purchase_tier(1, 2)).is_equal(MHEconomy.ERR_INVALID)
	assert_int(e.purchase_tier(1, 1)).is_equal(MHEconomy.OK)
	assert_int(e.cash).is_equal(e.params.c("start_cash_cents") - price)
	assert_int(e.tier_of(1)).is_equal(1)
	assert_int(e.purchase_tier(1, 1)).is_equal(MHEconomy.ERR_INVALID)
	assert_int(e.purchase_tier(99, 1)).is_equal(MHEconomy.ERR_INVALID)
	e.cash = 0
	assert_int(e.purchase_tier(1, 2)).is_equal(MHEconomy.ERR_INSUFFICIENT)
	assert_int(e.tier_of(1)).is_equal(1)


func test_start_cash_covers_all_tier_one_and_two_buildings() -> void:
	var total: int = 0
	var e: MHEconomy = _new_eco()
	for b: int in range(MHEconomyParams.BUILDINGS):
		total += e.price_cents(b, 1) + e.price_cents(b, 2)
	assert_bool(total < e.cash).is_true()


func test_save_roundtrip_and_bad_input() -> void:
	var e: MHEconomy = _new_eco()
	e.set_course(9, 41, 7)
	e.set_tier(0, 2)
	e.set_tier(3, 1)
	e.set_green_fee(1700)
	for i: int in range(25):
		e.tick_hour()
	var saved: Dictionary = e.to_dict()
	var text: String = JSON.stringify(saved)
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(typeof(parsed) == TYPE_DICTIONARY).is_true()
	var f: MHEconomy = _new_eco()
	assert_bool(f.from_dict(parsed)).is_true()
	assert_array(Array(f.state_list())).is_equal(Array(e.state_list()))
	assert_int(f.tier_of(0)).is_equal(2)
	# both continue identically
	for i: int in range(22):
		var a: Dictionary = e.tick_hour()
		var b: Dictionary = f.tick_hour()
		assert_int(int(a["revenue"])).is_equal(int(b["revenue"]))
	assert_int(f.cash).is_equal(e.cash)
	# bad input changes nothing
	var before: int = f.cash
	assert_bool(f.from_dict({"cash": 1.5})).is_false()
	assert_bool(f.from_dict({"hour": 99})).is_false()
	assert_bool(f.from_dict({"tiers": [1, 2]})).is_false()
	assert_bool(f.from_dict({"tiers": [9, 0, 0, 0, 0, 0, 0, 0, 0, 0]})).is_false()
	assert_int(f.cash).is_equal(before)


func test_deterministic_replay() -> void:
	var a: MHEconomy = _new_eco()
	var b: MHEconomy = _new_eco()
	for e: MHEconomy in [a, b]:
		e.set_course(12, 46, 10)
		e.set_tier(0, 3)
		e.set_tier(1, 2)
		e.set_tier(3, 2)
		e.set_green_fee(2100)
	for i: int in range(MHEconomy.HOURS_PER_DAY * 10):
		a.tick_hour()
		b.tick_hour()
	assert_array(Array(a.state_list())).is_equal(Array(b.state_list()))


func test_golden_renovation_sink() -> void:
	var sc: Dictionary = _g["scenario_renovation"]
	var e: MHEconomy = _new_eco()
	assert_bool(e.from_dict(sc["init"])).is_true()
	assert_int(e.renovation).is_equal(0)
	assert_bool(e.renovation_available()).is_true()
	# refused when the course is short of 18 holes or one building is below renov_min_tier, and nothing is spent
	var na: Array = sc["not_available"]
	var short: MHEconomy = _new_eco()
	short.from_dict({"cash": 1000000000, "holes": 17, "tiers": [5, 5, 5, 5, 5, 5, 5, 5, 5, 5]})
	assert_int(short.purchase_renovation()).is_equal(int(na[0]))
	assert_int(short.cash).is_equal(1000000000)
	var low: MHEconomy = _new_eco()
	low.from_dict({"cash": 1000000000, "holes": 18, "tiers": [5, 5, 5, 5, 5, 5, 5, 5, 5, 3]})
	assert_int(low.purchase_renovation()).is_equal(int(na[1]))
	assert_int(low.cash).is_equal(1000000000)
	var res: Array = sc["results"]
	var upkeep0: int = e.daily_upkeep()
	assert_int(e.purchase_renovation()).is_equal(int(res[0]))
	_same_dict(e.to_dict(), sc["after1"])
	assert_bool(e.daily_upkeep() > upkeep0).is_true()
	assert_int(e.purchase_renovation()).is_equal(int(res[1]))
	_same_dict(e.to_dict(), sc["after2"])
	var cash_before: int = e.cash
	assert_int(e.purchase_renovation()).is_equal(int(res[2]))
	assert_int(e.cash).is_equal(cash_before)
	assert_int(e.renovation).is_equal(2)
	_replay(e, sc["rows"])
	_same_dict(e.to_dict(), sc["final"])


func test_renovation_stops_at_the_maximum_and_survives_save() -> void:
	var e: MHEconomy = _new_eco()
	e.from_dict({"cash": 1000000000000, "holes": 18, "tiers": [5, 5, 5, 5, 5, 5, 5, 5, 5, 5]})
	for i: int in range(_p.c("renov_max_levels")):
		assert_int(e.purchase_renovation()).is_equal(MHEconomy.OK)
	assert_bool(e.renovation_available()).is_false()
	assert_int(e.renovation_cost()).is_equal(0)
	assert_int(e.purchase_renovation()).is_equal(MHEconomy.ERR_NOT_AVAILABLE)
	var f: MHEconomy = _new_eco()
	assert_bool(f.from_dict(e.to_dict())).is_true()
	assert_int(f.renovation).is_equal(_p.c("renov_max_levels"))
	assert_bool(f.from_dict({"renovation": _p.c("renov_max_levels") + 1})).is_false()
	assert_bool(f.from_dict({"renovation": -1})).is_false()


func test_renovation_requires_every_building_at_tier_five() -> void:
	var e: MHEconomy = _new_eco()
	e.from_dict({"cash": 1000000000, "holes": 18, "tiers": [4, 4, 4, 4, 4, 4, 4, 4, 4, 4]})
	assert_int(_p.c("renov_min_tier")).is_equal(5)
	assert_bool(e.renovation_available()).is_false()
	assert_int(e.purchase_renovation()).is_equal(MHEconomy.ERR_NOT_AVAILABLE)
	assert_int(e.renovation).is_equal(0)
	e.from_dict({"tiers": [5, 5, 5, 5, 5, 5, 5, 5, 5, 5]})
	assert_bool(e.renovation_available()).is_true()
	assert_int(e.purchase_renovation()).is_equal(MHEconomy.OK)
	assert_int(e.renovation).is_equal(1)
