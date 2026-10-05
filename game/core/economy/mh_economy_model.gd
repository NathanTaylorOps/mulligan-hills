class_name MHEconomyModel
extends RefCounted
## Pure integer economy formulas (cents). Mirror of tools/reference/economy/mh_economy.py, function for function.
## No state, no floats, no randomness, no engine calls. Division is only ever applied to non-negative operands
## (GDScript int / int truncates toward zero, Python // floors; they agree for non-negative values).
## NOT YET RUN.


@warning_ignore("integer_division")
static func idiv(a: int, b: int) -> int:
	return a / b


## Willingness to pay for one round, cents. rating 0..100 (average hole score), holes counted up to 18.
static func wtp_cents(p: MHEconomyParams, rating: int, holes: int) -> int:
	var h: int = clampi(holes, 0, MHEconomyParams.MAX_HOLES)
	var r: int = clampi(rating, 0, 100)
	return h * (p.c("wtp_base_per_hole_cents") + p.c("wtp_per_rating_per_hole_cents") * r)


## 1000 / (1 + (fee/wtp)^2). 500 at fee == wtp. wtp <= 0 gives 0.
static func acceptance_permille(fee_cents: int, wtp: int) -> int:
	if wtp <= 0:
		return 0
	var f: int = maxi(fee_cents, 0)
	var w2: int = wtp * wtp
	return idiv(w2 * 1000, w2 + f * f)


## 1000 * (rating / 50)^1.5 as isqrt(8 r^3). rating 50 gives 1000, 100 gives 2828.
static func attract_permille(rating: int) -> int:
	var r: int = clampi(rating, 0, 100)
	return MHFixed.isqrt(8 * r * r * r)


## Sum of one effect over the ten buildings. tiers: 10 entries, 0..5. table: eff_dem / eff_anc / eff_flat / eff_cut.
static func effect_sum(table: PackedInt32Array, tiers: PackedInt32Array) -> int:
	var total: int = 0
	for b: int in range(MHEconomyParams.BUILDINGS):
		var t: int = tiers[b]
		if t > 0:
			total += table[b * MHEconomyParams.TIERS + (t - 1)]
	return total


## Golfers who would like to play per day, x1000, before the fee decision.
## dem_add_milli: extra golfers/day x1000 from buildings (additive).
static func arrivals_milli(p: MHEconomyParams, holes: int, rating: int, dem_add_milli: int, rep_permille: int, ext_permille: int) -> int:
	var h: int = clampi(holes, 0, MHEconomyParams.MAX_HOLES)
	var att: int = attract_permille(rating)
	var base: int = p.c("arrivals_base_milli") + idiv(p.c("arrivals_per_hole_milli") * h * att, 1000) + dem_add_milli
	base = idiv(base * rep_permille, 1000)
	return idiv(base * ext_permille, 1000)


## Exact split of a daily amount over the 11 game hours (hour_index 0..10): the parts sum to daily.
static func split_hour(daily: int, hour_index: int) -> int:
	if daily <= 0:
		return 0
	var h: int = clampi(hour_index, 0, MHEconomyParams.HOURS_PER_DAY - 1)
	return idiv(daily * (h + 1), MHEconomyParams.HOURS_PER_DAY) - idiv(daily * h, MHEconomyParams.HOURS_PER_DAY)


## Tee capacity per game hour, x1000 golfers (groups per hour x average group size).
static func hour_cap_milli(p: MHEconomyParams) -> int:
	return p.c("tee_groups_per_hour") * p.c("tee_group_size_x10") * 100


## Golfers accepted in game hour h (0..10), x1000, before the carried remainder.
static func hour_golfers_milli(p: MHEconomyParams, arr_milli: int, acc_permille: int, hour_index: int) -> int:
	var a: int = idiv(arr_milli * p.hour_profile[hour_index], p.profile_total)
	a = idiv(a * acc_permille, 1000)
	return mini(a, hour_cap_milli(p))


## Expected accepted golfers per day x1000, honouring the per-hour tee cap.
static func golfers_day_milli(p: MHEconomyParams, arr_milli: int, acc_permille: int) -> int:
	var tot: int = 0
	for h: int in range(MHEconomyParams.HOURS_PER_DAY):
		tot += hour_golfers_milli(p, arr_milli, acc_permille, h)
	return tot


static func members_target_milli(p: MHEconomyParams, clubhouse_tier: int, rating: int, rep_permille: int) -> int:
	if clubhouse_tier <= 0:
		return 0
	var cap: int = p.member_cap[clampi(clubhouse_tier, 1, MHEconomyParams.TIERS) - 1]
	var num: int = maxi(rating - p.c("member_rating_floor"), 0)
	var f: int = clampi(idiv(num * 1000, p.c("member_rating_span")), 0, 1300)
	return idiv(idiv(cap * 1000 * f, 1000) * rep_permille, 1000)


static func step_members_milli(p: MHEconomyParams, members_milli: int, target_milli: int) -> int:
	var rate: int = p.c("member_join_rate_permille")
	var d: int = target_milli - members_milli
	if d >= 0:
		return members_milli + idiv(d * rate, 1000)
	return members_milli - idiv((-d) * rate, 1000)


