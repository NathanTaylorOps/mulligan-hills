"""Integer-only Python reference for game/core/economy/ (MHEconomyModel + MHEconomy).

Money is integer CENTS. No floats anywhere in this file. The GDScript mirrors every function 1:1.
Division: operands are non-negative wherever '//' is used, so floor == truncate (same as GDScript int /).
The player-behaviour simulation (sim.py) drives THIS code, so the numbers it reports are the numbers the game
core produces. Everything marked ASSUMPTION in economy_params.json must be re-tuned on closed-test data.
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
HOURS_PER_DAY = 11          # matches game/core/clock/mh_game_clock.gd (660 game minutes per day)
NB = 10                     # buildings
NT = 5                      # tiers

OK = 0
ERR_INSUFFICIENT = 1
ERR_INVALID = 2
ERR_BANKRUPT = 3
ERR_NOT_AVAILABLE = 4

OPT_LOAN = 1
OPT_TOKEN = 2


def clamp(v, lo, hi):
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v


def isqrt(n):
    if n <= 0:
        return 0
    x = 1 << ((n.bit_length() + 1) >> 1)
    while True:
        y = (x + n // x) >> 1
        if y >= x:
            return x
        x = y


# ---------------------------------------------------------------- params
def load_params(path=None):
    path = path or os.path.join(HERE, "economy_params.json")
    with open(path) as f:
        return json.load(f)


# ---------------------------------------------------------------- pure model
def wtp_cents(P, rating, holes):
    """Willingness to pay for one round. rating 0..100 (average hole score), holes counted up to 18."""
    c = P["core"]
    h = clamp(holes, 0, 18)
    r = clamp(rating, 0, 100)
    return h * (c["wtp_base_per_hole_cents"] + c["wtp_per_rating_per_hole_cents"] * r)


def acceptance_permille(fee_cents, wtp):
    """1000 / (1 + (fee/wtp)^2). 500 at fee == wtp. wtp <= 0 gives 0."""
    if wtp <= 0:
        return 0
    if fee_cents < 0:
        fee_cents = 0
    w2 = wtp * wtp
    return (w2 * 1000) // (w2 + fee_cents * fee_cents)


def attract_permille(rating):
    """1000 * (rating/50)^1.5, integer: isqrt(8 r^3). rating 50 -> 1000, 100 -> 2828."""
    r = clamp(rating, 0, 100)
    return isqrt(8 * r * r * r)


def effect_sum(P, tiers, key):
    """Sum of a per-tier effect over the ten buildings. tiers: list of 10 ints 0..5."""
    total = 0
    eff = P["effects"]
    ids = P["building_ids"]
    for i in range(NB):
        t = tiers[i]
        if t > 0:
            arr = eff[ids[i]].get(key)
            if arr:
                total += arr[t - 1]
    return total


def arrivals_milli(P, holes, rating, dem_add_milli, rep_permille, ext_permille):
    """Golfers who would like to play per day, times 1000, before the fee decision.
    dem_add_milli: extra golfers/day (x1000) contributed by buildings (additive, not a multiplier)."""
    c = P["core"]
    h = clamp(holes, 0, 18)
    att = attract_permille(rating)
    base = c["arrivals_base_milli"] + (c["arrivals_per_hole_milli"] * h * att) // 1000 + dem_add_milli
    base = (base * rep_permille) // 1000
    return (base * ext_permille) // 1000


def split_hour(daily, hour_index):
    """Exact split of a daily amount over HOURS_PER_DAY hours: the parts sum to daily."""
    if daily <= 0:
        return 0
    h = clamp(hour_index, 0, HOURS_PER_DAY - 1)
    return (daily * (h + 1)) // HOURS_PER_DAY - (daily * h) // HOURS_PER_DAY


def profile_sum(P):
    s = 0
    for v in P["hour_profile"]:
        s += v
    return s


def hour_cap_milli(P):
    c = P["core"]
    return c["tee_groups_per_hour"] * c["tee_group_size_x10"] * 100


def golfers_day_milli(P, arr_milli, acc_permille):
    """Expected accepted golfers per day x1000, honouring the per-hour tee cap."""
    ps = profile_sum(P)
    cap = hour_cap_milli(P)
    tot = 0
    for h in range(HOURS_PER_DAY):
        a = (arr_milli * P["hour_profile"][h]) // ps
        a = (a * acc_permille) // 1000
        tot += a if a < cap else cap
    return tot


def members_target_milli(P, clubhouse_tier, rating, rep_permille):
    if clubhouse_tier <= 0:
        return 0
    cap = P["member_cap"][clubhouse_tier - 1]
    num = rating - P["core"]["member_rating_floor"]
    if num < 0:
        num = 0
    f = clamp((num * 1000) // P["core"]["member_rating_span"], 0, 1300)
    return (cap * 1000 * f // 1000) * rep_permille // 1000


def step_members_milli(P, members_milli, target_milli):
    rate = P["core"]["member_join_rate_permille"]
    d = target_milli - members_milli
    if d >= 0:
        return members_milli + (d * rate) // 1000
    return members_milli - ((-d) * rate) // 1000


def course_upkeep_cents(P, holes, parcels, maint_cut_permille):
    c = P["core"]
    u = holes * c["hole_upkeep_cents"] + parcels * c["parcel_upkeep_cents"]
    cut = clamp(maint_cut_permille, 0, 900)
    return (u * (1000 - cut)) // 1000


def building_upkeep_cents(upkeep_dollars, tiers):
    """upkeep_dollars[i][t-1] from buildings.json upkeep_per_day (whole dollars, total for the standing tier)."""
    u = 0
    for i in range(NB):
        t = tiers[i]
        if t > 0:
            u += upkeep_dollars[i][t - 1] * 100
    return u


def day_estimate(P, upkeep_dollars, tiers, holes, parcels, rating, members_milli, fee, rep=1000, ext=1000, renovation=0):
    """Expected one-day figures, integer cents. Used for pricing, fee suggestion and bot decisions."""
    dem = effect_sum(P, tiers, "dem") + renovation_dem_milli(P, renovation)
    anc = effect_sum(P, tiers, "anc")
    arr = arrivals_milli(P, holes, rating, dem, rep, ext)
    acc = acceptance_permille(fee, wtp_cents(P, rating, holes))
    g = golfers_day_milli(P, arr, acc)
    flat = (effect_sum(P, tiers, "flat") * clamp(rating, 0, 100)) // 50
    dues = (members_milli * P["core"]["member_dues_cents"]) // 1000
    fees = (g * fee) // 1000
    ancr = (g * anc) // 1000
    cut = effect_sum(P, tiers, "cut")
    up_course = course_upkeep_cents(P, holes, parcels, cut)
    up_bld = building_upkeep_cents(upkeep_dollars, tiers) + renovation_upkeep_cents(P, renovation)
    return {"arrivals_milli": arr, "acc": acc, "golfers_milli": g, "fees": fees, "anc": ancr, "flat": flat,
            "dues": dues, "revenue": fees + ancr + flat + dues, "upkeep_course": up_course,
            "upkeep_buildings": up_bld, "upkeep": up_course + up_bld,
            "net": fees + ancr + flat + dues - up_course - up_bld}


def suggest_fee_cents(P, upkeep_dollars, tiers, holes, rating, rep=1000, renovation=0):
    """Fee that maximises fees + ancillary per day (first maximum, so ties go to the lower fee)."""
    c = P["core"]
    dem = effect_sum(P, tiers, "dem") + renovation_dem_milli(P, renovation)
    anc = effect_sum(P, tiers, "anc")
    arr = arrivals_milli(P, holes, rating, dem, rep, 1000)
    w = wtp_cents(P, rating, holes)
    best = -1
    bf = c["fee_min_cents"]
    f = c["fee_min_cents"]
    while f <= c["fee_max_cents"]:
        g = golfers_day_milli(P, arr, acceptance_permille(f, w))
        v = g * (f + anc)
        if v > best:
            best = v
            bf = f
        f += 100
    return bf


def payback_price_cents(target_days, added_daily_cents):
    """DEC-050: price = target payback days x added daily income."""
    if target_days <= 0 or added_daily_cents <= 0:
        return 0
    return target_days * added_daily_cents


def parcel_cost_cents(base_dollars, growth_pct, purchases_made):
    """Mirrors MHLandModel.price_for_purchase_index (whole dollars, integer growth each step), then x100."""
    p = base_dollars
    for _ in range(max(purchases_made, 0)):
        p = (p * growth_pct) // 100
    return p * 100


def hole_cost_cents(P, holes_built):
    """Build cost of the next hole when holes_built holes exist (ASSUMPTION: geometric, whole dollars)."""
    c = P["core"]
    d = c["hole_cost_base_dollars"]
    for _ in range(max(holes_built - c["start_holes"], 0)):
        d = (d * c["hole_cost_growth_permille"]) // 1000
    return d * 100


def renovation_cost_cents(P, level):
    """Cost of buying renovation level+1 when `level` renovations are done (late-game cash sink, geometric, whole
    dollars). Returns 0 when the maximum level is reached."""
    c = P["core"]
    if level < 0 or level >= c["renov_max_levels"]:
        return 0
    d = c["renov_base_dollars"]
    for _ in range(level):
        d = (d * c["renov_growth_permille"]) // 1000
    return d * 100


def renovation_dem_milli(P, level):
    """Extra golfers per day x1000 that `level` renovations add (additive, like building demand)."""
    return clamp(level, 0, P["core"]["renov_max_levels"]) * P["core"]["renov_dem_milli_per_level"]


def renovation_upkeep_cents(P, level):
    """Extra upkeep per day that `level` renovations add (not reduced by Maintenance)."""
    return clamp(level, 0, P["core"]["renov_max_levels"]) * P["core"]["renov_upkeep_cents_per_level"]


def speed_tokens_for_days(game_days):
    """Tokens a sped-up stretch costs under the clock's own rates (game/core/clock/mh_game_clock.gd): 2x, 4x and 8x
    drain 1, 2 and 4 tokens per real minute while a game day lasts 7.5, 3.75 and 1.875 real minutes, so every sped-up
    game day costs 7.5 tokens at any speed. Returns ceil(7.5 * days) = (15 * days + 1) // 2."""
    if game_days <= 0:
        return 0
    return (15 * game_days + 1) // 2


