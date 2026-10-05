class_name MHEconomy
extends RefCounted
## Club cash and daily accounting (DEC-049 to DEC-053). Integer CENTS, deterministic, no RNG, no floats.
## Mirror of tools/reference/economy/mh_economy.py (class Economy). NOT YET RUN in Godot.
##
## What it does
##  - tick_hour(): call ONCE per MHGameClock.EV_HOUR event (11 per game day). Works out the golfers accepted this hour
##    (arrivals x fee acceptance, per-hour tee cap, remainder carried so nothing is lost to rounding), green fees,
##    ancillary spend, flat income and member dues, pays upkeep (buildings from buildings.json + holes + parcels),
##    carries unpaid upkeep as arrears and flags bankruptcy.
##  - Fee: set_green_fee clamps to [fee_min, fee_max]; suggest_fee() gives the revenue-maximising fee for the current club.
##  - Prices: price_cents() = target payback days x added daily income (DEC-050), from the economy_params.json table.
##  - Bankruptcy: free bank loan (no interest, repaid from a share of revenue, costs reputation) and a token-gated recovery
##    hook. Tokens are only DEBITED through an MHTokenLedger passed in; there is no purchase or store code here, and
##    neither recovery path ever grants spendable cash beyond the loan.
##  - Speed hook: speed_tokens_for_days() is informational (MHGameClock does the draining).
## The caller (UI / save / events) owns: course rating and hole count (set_course), tier ownership (set_tier), parcels,
## and a demand modifier from events (set_demand_modifier). Gate checks (MHUnlockRules) happen BEFORE purchase_tier.

signal cash_changed(new_cash: int, delta: int, reason: int)

const OK: int = 0
const ERR_INSUFFICIENT: int = 1
const ERR_INVALID: int = 2
const ERR_BANKRUPT: int = 3
const ERR_NOT_AVAILABLE: int = 4

const OPT_LOAN: int = 1
const OPT_TOKEN: int = 2

const REASON_SPEND: int = 1
const REASON_EARN: int = 2
const REASON_TICK: int = 3
const REASON_LOAN: int = 4

const HOURS_PER_DAY: int = 11
const SAVE_VERSION: int = 1

const _INT_KEYS: Array = [
	"cash", "fee", "day", "hour", "arrears", "loan_balance", "loans_taken", "reputation", "holiday_hours", "carry_milli",
	"last_daily_upkeep", "members_milli", "holes", "rating", "parcels", "ext_permille", "total_revenue", "total_upkeep_paid",
]

var params: MHEconomyParams
var upkeep_dollars: PackedInt32Array = PackedInt32Array()

var cash: int = 0
var fee: int = 0
var day: int = 0
var hour: int = 0
var arrears: int = 0
var loan_balance: int = 0
var loans_taken: int = 0
var reputation: int = 1000
var holiday_hours: int = 0
var bankrupt: bool = false
var carry_milli: int = 0
var last_daily_upkeep: int = 0
var members_milli: int = 0
var holes: int = 6
var rating: int = 34
var parcels: int = 5
var ext_permille: int = 1000
var tiers: PackedInt32Array = PackedInt32Array()
var total_revenue: int = 0
var total_upkeep_paid: int = 0


## upkeep_table: BUILDINGS * TIERS whole dollars (see upkeep_from_defs). Returns null when the table has the wrong size.
static func create(p: MHEconomyParams, upkeep_table: PackedInt32Array) -> MHEconomy:
	if p == null or not p.is_loaded():
		return null
	if upkeep_table.size() != MHEconomyParams.BUILDINGS * MHEconomyParams.TIERS:
		return null
	var e: MHEconomy = MHEconomy.new()
	e.params = p
	e.upkeep_dollars = upkeep_table
	e.reset_to_start()
	return e


static func create_from_defs(p: MHEconomyParams, defs: MHBuildingDefs) -> MHEconomy:
	var table: PackedInt32Array = upkeep_from_defs(p, defs)
	return create(p, table)


