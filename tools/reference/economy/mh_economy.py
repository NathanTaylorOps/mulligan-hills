"""Integer-only Python reference for game/core/economy/mh_economy.gd (MHEconomy).
Money is integer CENTS. No floats anywhere in this file. GDScript mirrors every function 1:1.
Division: all operands are non-negative wherever '//' is used, so floor == truncate (same as GDScript int /)."""

HOURS_PER_DAY = 12

OK = 0
ERR_INSUFFICIENT = 1
ERR_INVALID = 2
ERR_BANKRUPT = 3
ERR_NOT_AVAILABLE = 4

OPT_LOAN = 1
OPT_TOKEN = 2

# Core defaults (cents unless named otherwise). economy_params.json "core" section must equal this.
CORE_DEFAULTS = {
    "start_cash_cents": 4000000,
    "fee_min_cents": 500,
    "fee_max_cents": 25000,
    "fee_start_cents": 1500,
    "wtp_base_per_hole_cents": 40,
    "wtp_per_rating_per_hole_cents": 12,
    "upkeep_ppm_per_day": 2500,
    "parcel_base_cents": 3000000,
    "parcel_growth_permille": 1200,
    "parcel_round_cents": 10000,
    "bankrupt_arrears_days_x10": 20,
    "bankrupt_min_arrears_cents": 100000,
    "loan_upkeep_days": 10,
    "loan_min_cents": 500000,
    "loan_max_cents": 5000000,
    "loan_fee_permille": 100,
    "loan_repay_share_permille": 250,
    "loan_max_taken": 3,
    "loan_rep_penalty_permille": 150,
    "rep_floor_permille": 500,
    "rep_recover_per_day_permille": 3,
    "tokens_earn_every_days": 6,
    "speed_cost_2x_per_10_days": 1,
    "speed_cost_4x_per_10_days": 3,
    "speed_cost_8x_per_10_days": 8,
    "recovery_token_cost": 3,
    "recovery_holiday_days": 5,
}


def clamp(v, lo, hi):
    if v < lo:
        return lo
    if v > hi:
        return hi
    return v


def wtp_cents(p, rating, holes):
    """Willingness to pay for one round, cents. rating 0..100, holes counted up to 18."""
    h = clamp(holes, 0, 18)
    r = clamp(rating, 0, 100)
    return h * (p["wtp_base_per_hole_cents"] + p["wtp_per_rating_per_hole_cents"] * r)


def fee_acceptance_permille(fee_cents, wtp):
    """1000 / (1 + (fee/wtp)^2), integer. 500 at fee == wtp. wtp <= 0 -> 0."""
    if wtp <= 0:
        return 0
    if fee_cents < 0:
        fee_cents = 0
    w2 = wtp * wtp
    return (w2 * 1000) // (w2 + fee_cents * fee_cents)


def payback_price_cents(target_days, added_daily_income_cents, upkeep_ppm):
    """DEC-050. cost = target_days * (added_income - cost*upkeep_ppm/1e6) solved for cost:
    cost = T*G*1e6 / (1e6 + T*u). With upkeep_ppm == 0 this is the plain rule T*G."""
    if target_days <= 0 or added_daily_income_cents <= 0:
        return 0
    return (target_days * added_daily_income_cents * 1000000) // (1000000 + target_days * upkeep_ppm)


def payback_days_x100(cost_cents, added_daily_income_cents, upkeep_ppm):
    net = added_daily_income_cents - (cost_cents * upkeep_ppm) // 1000000
    if net <= 0:
        return -1
    return (cost_cents * 100) // net


def upkeep_hour_cents(daily_cents, hour_index):
    """Exact split of a daily amount over 12 hours: the 12 parts sum to daily_cents."""
    if daily_cents <= 0:
        return 0
    h = clamp(hour_index, 0, HOURS_PER_DAY - 1)
    return (daily_cents * (h + 1)) // HOURS_PER_DAY - (daily_cents * h) // HOURS_PER_DAY