# ---------------------------------------------------------------- state machine
class Economy:
    def __init__(self, P, upkeep_dollars, start_cash_cents=-1):
        self.P = P
        self.c = P["core"]
        self.upk = upkeep_dollars
        self.cash = self.c["start_cash_cents"] if start_cash_cents < 0 else start_cash_cents
        self.fee = self.c["fee_start_cents"]
        self.day = 0
        self.hour = 0
        self.arrears = 0
        self.loan_balance = 0
        self.loans_taken = 0
        self.reputation = 1000
        self.holiday_hours = 0
        self.bankrupt = False
        self.carry_milli = 0
        self.last_daily_upkeep = 0
        self.members_milli = 0
        self.holes = self.c["start_holes"]
        self.rating = self.c["start_rating"]
        self.parcels = self.c["start_parcels"]
        self.tiers = [0] * NB
        self.renovation = 0
        self.ext_permille = 1000
        self.total_revenue = 0
        self.total_upkeep_paid = 0
        self.tokens_spent_on_recovery = 0

    # cash
    def can_afford(self, cost):
        return cost >= 0 and self.cash >= cost and not self.bankrupt

    def spend(self, cost):
        if cost < 0:
            return ERR_INVALID
        if self.bankrupt:
            return ERR_BANKRUPT
        if self.cash < cost:
            return ERR_INSUFFICIENT
        self.cash -= cost
        return OK

    def earn(self, amount):
        if amount < 0:
            return ERR_INVALID
        self.cash += amount
        return OK

    def incur_loss(self, amount):
        if amount < 0:
            return ERR_INVALID
        paid = min(self.cash, amount)
        self.cash -= paid
        self.arrears += amount - paid
        self._update_bankrupt()
        return OK

    def set_green_fee(self, fee_cents):
        self.fee = clamp(fee_cents, self.c["fee_min_cents"], self.c["fee_max_cents"])
        return self.fee

    def members(self):
        return self.members_milli // 1000

    def daily_upkeep(self):
        cut = effect_sum(self.P, self.tiers, "cut")
        return (course_upkeep_cents(self.P, self.holes, self.parcels, cut) + building_upkeep_cents(self.upk, self.tiers)
                + renovation_upkeep_cents(self.P, self.renovation))

    # renovation (late-game sink): needs a full 18-hole course and every building at tier renov_min_tier (5) or higher,
    # so a player who is stuck below tier 5 on the rating gate still has something to spend cash on
    def renovation_available(self):
        if self.holes < 18:
            return False
        for t in self.tiers:
            if t < self.c["renov_min_tier"]:
                return False
        return self.renovation < self.c["renov_max_levels"]

    def renovation_cost(self):
        return renovation_cost_cents(self.P, self.renovation)

    def purchase_renovation(self):
        if not self.renovation_available():
            return ERR_NOT_AVAILABLE
        r = self.spend(self.renovation_cost())
        if r != OK:
            return r
        self.renovation += 1
        return OK

    # one game hour
    def tick_hour(self):
        P = self.P
        h = self.hour
        dem = effect_sum(P, self.tiers, "dem") + renovation_dem_milli(P, self.renovation)
        anc = effect_sum(P, self.tiers, "anc")
        arr = arrivals_milli(P, self.holes, self.rating, dem, self.reputation, self.ext_permille)
        acc = acceptance_permille(self.fee, wtp_cents(P, self.rating, self.holes))
        a = (arr * P["hour_profile"][h]) // profile_sum(P)
        a = (a * acc) // 1000
        cap = hour_cap_milli(P)
        if a > cap:
            a = cap
        a += self.carry_milli
        golfers = a // 1000
        self.carry_milli = a - golfers * 1000
        fees = golfers * self.fee
        ancr = golfers * anc
        flat_day = (effect_sum(P, self.tiers, "flat") * clamp(self.rating, 0, 100)) // 50
        dues_day = (self.members_milli * self.c["member_dues_cents"]) // 1000
        flat = split_hour(flat_day + dues_day, h)
        revenue = fees + ancr + flat
        self.cash += revenue
        self.total_revenue += revenue
        repaid = 0
        if self.loan_balance > 0 and revenue > 0:
            repaid = min(self.loan_balance, (revenue * self.c["loan_repay_share_permille"]) // 1000, self.cash)
            self.loan_balance -= repaid
            self.cash -= repaid
        self.last_daily_upkeep = self.daily_upkeep()
        due_now = 0
        if self.holiday_hours > 0:
            self.holiday_hours -= 1
        else:
            due_now = split_hour(self.last_daily_upkeep, h)
        owed = self.arrears + due_now
        paid = min(self.cash, owed)
        self.cash -= paid
        self.arrears = owed - paid
        self.total_upkeep_paid += paid
        self._update_bankrupt()
        self.hour += 1
        rolled = False
        if self.hour >= HOURS_PER_DAY:
            self.hour = 0
            self.day += 1
            rolled = True
            self.reputation = min(1000, self.reputation + self.c["rep_recover_per_day_permille"])
            tgt = members_target_milli(P, self.tiers[0], self.rating, self.reputation)
            self.members_milli = step_members_milli(P, self.members_milli, tgt)
        return {"golfers": golfers, "fees": fees, "ancillary": ancr, "flat": flat, "revenue": revenue,
                "repaid": repaid, "upkeep_due": due_now, "upkeep_paid": paid, "arrears": self.arrears,
                "cash": self.cash, "bankrupt": self.bankrupt, "day_rolled": rolled}

    def _update_bankrupt(self):
        if self.arrears == 0:
            self.bankrupt = False
            return
        if self.bankrupt:
            return
        if self.arrears < self.c["bankrupt_min_arrears_cents"]:
            return
        d = self.last_daily_upkeep
        if d <= 0:
            return
        if self.arrears * 10 >= self.c["bankrupt_arrears_days_x10"] * d:
            self.bankrupt = True

    # recovery
    def recovery_options(self, tokens_available):
        if not self.bankrupt:
            return 0
        o = 0
        if self.loans_taken < self.c["loan_max_taken"]:
            o |= OPT_LOAN
        if tokens_available >= self.c["recovery_token_cost"]:
            o |= OPT_TOKEN
        return o

    def loan_amount_cents(self):
        a = self.c["loan_upkeep_days"] * self.last_daily_upkeep + self.arrears
        return clamp(a, self.c["loan_min_cents"], self.c["loan_max_cents"])

    def take_bank_loan(self):
        """Free loan: no interest, no fee unless loan_fee_permille > 0. Repaid from a share of revenue.
        Costs reputation. Returns the amount, or a negative error."""
        if not self.bankrupt:
            return -ERR_NOT_AVAILABLE
        if self.loans_taken >= self.c["loan_max_taken"]:
            return -ERR_NOT_AVAILABLE
        amount = self.loan_amount_cents()
        self.cash += amount
        self.loan_balance += amount + (amount * self.c["loan_fee_permille"]) // 1000
        self.loans_taken += 1
        self.reputation = max(self.c["rep_floor_permille"], self.reputation - self.c["loan_rep_penalty_permille"])
        paid = min(self.cash, self.arrears)
        self.cash -= paid
        self.arrears -= paid
        self._update_bankrupt()
        return amount

    def apply_token_recovery(self):
        """Call only after the caller has debited recovery_token_cost tokens from the ledger. Grants NO cash:
        clears arrears and suspends upkeep for a few days."""
        if not self.bankrupt:
            return ERR_NOT_AVAILABLE
        self.arrears = 0
        self.holiday_hours = self.c["recovery_holiday_days"] * HOURS_PER_DAY
        self.tokens_spent_on_recovery += self.c["recovery_token_cost"]
        self._update_bankrupt()
        return OK

    def to_dict(self):
        return {"cash": self.cash, "fee": self.fee, "day": self.day, "hour": self.hour, "arrears": self.arrears,
                "loan_balance": self.loan_balance, "loans_taken": self.loans_taken, "reputation": self.reputation,
                "holiday_hours": self.holiday_hours, "bankrupt": 1 if self.bankrupt else 0,
                "carry_milli": self.carry_milli, "last_daily_upkeep": self.last_daily_upkeep,
                "members_milli": self.members_milli, "holes": self.holes, "rating": self.rating,
                "parcels": self.parcels, "ext_permille": self.ext_permille, "renovation": self.renovation,
                "tiers": list(self.tiers), "total_revenue": self.total_revenue, "total_upkeep_paid": self.total_upkeep_paid}

    def from_dict(self, d):
        for k in ("cash", "fee", "day", "hour", "arrears", "loan_balance", "loans_taken", "reputation",
                  "holiday_hours", "carry_milli", "last_daily_upkeep", "members_milli", "holes", "rating",
                  "parcels", "ext_permille", "renovation", "total_revenue", "total_upkeep_paid"):
            if k in d:
                setattr(self, k, d[k])
        if "bankrupt" in d:
            self.bankrupt = d["bankrupt"] != 0
        if "tiers" in d:
            self.tiers = list(d["tiers"])

    def state_list(self):
        return [self.cash, self.fee, self.day, self.hour, self.arrears, self.loan_balance, self.loans_taken,
                self.reputation, self.holiday_hours, 1 if self.bankrupt else 0, self.carry_milli,
                self.last_daily_upkeep, self.members_milli]