## Builds the upkeep table in the params' building order from buildings.json. Empty when an id is missing.
static func upkeep_from_defs(p: MHEconomyParams, defs: MHBuildingDefs) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	if p == null or defs == null or not defs.is_loaded():
		return out
	for b: int in range(MHEconomyParams.BUILDINGS):
		var id: String = str(p.building_ids[b])
		if not defs.has_building(id):
			return PackedInt32Array()
		for t: int in range(1, MHEconomyParams.TIERS + 1):
			out.append(defs.upkeep_per_day(id, t))
	return out


func reset_to_start() -> void:
	cash = params.c("start_cash_cents")
	fee = params.c("fee_start_cents")
	day = 0
	hour = 0
	arrears = 0
	loan_balance = 0
	loans_taken = 0
	reputation = 1000
	holiday_hours = 0
	bankrupt = false
	carry_milli = 0
	last_daily_upkeep = 0
	members_milli = 0
	holes = params.c("start_holes")
	rating = params.c("start_rating")
	parcels = params.c("start_parcels")
	ext_permille = 1000
	tiers = PackedInt32Array()
	tiers.resize(MHEconomyParams.BUILDINGS)
	total_revenue = 0
	total_upkeep_paid = 0


# ------------------------------------------------------------------ inputs owned by other modules
func set_course(new_holes: int, new_rating: int, new_parcels: int) -> void:
	holes = clampi(new_holes, 0, MHEconomyParams.MAX_HOLES)
	rating = clampi(new_rating, 0, 100)
	parcels = maxi(new_parcels, 0)


func set_tier(building_index: int, tier: int) -> void:
	if building_index < 0 or building_index >= MHEconomyParams.BUILDINGS:
		return
	tiers[building_index] = clampi(tier, 0, MHEconomyParams.TIERS)


func tier_of(building_index: int) -> int:
	if building_index < 0 or building_index >= MHEconomyParams.BUILDINGS:
		return 0
	return tiers[building_index]


## Demand modifier from events, permille of normal (1000 = normal), clamped 0..3000.
func set_demand_modifier(permille: int) -> void:
	ext_permille = clampi(permille, 0, 3000)


# ------------------------------------------------------------------ cash
func can_afford(cost: int) -> bool:
	return cost >= 0 and cash >= cost and not bankrupt


func spend(cost: int, reason: int = REASON_SPEND) -> int:
	if cost < 0:
		return ERR_INVALID
	if bankrupt:
		return ERR_BANKRUPT
	if cash < cost:
		return ERR_INSUFFICIENT
	cash -= cost
	if cost != 0:
		cash_changed.emit(cash, -cost, reason)
	return OK


func earn(amount: int, reason: int = REASON_EARN) -> int:
	if amount < 0:
		return ERR_INVALID
	cash += amount
	if amount != 0:
		cash_changed.emit(cash, amount, reason)
	return OK


# ------------------------------------------------------------------ fee
func set_green_fee(fee_cents: int) -> int:
	fee = clampi(fee_cents, params.c("fee_min_cents"), params.c("fee_max_cents"))
	return fee


func green_fee() -> int:
	return fee


func suggest_fee() -> int:
	return MHEconomyModel.suggest_fee_cents(params, tiers, holes, rating, reputation)


func members() -> int:
	return MHEconomyModel.idiv(members_milli, 1000)


# ------------------------------------------------------------------ prices (DEC-050)
## Price in cents of tier `tier` of building `building_index`. target_days_override > 0 uses that target instead of
## the params' table (pass MHBuildingDefs.target_payback_days so buildings.json stays the source of the targets).
func price_cents(building_index: int, tier: int, target_days_override: int = 0) -> int:
	if building_index < 0 or building_index >= MHEconomyParams.BUILDINGS or tier < 1 or tier > MHEconomyParams.TIERS:
		return 0
	var target: int = target_days_override
	if target <= 0:
		target = params.payback_targets[tier - 1]
	var added: int = params.added_dollars[building_index * MHEconomyParams.TIERS + (tier - 1)]
	return MHEconomyModel.payback_price(target, added * 100)