static func course_upkeep_cents(p: MHEconomyParams, holes: int, parcels: int, maint_cut_permille: int) -> int:
	var u: int = holes * p.c("hole_upkeep_cents") + parcels * p.c("parcel_upkeep_cents")
	var cut: int = clampi(maint_cut_permille, 0, 900)
	return idiv(u * (1000 - cut), 1000)


## upkeep_dollars: BUILDINGS * TIERS whole dollars (buildings.json upkeep_per_day, the TOTAL for the standing tier).
static func building_upkeep_cents(upkeep_dollars: PackedInt32Array, tiers: PackedInt32Array) -> int:
	var u: int = 0
	for b: int in range(MHEconomyParams.BUILDINGS):
		var t: int = tiers[b]
		if t > 0:
			u += upkeep_dollars[b * MHEconomyParams.TIERS + (t - 1)] * 100
	return u


## Expected one-day figures in integer cents (golfers in thousandths). Used for fee advice and tests.
static func day_estimate(p: MHEconomyParams, upkeep_dollars: PackedInt32Array, tiers: PackedInt32Array, holes: int, parcels: int, rating: int, members_milli: int, fee: int, rep_permille: int, ext_permille: int) -> Dictionary:
	var dem: int = effect_sum(p.eff_dem, tiers)
	var anc: int = effect_sum(p.eff_anc, tiers)
	var arr: int = arrivals_milli(p, holes, rating, dem, rep_permille, ext_permille)
	var acc: int = acceptance_permille(fee, wtp_cents(p, rating, holes))
	var g: int = golfers_day_milli(p, arr, acc)
	var flat: int = idiv(effect_sum(p.eff_flat, tiers) * clampi(rating, 0, 100), 50)
	var dues: int = idiv(members_milli * p.c("member_dues_cents"), 1000)
	var fees: int = idiv(g * fee, 1000)
	var ancr: int = idiv(g * anc, 1000)
	var cut: int = effect_sum(p.eff_cut, tiers)
	var up_course: int = course_upkeep_cents(p, holes, parcels, cut)
	var up_bld: int = building_upkeep_cents(upkeep_dollars, tiers)
	var revenue: int = fees + ancr + flat + dues
	return {
		"arrivals_milli": arr, "acc": acc, "golfers_milli": g, "fees": fees, "anc": ancr, "flat": flat,
		"dues": dues, "revenue": revenue, "upkeep_course": up_course, "upkeep_buildings": up_bld,
		"upkeep": up_course + up_bld, "net": revenue - up_course - up_bld,
	}


## Fee (cents) that maximises fees + ancillary per day; the first maximum wins, so ties go to the lower fee.
static func suggest_fee_cents(p: MHEconomyParams, tiers: PackedInt32Array, holes: int, rating: int, rep_permille: int) -> int:
	var dem: int = effect_sum(p.eff_dem, tiers)
	var anc: int = effect_sum(p.eff_anc, tiers)
	var arr: int = arrivals_milli(p, holes, rating, dem, rep_permille, 1000)
	var w: int = wtp_cents(p, rating, holes)
	var best: int = -1
	var best_fee: int = p.c("fee_min_cents")
	var f: int = p.c("fee_min_cents")
	var f_max: int = p.c("fee_max_cents")
	while f <= f_max:
		var g: int = golfers_day_milli(p, arr, acceptance_permille(f, w))
		var v: int = g * (f + anc)
		if v > best:
			best = v
			best_fee = f
		f += 100
	return best_fee


## DEC-050: price = target payback days x added daily income. Both in the units you pass; result in the same unit.
static func payback_price(target_days: int, added_daily: int) -> int:
	if target_days <= 0 or added_daily <= 0:
		return 0
	return target_days * added_daily


## Mirrors MHLandModel.price_for_purchase_index: whole dollars, integer growth each step, returned in cents.
static func parcel_cost_cents(base_dollars: int, growth_pct: int, purchases_made: int) -> int:
	var d: int = base_dollars
	for _i: int in range(maxi(purchases_made, 0)):
		d = idiv(d * growth_pct, 100)
	return d * 100


## Cost of the next hole when holes_built holes exist (ASSUMPTION: geometric, whole dollars), in cents.
static func hole_cost_cents(p: MHEconomyParams, holes_built: int) -> int:
	var d: int = p.c("hole_cost_base_dollars")
	for _i: int in range(maxi(holes_built - p.c("start_holes"), 0)):
		d = idiv(d * p.c("hole_cost_growth_permille"), 1000)
	return d * 100


## Tokens a sped-up stretch costs under the clock's own rates (MHGameClock): every sped-up game day costs 7.5 tokens at
## any speed above 1x. Returns ceil(7.5 * days). Informational: MHGameClock does the real draining.
static func speed_tokens_for_days(game_days: int) -> int:
	if game_days <= 0:
		return 0
	return idiv(15 * game_days + 1, 2)
