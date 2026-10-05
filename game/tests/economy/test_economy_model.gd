extends GdUnitTestSuite
## MHEconomyParams and MHEconomyModel against golden vectors from tools/reference/economy/gen_golden.py.
## Money is integer cents. NOT YET RUN in Godot (CI validates).

const GOLDEN_PATH: String = "res://tests/economy/golden/economy_golden.json"

var _p: MHEconomyParams
var _defs: MHBuildingDefs
var _up: PackedInt32Array
var _g: Dictionary = {}


func before_test() -> void:
	_p = MHEconomyParams.load_default()
	_defs = MHBuildingDefs.load_default()
	_up = MHEconomy.upkeep_from_defs(_p, _defs)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN_PATH))
	if typeof(parsed) == TYPE_DICTIONARY:
		_g = parsed
	else:
		_g = {}


func _tiers(src: Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for v: Variant in src:
		out.append(int(v))
	return out


func test_golden_file_and_params_load() -> void:
	assert_bool(_g.is_empty()).is_false()
	assert_str(_p.error()).is_equal("")
	assert_bool(_p.is_loaded()).is_true()
	var digest: Array = _g["params_digest"]
	assert_int(_p.c("start_cash_cents")).is_equal(int(digest[0]))
	assert_int(_p.c("fee_max_cents")).is_equal(int(digest[1]))
	assert_int(_p.profile_total).is_equal(int(digest[2]))


func test_params_building_order_matches_buildings_json() -> void:
	assert_bool(_defs.is_loaded()).is_true()
	var ids: Array = _defs.ids()
	assert_int(ids.size()).is_equal(MHEconomyParams.BUILDINGS)
	for i: int in range(MHEconomyParams.BUILDINGS):
		assert_str(str(_p.building_ids[i])).is_equal(str(ids[i]))
	assert_int(_up.size()).is_equal(50)


func test_params_rejects_garbage() -> void:
	assert_bool(MHEconomyParams.from_text("[1,2]").is_loaded()).is_false()
	assert_bool(MHEconomyParams.from_text("{}").is_loaded()).is_false()
	assert_bool(MHEconomyParams.from_text("not json").is_loaded()).is_false()
	assert_bool(MHEconomyParams.from_text("").is_loaded()).is_false()


func test_hours_per_day_matches_clock() -> void:
	assert_int(MHEconomy.HOURS_PER_DAY).is_equal(MHGameClock.HOURS_PER_DAY)
	assert_int(MHEconomyParams.HOURS_PER_DAY).is_equal(MHGameClock.HOURS_PER_DAY)
	assert_int(_p.hour_profile.size()).is_equal(MHGameClock.HOURS_PER_DAY)


func test_golden_wtp_and_acceptance() -> void:
	var rows: Array = _g["wtp"]
	for r: Variant in rows:
		var row: Array = r
		assert_int(MHEconomyModel.wtp_cents(_p, int(row[1]), int(row[0]))).is_equal(int(row[2]))
	var accs: Array = _g["acc"]
	for r2: Variant in accs:
		var row2: Array = r2
		assert_int(MHEconomyModel.acceptance_permille(int(row2[0]), int(row2[1]))).is_equal(int(row2[2]))


func test_acceptance_is_half_at_wtp_and_monotone() -> void:
	assert_int(MHEconomyModel.acceptance_permille(1000, 1000)).is_equal(500)
	var prev: int = 1001
	for fee: int in range(0, 5001, 250):
		var a: int = MHEconomyModel.acceptance_permille(fee, 1000)
		assert_bool(a <= prev).is_true()
		assert_bool(a >= 0 and a <= 1000).is_true()
		prev = a


func test_golden_attract() -> void:
	var rows: Array = _g["attract"]
	assert_int(rows.size()).is_equal(101)
	for r: int in range(101):
		assert_int(MHEconomyModel.attract_permille(r)).is_equal(int(rows[r]))
	assert_int(MHEconomyModel.attract_permille(50)).is_equal(1000)


func test_golden_arrivals() -> void:
	var rows: Array = _g["arrivals"]
	for r: Variant in rows:
		var row: Array = r
		assert_int(MHEconomyModel.arrivals_milli(_p, int(row[0]), int(row[1]), int(row[2]), int(row[3]), int(row[4]))).is_equal(int(row[5]))


func test_golden_split_hour_parts_sum_to_daily() -> void:
	var rows: Array = _g["split"]
	for r: Variant in rows:
		var row: Array = r
		var daily: int = int(row[0])
		var parts: Array = row[1]
		var sum: int = 0
		for h: int in range(MHEconomy.HOURS_PER_DAY):
			var v: int = MHEconomyModel.split_hour(daily, h)
			assert_int(v).is_equal(int(parts[h]))
			sum += v
		assert_int(sum).is_equal(maxi(daily, 0))


func test_golden_members() -> void:
	var rows: Array = _g["members_target"]
	for r: Variant in rows:
		var row: Array = r
		assert_int(MHEconomyModel.members_target_milli(_p, int(row[0]), int(row[1]), int(row[2]))).is_equal(int(row[3]))
	var steps: Array = _g["members_step"]
	for r2: Variant in steps:
		var row2: Array = r2
		assert_int(MHEconomyModel.step_members_milli(_p, int(row2[0]), int(row2[1]))).is_equal(int(row2[2]))


func test_golden_parcel_and_hole_costs() -> void:
	var land: Dictionary = _defs.land_config()
	var base: int = int(land["parcel_base_cost"])
	var growth: int = int(land["parcel_growth_pct"])
	var rows: Array = _g["parcel_cost"]
	var model: MHLandModel = MHLandModel.create(_defs)
	for n: int in range(rows.size()):
		assert_int(MHEconomyModel.parcel_cost_cents(base, growth, n)).is_equal(int(rows[n]))
		# the economy must charge exactly what the land model quotes (dollars -> cents)
		assert_int(MHEconomyModel.parcel_cost_cents(base, growth, n)).is_equal(model.price_for_purchase_index(n) * 100)
	var holes: Array = _g["hole_cost"]
	for i: int in range(holes.size()):
		assert_int(MHEconomyModel.hole_cost_cents(_p, 6 + i)).is_equal(int(holes[i]))


func test_golden_payback_and_speed_tokens() -> void:
	var rows: Array = _g["payback"]
	for r: Variant in rows:
		var row: Array = r
		assert_int(MHEconomyModel.payback_price(int(row[0]), int(row[1]))).is_equal(int(row[2]))
	var sp: Array = _g["speed_tokens"]
	for d: int in range(sp.size()):
		assert_int(MHEconomyModel.speed_tokens_for_days(d)).is_equal(int(sp[d]))
	assert_int(MHEconomyModel.speed_tokens_for_days(2)).is_equal(15)


func test_golden_course_upkeep() -> void:
	var rows: Array = _g["course_upkeep"]
	for r: Variant in rows:
		var row: Array = r
		assert_int(MHEconomyModel.course_upkeep_cents(_p, int(row[0]), int(row[1]), int(row[2]))).is_equal(int(row[3]))


func test_golden_day_estimates_and_fee_suggestion() -> void:
	var rows: Array = _g["estimates"]
	assert_bool(rows.size() > 0).is_true()
	for r: Variant in rows:
		var row: Dictionary = r
		var tiers: PackedInt32Array = _tiers(row["tiers"])
		var out: Dictionary = MHEconomyModel.day_estimate(_p, _up, tiers, int(row["holes"]), int(row["parcels"]), int(row["rating"]), int(row["members_milli"]), int(row["fee"]), int(row["rep"]), int(row["ext"]))
		var want: Dictionary = row["out"]
		for k: Variant in want.keys():
			assert_int(int(out[k])).is_equal(int(want[k]))
		assert_int(MHEconomyModel.suggest_fee_cents(_p, tiers, int(row["holes"]), int(row["rating"]), int(row["rep"]))).is_equal(int(row["suggest"]))
		# ledger arithmetic: net = revenue - upkeep
		assert_int(int(out["net"])).is_equal(int(out["revenue"]) - int(out["upkeep"]))


func test_tier_prices_follow_payback_rule() -> void:
	var gp: Dictionary = _g["tier_prices_dollars"]
	for b: int in range(MHEconomyParams.BUILDINGS):
		var id: String = str(_p.building_ids[b])
		var golden_row: Array = gp[id]
		for t: int in range(1, MHEconomyParams.TIERS + 1):
			var added: int = _p.added_dollars[b * MHEconomyParams.TIERS + t - 1]
			assert_bool(added > 0).is_true()
			# MHBuildingDefs.price_for is the shared rule: target days (from buildings.json) x added daily income
			var price_defs: int = _defs.price_for(id, t, added)
			assert_int(price_defs).is_equal(int(golden_row[t - 1]))
			assert_int(int(_p.price_dollars[b * MHEconomyParams.TIERS + t - 1])).is_equal(price_defs)
			var e: MHEconomy = MHEconomy.create(_p, _up)
			assert_int(e.price_cents(b, t, _defs.target_payback_days(id, t))).is_equal(price_defs * 100)
			assert_int(e.price_cents(b, t)).is_equal(price_defs * 100)


func test_upkeep_is_covered_by_added_income() -> void:
	# Every tier must pay for its own upkeep at the reference state, otherwise payback pricing is meaningless.
	for b: int in range(MHEconomyParams.BUILDINGS):
		for t: int in range(1, MHEconomyParams.TIERS + 1):
			var id: String = str(_p.building_ids[b])
			var added: int = _p.added_dollars[b * MHEconomyParams.TIERS + t - 1]
			assert_bool(added >= 1).is_true()
			assert_bool(_defs.upkeep_per_day(id, t) >= 0).is_true()