## Spend the price and raise the tier by exactly one. Gate checks are the caller's job (MHUnlockRules).
func purchase_tier(building_index: int, tier: int, target_days_override: int = 0) -> int:
	if building_index < 0 or building_index >= MHEconomyParams.BUILDINGS:
		return ERR_INVALID
	if tier != tiers[building_index] + 1 or tier > MHEconomyParams.TIERS:
		return ERR_INVALID
	var r: int = spend(price_cents(building_index, tier, target_days_override))
	if r != OK:
		return r
	tiers[building_index] = tier
	return OK


## Cost in cents of the n-th land purchase (n from 0), same rule as MHLandModel.
func parcel_cost_cents(purchases_made: int, base_dollars: int, growth_pct: int) -> int:
	return MHEconomyModel.parcel_cost_cents(base_dollars, growth_pct, purchases_made)


func hole_cost_cents() -> int:
	return MHEconomyModel.hole_cost_cents(params, holes)


# ------------------------------------------------------------------ upkeep
func daily_upkeep() -> int:
	var cut: int = MHEconomyModel.effect_sum(params.eff_cut, tiers)
	return MHEconomyModel.course_upkeep_cents(params, holes, parcels, cut) + MHEconomyModel.building_upkeep_cents(upkeep_dollars, tiers)


func estimate_day() -> Dictionary:
	return MHEconomyModel.day_estimate(params, upkeep_dollars, tiers, holes, parcels, rating, members_milli, fee, reputation, ext_permille)


# ------------------------------------------------------------------ the hourly tick
## One game hour. Returns a Dictionary: golfers, fees, ancillary, flat, revenue, repaid, upkeep_due, upkeep_paid,
## arrears, cash, bankrupt, day_rolled (all int except the bools).
func tick_hour() -> Dictionary:
	var cash_before: int = cash
	var h: int = hour
	var dem: int = MHEconomyModel.effect_sum(params.eff_dem, tiers)
	var anc: int = MHEconomyModel.effect_sum(params.eff_anc, tiers)
	var arr: int = MHEconomyModel.arrivals_milli(params, holes, rating, dem, reputation, ext_permille)
	var acc: int = MHEconomyModel.acceptance_permille(fee, MHEconomyModel.wtp_cents(params, rating, holes))
	var a: int = MHEconomyModel.hour_golfers_milli(params, arr, acc, h) + carry_milli
	var golfers: int = MHEconomyModel.idiv(a, 1000)
	carry_milli = a - golfers * 1000
	var fees: int = golfers * fee
	var ancr: int = golfers * anc
	var flat_day: int = MHEconomyModel.idiv(MHEconomyModel.effect_sum(params.eff_flat, tiers) * clampi(rating, 0, 100), 50)
	var dues_day: int = MHEconomyModel.idiv(members_milli * params.c("member_dues_cents"), 1000)
	var flat: int = MHEconomyModel.split_hour(flat_day + dues_day, h)
	var revenue: int = fees + ancr + flat
	cash += revenue
	total_revenue += revenue
	var repaid: int = 0
	if loan_balance > 0 and revenue > 0:
		repaid = mini(mini(loan_balance, MHEconomyModel.idiv(revenue * params.c("loan_repay_share_permille"), 1000)), cash)
		loan_balance -= repaid
		cash -= repaid
	last_daily_upkeep = daily_upkeep()
	var due_now: int = 0
	if holiday_hours > 0:
		holiday_hours -= 1
	else:
		due_now = MHEconomyModel.split_hour(last_daily_upkeep, h)
	var owed: int = arrears + due_now
	var paid: int = mini(cash, owed)
	cash -= paid
	arrears = owed - paid
	total_upkeep_paid += paid
	_update_bankrupt()
	hour += 1
	var rolled: bool = false
	if hour >= HOURS_PER_DAY:
		hour = 0
		day += 1
		rolled = true
		reputation = mini(1000, reputation + params.c("rep_recover_per_day_permille"))
		var tgt: int = MHEconomyModel.members_target_milli(params, tiers[0], rating, reputation)
		members_milli = MHEconomyModel.step_members_milli(params, members_milli, tgt)
	if cash != cash_before:
		cash_changed.emit(cash, cash - cash_before, REASON_TICK)
	return {
		"golfers": golfers, "fees": fees, "ancillary": ancr, "flat": flat, "revenue": revenue, "repaid": repaid,
		"upkeep_due": due_now, "upkeep_paid": paid, "arrears": arrears, "cash": cash, "bankrupt": bankrupt,
		"day_rolled": rolled,
	}