def parcel_cost_cents(p, parcels_bought):
    """Cost of the next parcel when parcels_bought have been bought so far (start plot not counted)."""
    c = p["parcel_base_cents"]
    k = 0
    while k < parcels_bought:
        c = (c * p["parcel_growth_permille"]) // 1000
        k += 1
    rnd = p["parcel_round_cents"]
    if rnd > 1:
        c = (c // rnd) * rnd
    return c


def speed_token_cost(p, multiplier, game_days):
    if multiplier <= 1 or game_days <= 0:
        return 0
    if multiplier <= 2:
        rate = p["speed_cost_2x_per_10_days"]
    elif multiplier <= 4:
        rate = p["speed_cost_4x_per_10_days"]
    else:
        rate = p["speed_cost_8x_per_10_days"]
    return (game_days * rate + 9) // 10


class Economy:
    def __init__(self, params=None, start_cash_cents=-1):
        self.p = dict(CORE_DEFAULTS if params is None else params)
        self.cash = self.p["start_cash_cents"] if start_cash_cents < 0 else start_cash_cents
        self.fee = self.p["fee_start_cents"]
        self.day = 0
        self.hour = 0
        self.arrears = 0
        self.loan_balance = 0
        self.loans_taken = 0
        self.reputation = 1000
        self.tokens = 0
        self.holiday_hours = 0
        self.bankrupt = False
        self.accept_carry = 0
        self.last_daily_upkeep = 0
        self.total_revenue = 0
        self.total_upkeep_paid = 0

    # ---- cash
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

    # ---- fee
    def set_green_fee(self, fee_cents):
        self.fee = clamp(fee_cents, self.p["fee_min_cents"], self.p["fee_max_cents"])
        return self.fee

    def demand_multiplier_permille(self):
        return self.reputation

    def accept_arrivals(self, arriving, wtp):
        """Deterministic rounding with a carried remainder (no RNG)."""
        if arriving <= 0:
            return 0
        acc = fee_acceptance_permille(self.fee, wtp)
        total = arriving * acc + self.accept_carry
        n = total // 1000
        self.accept_carry = total - n * 1000
        return n

    # ---- hourly tick
    def tick_hour(self, golfers_played, ancillary_cents, flat_income_daily_cents, upkeep_daily_cents):
        """Returns dict: fees, ancillary, flat, revenue, repaid, upkeep_due, upkeep_paid, arrears, cash, bankrupt, day_rolled"""
        h = self.hour
        fees = max(golfers_played, 0) * self.fee
        anc = max(ancillary_cents, 0)
        flat = upkeep_hour_cents(flat_income_daily_cents, h)
        revenue = fees + anc + flat
        self.cash += revenue
        self.total_revenue += revenue
        repaid = 0
        if self.loan_balance > 0 and revenue > 0:
            repaid = min(self.loan_balance, (revenue * self.p["loan_repay_share_permille"]) // 1000, self.cash)
            self.loan_balance -= repaid
            self.cash -= repaid
        self.last_daily_upkeep = max(upkeep_daily_cents, 0)
        due_now = 0
        if self.holiday_hours > 0:
            self.holiday_hours -= 1
        else:
            due_now = upkeep_hour_cents(self.last_daily_upkeep, h)
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
            self.reputation = min(1000, self.reputation + self.p["rep_recover_per_day_permille"])
            every = self.p["tokens_earn_every_days"]
            if every > 0 and self.day % every == 0:
                self.tokens += 1
        return {"fees": fees, "ancillary": anc, "flat": flat, "revenue": revenue, "repaid": repaid,
                "upkeep_due": due_now, "upkeep_paid": paid, "arrears": self.arrears, "cash": self.cash,
                "bankrupt": self.bankrupt, "day_rolled": rolled}

    def _update_bankrupt(self):
        if self.arrears == 0:
            self.bankrupt = False
            return
        if self.bankrupt:
            return
        if self.arrears < self.p["bankrupt_min_arrears_cents"]:
            return
        d = self.last_daily_upkeep
        if d <= 0:
            return
        # arrears >= days * daily_upkeep, days given in tenths
        if self.arrears * 10 >= self.p["bankrupt_arrears_days_x10"] * d:
            self.bankrupt = True

    # ---- bankruptcy recovery
    def recovery_options(self):
        if not self.bankrupt:
            return 0
        o = 0
        if self.loans_taken < self.p["loan_max_taken"]:
            o |= OPT_LOAN
        if self.tokens >= self.p["recovery_token_cost"]:
            o |= OPT_TOKEN
        return o

    def loan_amount_cents(self):
        a = self.p["loan_upkeep_days"] * self.last_daily_upkeep + self.arrears
        return clamp(a, self.p["loan_min_cents"], self.p["loan_max_cents"])

    def take_bank_loan(self):
        """Free loan (no interest, a flat fee repaid from income) plus a reputation penalty."""
        if not (self.recovery_options() & OPT_LOAN):
            return -ERR_NOT_AVAILABLE
        amount = self.loan_amount_cents()
        self.cash += amount
        self.loan_balance += amount + (amount * self.p["loan_fee_permille"]) // 1000
        self.loans_taken += 1
        self.reputation = max(self.p["rep_floor_permille"], self.reputation - self.p["loan_rep_penalty_permille"])
        paid = min(self.cash, self.arrears)
        self.cash -= paid
        self.arrears -= paid
        self._update_bankrupt()
        return amount

    def use_token_recovery(self):
        """Token-gated recovery: clears arrears and suspends upkeep for a few days. Grants NO cash."""
        if not (self.recovery_options() & OPT_TOKEN):
            return ERR_NOT_AVAILABLE
        self.tokens -= self.p["recovery_token_cost"]
        self.arrears = 0
        self.holiday_hours = self.p["recovery_holiday_days"] * HOURS_PER_DAY
        self._update_bankrupt()
        return OK

    # ---- tokens (logic only, no purchase path)
    def add_tokens(self, n):
        if n <= 0:
            return ERR_INVALID
        self.tokens += n
        return OK

    def can_use_speed(self, multiplier, game_days):
        return self.tokens >= speed_token_cost(self.p, multiplier, game_days)

    def use_speed(self, multiplier, game_days):
        c = speed_token_cost(self.p, multiplier, game_days)
        if self.tokens < c:
            return ERR_INSUFFICIENT
        self.tokens -= c
        return OK

    def state_list(self):
        return [self.cash, self.fee, self.day, self.hour, self.arrears, self.loan_balance, self.loans_taken,
                self.reputation, self.tokens, self.holiday_hours, 1 if self.bankrupt else 0,
                self.accept_carry, self.last_daily_upkeep]