func _update_bankrupt() -> void:
	if arrears == 0:
		bankrupt = false
		return
	if bankrupt:
		return
	if arrears < params.c("bankrupt_min_arrears_cents"):
		return
	var d: int = last_daily_upkeep
	if d <= 0:
		return
	if arrears * 10 >= params.c("bankrupt_arrears_days_x10") * d:
		bankrupt = true


# ------------------------------------------------------------------ bankruptcy recovery
func is_bankrupt() -> bool:
	return bankrupt


## Bit mask of OPT_LOAN / OPT_TOKEN. 0 when not bankrupt.
func recovery_options(tokens_available: int) -> int:
	if not bankrupt:
		return 0
	var o: int = 0
	if loans_taken < params.c("loan_max_taken"):
		o |= OPT_LOAN
	if tokens_available >= params.c("recovery_token_cost"):
		o |= OPT_TOKEN
	return o


func loan_amount_cents() -> int:
	var a: int = params.c("loan_upkeep_days") * last_daily_upkeep + arrears
	return clampi(a, params.c("loan_min_cents"), params.c("loan_max_cents"))


## Free bank loan: no interest, no fee unless loan_fee_permille > 0, repaid from a share of revenue, costs reputation.
## Returns the amount lent (>= 0) or a negative error code.
func take_bank_loan() -> int:
	if not bankrupt:
		return -ERR_NOT_AVAILABLE
	if loans_taken >= params.c("loan_max_taken"):
		return -ERR_NOT_AVAILABLE
	var amount: int = loan_amount_cents()
	cash += amount
	loan_balance += amount + MHEconomyModel.idiv(amount * params.c("loan_fee_permille"), 1000)
	loans_taken += 1
	reputation = maxi(params.c("rep_floor_permille"), reputation - params.c("loan_rep_penalty_permille"))
	var paid: int = mini(cash, arrears)
	cash -= paid
	arrears -= paid
	_update_bankrupt()
	cash_changed.emit(cash, amount - paid, REASON_LOAN)
	return amount


## Token-gated recovery. Debits recovery_token_cost from the ledger, clears arrears and suspends upkeep for a few days.
## Grants NO cash. The ledger is the only token source; this class has no purchase code.
func recover_with_tokens(ledger: MHTokenLedger) -> int:
	if not bankrupt:
		return ERR_NOT_AVAILABLE
	if ledger == null or not ledger.can_spend(params.c("recovery_token_cost")):
		return ERR_INSUFFICIENT
	if not ledger.spend(params.c("recovery_token_cost")):
		return ERR_INSUFFICIENT
	return apply_token_recovery()


## The effect only. Call after the caller has debited the tokens (recover_with_tokens does both).
func apply_token_recovery() -> int:
	if not bankrupt:
		return ERR_NOT_AVAILABLE
	arrears = 0
	holiday_hours = params.c("recovery_holiday_days") * HOURS_PER_DAY
	_update_bankrupt()
	return OK


## Informational mirror of the clock's token rate (7.5 tokens per sped-up game day).
func speed_tokens_for_days(game_days: int) -> int:
	return MHEconomyModel.speed_tokens_for_days(game_days)


func can_afford_speed(ledger: MHTokenLedger, game_days: int) -> bool:
	if ledger == null:
		return false
	return ledger.can_spend(MHEconomyModel.speed_tokens_for_days(game_days))


# ------------------------------------------------------------------ save
func to_dict() -> Dictionary:
	var tl: Array = []
	for t: int in tiers:
		tl.append(t)
	return {
		"v": SAVE_VERSION, "cash": cash, "fee": fee, "day": day, "hour": hour, "arrears": arrears,
		"loan_balance": loan_balance, "loans_taken": loans_taken, "reputation": reputation,
		"holiday_hours": holiday_hours, "bankrupt": 1 if bankrupt else 0, "carry_milli": carry_milli,
		"last_daily_upkeep": last_daily_upkeep, "members_milli": members_milli, "holes": holes, "rating": rating,
		"parcels": parcels, "ext_permille": ext_permille, "tiers": tl, "total_revenue": total_revenue,
		"total_upkeep_paid": total_upkeep_paid,
	}


## Restores a state written by to_dict, or a golden "init" dictionary with any subset of the keys (missing keys keep
## their current value). Returns false and changes nothing when a value has the wrong type or is out of range.
func from_dict(d: Dictionary) -> bool:
	var vals: Dictionary = {}
	for k: Variant in _INT_KEYS:
		var key: String = str(k)
		if d.has(key):
			var iv: Variant = MHEconomyParams.int_or_null(d[key])
			if iv == null:
				return false
			vals[key] = int(iv)
	var new_tiers: PackedInt32Array = tiers.duplicate()
	if d.has("tiers"):
		if typeof(d["tiers"]) != TYPE_ARRAY:
			return false
		var arr: Array = d["tiers"]
		if arr.size() != MHEconomyParams.BUILDINGS:
			return false
		for b: int in range(MHEconomyParams.BUILDINGS):
			var tv: Variant = MHEconomyParams.int_or_null(arr[b])
			if tv == null or int(tv) < 0 or int(tv) > MHEconomyParams.TIERS:
				return false
			new_tiers[b] = int(tv)
	var new_bankrupt: bool = bankrupt
	if d.has("bankrupt"):
		var bv: Variant = MHEconomyParams.int_or_null(d["bankrupt"])
		if bv == null:
			return false
		new_bankrupt = int(bv) != 0
	if vals.has("hour") and (int(vals["hour"]) < 0 or int(vals["hour"]) >= HOURS_PER_DAY):
		return false
	if vals.has("holes") and (int(vals["holes"]) < 0 or int(vals["holes"]) > MHEconomyParams.MAX_HOLES):
		return false
	if vals.has("rating") and (int(vals["rating"]) < 0 or int(vals["rating"]) > 100):
		return false
	if vals.has("carry_milli") and (int(vals["carry_milli"]) < 0 or int(vals["carry_milli"]) > 999):
		return false
	if vals.has("members_milli") and int(vals["members_milli"]) < 0:
		return false
	if vals.has("arrears") and int(vals["arrears"]) < 0:
		return false
	if vals.has("fee") and int(vals["fee"]) < 0:
		return false
	for k: Variant in vals.keys():
		set(str(k), int(vals[k]))
	tiers = new_tiers
	bankrupt = new_bankrupt
	return true


## Flat list in the same order as the Python reference state_list(): used by the golden tests.
func state_list() -> PackedInt64Array:
	var out: PackedInt64Array = PackedInt64Array()
	out.append(cash)
	out.append(fee)
	out.append(day)
	out.append(hour)
	out.append(arrears)
	out.append(loan_balance)
	out.append(loans_taken)
	out.append(reputation)
	out.append(holiday_hours)
	out.append(1 if bankrupt else 0)
	out.append(carry_milli)
	out.append(last_daily_upkeep)
	out.append(members_milli)
	return out
