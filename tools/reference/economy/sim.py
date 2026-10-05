"""Mulligan Hills economy simulation. Python 3 standard library only.

The accounting and demand model is mh_economy.py (integer cents, mirrored 1:1 in game/core/economy/). Only the
PLAYER BEHAVIOUR here is float/random and is a model: skill growth, fee habits, purchase style. Every constant in
economy_params.json is an ASSUMPTION to be re-tuned against closed-test data.

Usage (from this folder):
    python3 sim.py report [runs_per_cell]    # balance report for the current economy_params.json
    python3 sim.py write                     # derive added-income + price tables, write economy_params.json
    python3 sim.py demo                      # demo-cut analysis
"""
import copy
import json
import os
import random
import sys

import mh_economy as E
import make_params

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BUILD = json.load(open(os.path.join(ROOT, "docs", "spec", "data", "buildings.json")))
BIDS = [b["id"] for b in BUILD["buildings"]]
NB = len(BIDS)
UPK = [[t["upkeep_per_day"] for t in b["tiers"]] for b in BUILD["buildings"]]          # whole dollars
REQ = [[t["requires"] for t in b["tiers"]] for b in BUILD["buildings"]]
TARGETS_FILE = [[t["target_payback_days"] for t in b["tiers"]] for b in BUILD["buildings"]]
HEAVY = [b["land_class"] == "heavy" for b in BUILD["buildings"]]
DEMO_TIER = [b["demo_max_tier"] for b in BUILD["buildings"]]
LAND = BUILD["land"]
LEVEL_RANK = {"local": 1, "regional": 2, "national": 3, "major": 4}
IDX = {b: i for i, b in enumerate(BIDS)}
TOURN = json.load(open(os.path.join(ROOT, "docs", "spec", "data", "tournaments.json")))
TLEVELS = {L["level"]: L for L in TOURN["levels"]}
TCAP = TOURN["spectator_capacity_by_clubhouse_tier"]
# Real play time per game day under the assumed speed mix (DEC-066): 60% of days at 1x (15 min), 25% at 2x (7.5 min),
# 15% at 4x (3.75 min) = 12.125 min per game day on average. This is a sensitivity, NOT a token-funded prediction.
MIN_PER_DAY_X100 = 1213


def tournament_revenue_dollars(level, clubhouse_tier):
    """Mirror of MHTournamentSim.evaluate revenue on success (whole dollars): sponsor reward + entry fees + tickets."""
    L = TLEVELS[level]
    rv = L["revenue"]
    cap = TCAP[max(0, min(clubhouse_tier, 5) - 1)] if clubhouse_tier > 0 else 0
    entry = rv["entry_fee"] * L["field_size"]
    tickets = (rv["ticket_price"] * cap * rv["attendance_pct"] // 100) * L["duration_days"]
    return L["reward"]["cash"] + entry + tickets


def tournament_eligible(level, e):
    """Entry checklist from tournaments.json (holes, average score, building tiers, spectators). Pace and staff are not
    modelled by the economy (no source yet), so the bot assumes they are met."""
    en = TLEVELS[level]["entry"]
    if e.holes < en["min_holes"] or e.rating < en["min_avg_hole_score"]:
        return False
    for b in en["buildings"]:
        if e.tiers[IDX[b["building"]]] < b["min_tier"]:
            return False
    ch = e.tiers[0]
    cap = TCAP[ch - 1] if ch > 0 else 0
    return cap >= en["min_spectator_capacity"]


def load():
    return E.load_params(os.path.join(HERE, "economy_params.json"))


# ---------------------------------------------------------------- pricing tables
def parcels_for_ref(tier):
    return [5, 8, 11, 14, 15][tier - 1]


def added_table(P):
    """Net added daily income (whole dollars) per building and tier at the reference state of that tier:
    holes and rating at the tier's gate, every building at (tier - 1), best fee, members at their target.
    Net = revenue gained minus the tier's own incremental upkeep, plus any course-upkeep cut."""
    out = []
    for i in range(NB):
        row = []
        for t in range(1, 6):
            tiers0 = [t - 1] * NB
            tiers1 = list(tiers0)
            tiers1[i] = t
            holes = P["ref_holes"][t - 1]
            rating = P["ref_rating"][t - 1]
            par = parcels_for_ref(t)
            m0 = E.members_target_milli(P, tiers0[0], rating, 1000)
            m1 = E.members_target_milli(P, tiers1[0], rating, 1000)
            fee = E.suggest_fee_cents(P, UPK, tiers1, holes, rating)
            a = E.day_estimate(P, UPK, tiers1, holes, par, rating, m1, fee)
            b = E.day_estimate(P, UPK, tiers0, holes, par, rating, m0, fee)
            row.append((a["net"] - b["net"]) // 100)
        out.append(row)
    return out


def price_table(P, added):
    floor = P.get("added_floor_dollars", 20)
    price = []
    for i in range(NB):
        price.append([P["payback_targets_days"][t] * max(added[i][t], floor) for t in range(5)])
    return price


UPPER = {"dem": 400000, "anc": 200000, "flat": 8000000, "cut": 600}


def net_added_cents(P, i, t):
    tiers0 = [t - 1] * NB
    tiers1 = list(tiers0)
    tiers1[i] = t
    holes = P["ref_holes"][t - 1]
    rating = P["ref_rating"][t - 1]
    par = parcels_for_ref(t)
    m0 = E.members_target_milli(P, tiers0[0], rating, 1000)
    m1 = E.members_target_milli(P, tiers1[0], rating, 1000)
    fee = E.suggest_fee_cents(P, UPK, tiers1, holes, rating)
    a = E.day_estimate(P, UPK, tiers1, holes, par, rating, m1, fee)
    b = E.day_estimate(P, UPK, tiers0, holes, par, rating, m0, fee)
    return a["net"] - b["net"]


def calibrate(P):
    """Fill P['effects'] so each building tier adds about weight-share x tier total of net daily income at its
    reference state. Effects are the integer RESULT; the targets are the design intent (calibration block)."""
    cal = P["calibration"]
    S = cal["tier_total_net_dollars"]
    W = cal["weights"]
    wt = sum(W[b] for b in BIDS)
    eff = {b: {} for b in BIDS}
    P["effects"] = eff
    for b in BIDS:
        keys = set(k for k, _ in cal["channels"][b])
        if b == "landmark":
            keys.add("flat")
        for k in keys:
            eff[b][k] = [0] * 5
    for t in range(1, 6):
        for i, b in enumerate(BIDS):
            n = S[t - 1] * W[b] * 100 // wt
            chans = cal["channels"][b]
            if b == "landmark" and t >= cal["landmark_flat_from_tier"]:
                chans = [["dem", 60], ["flat", 40]]
            cum = 0
            for key, share in chans:
                cum += share
                target = n * cum // 100
                prev = eff[b][key][t - 2] if t >= 2 else 0
                lo, hi = prev, UPPER[key]
                eff[b][key][t - 1] = hi
                if net_added_cents(P, i, t) < target:
                    continue
                while lo < hi:
                    mid = (lo + hi) // 2
                    eff[b][key][t - 1] = mid
                    if net_added_cents(P, i, t) >= target:
                        hi = mid
                    else:
                        lo = mid + 1
                eff[b][key][t - 1] = lo
            for key in eff[b]:
                if key not in [k for k, _ in chans]:
                    eff[b][key][t - 1] = eff[b][key][t - 2] if t >= 2 else 0
    return P


def derive(P):
    P = copy.deepcopy(P)
    calibrate(P)
    added = added_table(P)
    P["added_floor_dollars"] = P.get("added_floor_dollars", 20)
    P["added_daily_income_dollars"] = {BIDS[i]: [max(a, P["added_floor_dollars"]) for a in added[i]] for i in range(NB)}
    P["price_dollars"] = {BIDS[i]: price_table(P, added)[i] for i in range(NB)}
    P["_added_raw_dollars"] = {BIDS[i]: added[i] for i in range(NB)}
    return P


# ---------------------------------------------------------------- bot
ARCH = {
    # name: (reserve_days, style, fee_policy)
    "casual":   (3, "roi", "slow"),
    "careful":  (8, "roi", "opt"),
    "sticky":   (3, "roi", "fixed"),
    "greedy":   (0, "big", "slow"),
    "gouger":   (3, "roi", "max"),
    "cheap":    (3, "roi", "min"),
}
# Skill profiles. ASSUMPTION (invented, no player data): rating (average hole score) moves from the start rating toward a
# personal ceiling, closing half the gap every `half-life` game days (uniform in the range given). Ceilings carry +-3 noise.
# T5 needs rating 62 (DEC-048), so a profile whose ceiling is under about 62 can never finish; "casual-but-competent" =
# every profile except novice.
PROFILES = {
    #            ceiling, half-life range (game days), population weight
    "novice":    (58, (30, 50), 0.15),
    "casual":    (68, (24, 42), 0.45),
    "competent": (76, (18, 32), 0.30),
    "expert":    (84, (12, 24), 0.10),
}
SKILL = {k: v[0] for k, v in PROFILES.items()}
SKILL_W = {k: v[2] for k, v in PROFILES.items()}


HABIT_W = {"casual": 0.35, "careful": 0.20, "sticky": 0.20, "greedy": 0.20, "cheap": 0.05}
SNAP_DAYS = (10, 30, 60, 100, 150, 240, 400, 720)


class Run:
    def __init__(self, P, seed, arch, skill_name, days, demo=False, tokens=12, shock=None, start_cash=None):
        self.P = P
        self.c = P["core"]
        self.rnd = random.Random(seed)
        self.arch = arch
        self.skill_cap = SKILL[skill_name] + self.rnd.uniform(-3, 3)
        lo, hi = PROFILES[skill_name][1]
        self.half_life = self.rnd.uniform(lo, hi)   # game days to close half of the gap to the skill cap
        self.days = days
        self.demo = demo
        self.eco = E.Economy(P, UPK, -1 if start_cash is None else start_cash)
        self.shock = shock                      # (start_day, length_days, ext_permille) demand shock, or None
        self.fee_reset = False
        self.nbuys = 0
        self.gp, self.fp, self.hp = 4, 1, 0
        self.tourn_rank = 0                     # highest level hosted (1 local .. 4 major)
        self.tourn_active = None                # (level, resolve_day, revenue_cents)
        self.tourn_cd = 0                       # first day a new event may start
        self.sink_spend = 0                     # cents spent on renovations and net cost of optional tournaments
        self.tourn_count = 0
        self.tokens = tokens
        self.price = P["price_dollars"]
        self.res = {"first_any": {}, "all": {}, "first_stall": None, "bankrupt_events": 0, "loans": 0,
                    "token_rec": 0, "quit": False, "cash_blocked": 0, "gate_blocked": 0, "pile_days": 0,
                    "snap": {}, "h18": None, "m50": None, "demo_wall": None, "t5_full": None}

    # -- land
    def parcels_total(self):
        return self.gp + self.fp + self.hp

    def parcel_cost(self):
        made = self.parcels_total() - self.c["start_parcels"]
        return E.parcel_cost_cents(LAND["parcel_base_cost"], LAND["parcel_growth_pct"], made)

    def hole_cap(self):
        return min(self.gp * 3 // 2, 18, 9 if self.demo else 18)

    def next_hole_bundle(self):
        e = self.eco
        if e.holes >= (9 if self.demo else 18):
            return None
        cost = E.hole_cost_cents(self.P, e.holes)
        add = ("hole",)
        buy = []
        if e.holes + 1 > self.hole_cap():
            if self.gp >= 12:
                return None
            buy = ["g"]
        return cost, buy, add

    def parcel_bundle(self, b, tier):
        """Parcels to buy so the upgrade's land rules hold. None when impossible."""
        minp = REQ[b][tier - 1]["min_parcels_owned"]
        gp, fp, hp = self.gp, self.fp, self.hp
        buy = []
        if BIDS[b] == "homes" and hp < 1:
            if hp >= 2:
                return None
            hp += 1
            buy.append("h")
        if BIDS[b] == "landmark" or True:
            pass
        while gp + fp + hp < minp:
            if gp < 12:
                gp += 1
                buy.append("g")
            elif fp < 2:
                fp += 1
                buy.append("f")
            elif hp < 2:
                hp += 1
                buy.append("h")
            else:
                return None
        return buy

    # -- gates
    def can_upgrade(self, b, tier, ignore_tourn=False):
        e = self.eco
        if e.tiers[b] != tier - 1:
            return False
        if self.demo and tier > DEMO_TIER[b]:
            return False
        q = REQ[b][tier - 1]
        if e.holes < q["min_holes"] or e.rating < q["min_avg_hole_score"] or e.members() < q["min_members"]:
            return False
        for sp in q["specific"]:
            if e.tiers[IDX[sp["building"]]] < sp["min_tier"]:
                return False
        ao = q["any_others"]
        if ao:
            n = sum(1 for o in range(NB) if o != b and e.tiers[o] >= ao["min_tier"])
            if n < ao["count"]:
                return False
        ht = q["hosted_tournament"]
        if ht and not ignore_tourn and self.tourn_rank < LEVEL_RANK[ht["min_level"]]:
            return False
        return True

    def apply_land(self, buy):
        for k in buy:
            if k == "g":
                self.gp += 1
            elif k == "f":
                self.fp += 1
            else:
                self.hp += 1
        self.eco.parcels = self.parcels_total()

    def net_now(self, tiers, holes, parcels, fee):
        e = self.eco
        return E.day_estimate(self.P, UPK, tiers, holes, parcels, e.rating, e.members_milli, fee, e.reputation)["net"]

    # -- fee
    def choose_fee(self, day):
        e = self.eco
        pol = ARCH[self.arch][2]
        if pol == "opt" and day % 3 == 0:
            e.set_green_fee(E.suggest_fee_cents(self.P, UPK, e.tiers, e.holes, e.rating, e.reputation))
        elif pol == "slow" and day % 20 == 0:
            f = E.suggest_fee_cents(self.P, UPK, e.tiers, e.holes, e.rating, e.reputation)
            e.set_green_fee(int(f * self.rnd.uniform(0.7, 1.3)) // 100 * 100)
        elif pol == "max" and not self.fee_reset:
            e.set_green_fee(self.c["fee_max_cents"])
        elif pol == "max" and day % 3 == 0:
            e.set_green_fee(E.suggest_fee_cents(self.P, UPK, e.tiers, e.holes, e.rating, e.reputation))
        elif pol == "min":
            e.set_green_fee(self.c["fee_min_cents"])

    # -- candidate list
    def tier5_waits_for(self, rank):
        """True when some tier 5 upgrade needs a hosted tournament of at least `rank` and nothing else is missing."""
        e = self.eco
        for b in range(NB):
            if e.tiers[b] != 4:
                continue
            ht = REQ[b][4]["hosted_tournament"]
            if ht and LEVEL_RANK[ht["min_level"]] == rank and self.can_upgrade(b, 5, ignore_tourn=True):
                return True
        return False

    def candidates(self):
        e = self.eco
        day_now = e.day
        cands = []
        hb = self.next_hole_bundle()
        if hb:
            cost, buy, _ = hb
            pc = 0
            if buy:
                pc = self.parcel_cost()
            par = e.parcels + len(buy)
            d = self.net_now(e.tiers, e.holes + 1, par, e.fee) - self.net_now(e.tiers, e.holes, e.parcels, e.fee)
            cands.append(("hole", None, cost + pc, d, buy, 1))
        for b in range(NB):
            tier = e.tiers[b] + 1
            if tier > 5 or not self.can_upgrade(b, tier):
                continue
            buy = self.parcel_bundle(b, tier)
            if buy is None:
                continue
            cost = self.price[BIDS[b]][tier - 1] * 100
            made = self.parcels_total() - self.c["start_parcels"]
            for _ in buy:
                cost += E.parcel_cost_cents(LAND["parcel_base_cost"], LAND["parcel_growth_pct"], made)
                made += 1
            t2 = list(e.tiers)
            t2[b] = tier
            d = self.net_now(t2, e.holes, e.parcels + len(buy), e.fee) - self.net_now(e.tiers, e.holes, e.parcels, e.fee)
            cands.append(("tier", (b, tier), cost, d, buy, 1))
        # tournaments: real entry checklist from tournaments.json. The bot hosts local (and regional) as soon as a tier 5
        # upgrade is waiting only for it. National and major are optional late-game sinks, hosted after tier 5 is complete.
        if self.tourn_active is None and day_now >= self.tourn_cd:
            need_local = self.tourn_rank < 1 and self.tier5_waits_for(1)
            need_regional = self.tourn_rank < 2 and self.tier5_waits_for(2)
            for lvl, need in (("local", need_local), ("regional", need_regional)):
                if need and tournament_eligible(lvl, e):
                    cands.append(("tourn", lvl, TLEVELS[lvl]["host_cost"] * 100, 0, [], 0))
                    break
            if len(self.res["all"]) == 5 and self.tourn_rank >= 2:
                for lvl in ("major", "national"):
                    if tournament_eligible(lvl, e):
                        cands.append(("tourn", lvl, TLEVELS[lvl]["host_cost"] * 100, 0, [], 2))
                        break
        # the bot renovates once everything is built, or from day 160 when it is evidently stuck below tier 5
        if e.renovation_available() and (len(self.res["all"]) == 5 or day_now >= 160):
            d = (E.day_estimate(self.P, UPK, e.tiers, e.holes, e.parcels, e.rating, e.members_milli, e.fee, e.reputation, 1000, e.renovation + 1)["net"]
                 - E.day_estimate(self.P, UPK, e.tiers, e.holes, e.parcels, e.rating, e.members_milli, e.fee, e.reputation, 1000, e.renovation)["net"])
            cands.append(("reno", None, e.renovation_cost(), d, [], 2))
        return cands

    def buy(self, cand, day):
        kind, arg, cost, d, buy, _prio = cand
        e = self.eco
        if e.spend(cost) != E.OK:
            return False
        self.nbuys += 1
        self.res["last_buy_day"] = day
        self.res.setdefault("buy_days", []).append(day)
        self.apply_land(buy)
        if kind == "hole":
            e.holes += 1
            if e.holes >= 18 and self.res["h18"] is None:
                self.res["h18"] = day
        elif kind == "tourn":
            L = TLEVELS[arg]
            rev = tournament_revenue_dollars(arg, e.tiers[0]) * 100
            self.tourn_active = (arg, day + L["prep_days"] + L["duration_days"], rev)
            if LEVEL_RANK[arg] > 2:
                self.sink_spend += cost - rev
        elif kind == "reno":
            e.renovation += 1
            self.sink_spend += cost
            self.res["reno_first"] = self.res.get("reno_first", day)
        else:
            b, tier = arg
            e.tiers[b] = tier
            self.res["first_any"].setdefault(tier, day)
            if all(x >= tier for x in e.tiers):
                self.res["all"].setdefault(tier, day)
        return True

    def purchase_phase(self, day, gross, upkeep):
        reserve_days, style, _ = ARCH[self.arch]
        e = self.eco
        bought_any = False
        feasible_seen = False
        affordable_seen = False
        for _ in range(4):
            cands = self.candidates()
            if cands:
                feasible_seen = True
            reserve = reserve_days * upkeep
            afford = [c for c in cands if e.cash - c[2] >= reserve]
            if not afford:
                break
            affordable_seen = True
            if style == "big":
                afford.sort(key=lambda c: (c[5] == 2, -c[2]))
            else:
                afford.sort(key=lambda c: (c[5], c[2] if c[5] == 2 else -(c[3] * 1.0 / max(c[2], 1))))
            if not self.buy(afford[0], day):
                break
            bought_any = True
        if bought_any:
            return "bought"
        if feasible_seen:
            return "cash"
        return "gate"

    def run(self):
        e = self.eco
        eco_days = self.days
        e.day = 0
        e.set_green_fee(self.c["fee_start_cents"])
        gross = 1
        upkeep = 1
        for day in range(eco_days):
            gap = self.skill_cap - self.c["start_rating"]
            e.rating = int(self.c["start_rating"] + gap * (1.0 - 0.5 ** (day / self.half_life)))
            if self.tourn_active is not None and day >= self.tourn_active[1]:
                lvl, _, rev = self.tourn_active
                e.earn(rev)
                self.tourn_rank = max(self.tourn_rank, LEVEL_RANK[lvl])
                self.tourn_cd = day + TLEVELS[lvl]["cooldown_days"]
                self.tourn_active = None
                self.tourn_count += 1
            self.choose_fee(day)
            if self.shock:
                e.ext_permille = self.shock[2] if self.shock[0] <= day < self.shock[0] + self.shock[1] else 1000
            upkeep = max(e.daily_upkeep(), 1)
            status = self.purchase_phase(day, gross, upkeep)
            if status == "cash":
                self.res["cash_blocked"] += 1
                if self.res["first_stall"] is None:
                    self.res["first_stall"] = day
            elif status == "gate":
                self.res["gate_blocked"] += 1
            if e.cash > 30 * gross and status != "bought" and len(self.res["all"]) == 5:
                self.res["pile_days"] += 1
            rev0 = e.total_revenue
            for h in range(E.HOURS_PER_DAY):
                e.tick_hour()
            gross = max(e.total_revenue - rev0, 1)
            if e.cash < self.c["start_cash_cents"] // 5:
                self.res["low_first"] = self.res.get("low_first", day)
                if day < 30:
                    self.res["low_days30"] = self.res.get("low_days30", 0) + 1
            if self.res["m50"] is None and e.members() >= 50:
                self.res["m50"] = day
            if e.bankrupt:
                self.res["bankrupt_events"] += 1
                self.fee_reset = True
                opts = e.recovery_options(self.tokens)
                if opts & E.OPT_LOAN:
                    e.take_bank_loan()
                    self.res["loans"] += 1
                elif opts & E.OPT_TOKEN:
                    self.tokens -= self.c["recovery_token_cost"]
                    e.apply_token_recovery()
                    self.res["token_rec"] += 1
                else:
                    self.res["quit"] = True
                    break
            if (day + 1) % 7 == 0:
                self.tokens += 2
            if day + 1 in (10, 30, 100):
                self.res.setdefault("buys", {})[day + 1] = self.nbuys
            if day + 1 in SNAP_DAYS:
                self.res["snap"][day + 1] = {"cash": e.cash, "gross": gross, "net": gross - e.daily_upkeep(),
                                             "holes": e.holes, "tsum": sum(e.tiers), "rating": e.rating,
                                             "members": e.members(), "parcels": e.parcels}
            if len(self.res["all"]) == 5 and self.res["t5_full"] is None:
                self.res["t5_full"] = day
        self.res["final_cash"] = e.cash
        self.res["reno"] = e.renovation
        self.res["sink_spend"] = self.sink_spend
        self.res["tiers"] = list(e.tiers)
        self.res["holes"] = e.holes
        self.res["skill_cap"] = self.skill_cap
        return self.res


def pct(v, q):
    v = sorted(v)
    if not v:
        return None
    return v[min(len(v) - 1, int(q * len(v)))]


def cohort_runs(P, skill, arch, n, days, seed0=1000, demo=False, **kw):
    return [Run(P, seed0 + i, arch, skill, days, demo, **kw).run() for i in range(n)]


def fmt(v):
    return "-" if v is None else str(v)


def real_hours(day):
    return day * MIN_PER_DAY_X100 / 100.0 / 60.0


def q3(v):
    if not v:
        return "-"
    return "%s/%s/%s" % (pct(v, .1), pct(v, .5), pct(v, .9))


def report(P, n=60, days=400):
    print("=== balance report: %d runs per profile, %d game days; real hours = days x %.1f min (assumed speed mix)" % (n, days, MIN_PER_DAY_X100 / 100.0))
    print("Target (DEC-066): all ten buildings at tier 5 and 18 holes in 100 to 150 game days (about 20 to 30 hours).")
    out = {}
    fin = {}
    print("\n-- per skill profile, casual fee habits. Days are p10/p50/p90 of the runs that got there; 'inf' = same bot with unlimited cash (the rating/gate floor)")
    for sk in PROFILES:
        rs = cohort_runs(P, sk, "casual", n, days)
        inf = cohort_runs(P, sk, "casual", max(n // 3, 10), days, start_cash=10 ** 12)
        out[sk] = rs
        line = []
        for k in (3, 4, 5):
            al = [r["all"][k] for r in rs if k in r["all"]]
            line.append("T%d %s (%d/%d)" % (k, q3(al), len(al), n))
        print("%-9s cap %d | %s" % (sk, PROFILES[sk][0], " | ".join(line)))
        t5 = [r["all"][5] for r in rs if 5 in r["all"]]
        i5 = [r["all"][5] for r in inf if 5 in r["all"]]
        i4 = [r["all"][4] for r in inf if 4 in r["all"]]
        h18 = [r["h18"] for r in rs if r["h18"] is not None]
        print("          18 holes day %s | T5-all inf-cash day p50 %s, T4-all inf-cash p50 %s | T5-all p50 hours %s | full course AND T5 by day 150: %d/%d" % (
            q3(h18), fmt(pct(i5, .5)), fmt(pct(i4, .5)), fmt(None if not t5 else round(real_hours(pct(t5, .5)), 1)),
            sum(1 for r in rs if 5 in r["all"] and r["all"][5] <= 150 and r["h18"] is not None), n))
        sn = {d: [r["snap"][d] for r in rs if d in r["snap"]] for d in SNAP_DAYS}
        for d in (10, 30, 60, 100, 150, 400):
            if sn.get(d):
                print("          day %3d med: cash $%s gross/day $%s net/day $%s holes %s tiers %s rating %s members %s parcels %s" % (
                    d, *[format(pct([x[k] for x in sn[d]], .5) // 100, ",") for k in ("cash", "gross", "net")],
                    *[pct([x[k] for x in sn[d]], .5) for k in ("holes", "tsum", "rating", "members", "parcels")]))
        print("          purchases by day 10/30/100 (med): %s/%s/%s | first cash stall day med %s | cash-blocked days med %s, gate-blocked med %s, pile days (after T5) med %s | reno levels at end med %s, sink spend med $%s | bankrupt %d" % (
            pct([r["buys"][10] for r in rs if "buys" in r], .5), pct([r["buys"][30] for r in rs if "buys" in r], .5),
            pct([r["buys"][100] for r in rs if "buys" in r], .5), fmt(pct([r["first_stall"] for r in rs if r["first_stall"] is not None], .5)),
            pct([r["cash_blocked"] for r in rs], .5), pct([r["gate_blocked"] for r in rs], .5), pct([r["pile_days"] for r in rs], .5),
            pct([r["reno"] for r in rs], .5), format((pct([r["sink_spend"] for r in rs], .5) or 0) // 100, ","),
            sum(1 for r in rs if r["bankrupt_events"])))
    # population: skill profile x habit mix (gouger is a stress case, not part of the mix)
    print("\n-- population = skill weights %s x habit weights %s" % (
        ", ".join("%s %d%%" % (k, round(SKILL_W[k] * 100)) for k in PROFILES),
        ", ".join("%s %d%%" % (k, round(v * 100)) for k, v in HABIT_W.items())))
    ncell = max(n // 3, 12)
    cells = {}
    for sk in PROFILES:
        for arch in HABIT_W:
            cells[(sk, arch)] = out[sk] if arch == "casual" else cohort_runs(P, sk, arch, ncell, days)

    def share(profiles, lo, hi):
        tot = 0.0
        got = 0.0
        for p in profiles:
            for arch, hw in HABIT_W.items():
                rs = cells[(p, arch)]
                ok = sum(1 for r in rs if 5 in r["all"] and r["h18"] is not None and lo <= max(r["all"][5], r["h18"]) <= hi)
                tot += SKILL_W[p] * hw
                got += SKILL_W[p] * hw * ok / len(rs)
        return 100.0 * got / tot

    def fin_days(profiles):
        v = []
        for p in profiles:
            for arch in HABIT_W:
                v += [max(r["all"][5], r["h18"]) for r in cells[(p, arch)] if 5 in r["all"] and r["h18"] is not None]
        return v
    cbc = [p for p in PROFILES if p != "novice"]
    summary = {}
    for label, ps in (("all players", list(PROFILES)), ("casual-but-competent (not novice)", cbc)):
        fd = fin_days(ps)
        summary[label] = (share(ps, 0, 99), share(ps, 100, 150), share(ps, 0, 150), share(ps, 0, days))
        print("%-34s finished (T5 all + 18 holes) before day 100: %4.1f%% | day 100-150: %4.1f%% | by day 150: %4.1f%% | by day %d: %4.1f%%" % (
            label, summary[label][0], summary[label][1], summary[label][2], days, summary[label][3]))
        print("%-34s finish day p10/p50/p90 of finishers %s = %s hours at the assumed speed mix, %s hours if every day ran at 1x" % (
            "", q3(fd), "/".join(str(round(real_hours(x), 1)) for x in (pct(fd, .1), pct(fd, .5), pct(fd, .9))),
            "/".join(str(round(x * 0.25, 1)) for x in (pct(fd, .1), pct(fd, .5), pct(fd, .9)))))
        print("%-34s finish in 20-30h: %.1f%% at 1x; %.1f%% at assumed speed mix (unfunded)" % (
            "", share(ps, 80, 120), share(ps, 99, 148)))
    print("Hours exclude editor time and pauses. Population shares are assumed weights, not observed player data.")
    print("Assumed speed mix needs 3 tokens/game day: 300-450 tokens over days 100-150. Bot token income does not fund clock speed.")
    summary["tier5_reach_by_profile"] = {p: sum(1 for arch in HABIT_W for r in cells[(p, arch)] if 5 in r["all"]) * 100.0 / sum(len(cells[(p, arch)]) for arch in HABIT_W) for p in PROFILES}
    print("T5 reached within %d days by profile: %s" % (days, ", ".join("%s %.0f%%" % (p, v) for p, v in summary["tier5_reach_by_profile"].items())))
    print("\n-- behaviour archetypes (casual profile): finish day and bankruptcies")
    for arch in ARCH:
        rs = cohort_runs(P, "casual", arch, max(n // 2, 15), days)
        t5 = [r["all"][5] for r in rs if 5 in r["all"]]
        print("%-8s T5-all p10/p50/p90 %s (%d/%d)  bankrupt runs %2d  loans %d token recoveries %d quit %d | day-150 gross/day med $%s | day-400 cash med $%s" % (
            arch, q3(t5), len(t5), len(rs), sum(1 for r in rs if r["bankrupt_events"]), sum(r["loans"] for r in rs),
            sum(r["token_rec"] for r in rs), sum(1 for r in rs if r["quit"]),
            format((pct([r["snap"][150]["gross"] for r in rs if 150 in r["snap"]], .5) or 0) // 100, ","),
            format((pct([r["final_cash"] for r in rs], .5) or 0) // 100, ",")))
    return out


def demo_report(P, n=30):
    print("=== demo cut (DEC-055/063): 9 holes max, Clubhouse T2, Pro shop T2, Range T2, Restaurant T1 (7 building steps)")
    for sc in (None, 25000, 15000):
        for sk in ("novice", "casual", "competent"):
            rs = cohort_runs(P, sk, "casual", n, 400, demo=True, start_cash=None if sc is None else sc * 100)
            wall = [r["last_buy_day"] for r in rs if "last_buy_day" in r]
            c150 = [r["snap"][150]["cash"] for r in rs if 150 in r["snap"]]
            net = [r["snap"][150]["net"] for r in rs if 150 in r["snap"]]
            print("start cash %-8s %-9s last demo purchase day med %s (p25 %s, p75 %s) = %s real hours | holes %s | day-150 cash med $%s, net/day $%s" % (
                "default" if sc is None else "$%s" % format(sc, ","), sk, pct(wall, .5), pct(wall, .25), pct(wall, .75),
                round(real_hours(pct(wall, .5) or 0), 1), pct([r["holes"] for r in rs], .5),
                format((pct(c150, .5) or 0) // 100, ","), format((pct(net, .5) or 0) // 100, ",")))


def stress_report(P, n=10):
    print("=== stress: demand shocks (events agent hook ext_permille). Rows: shock = (start day, days, demand permille of normal)")
    for shock in [(20, 30, 250), (80, 30, 250), (150, 30, 250), (80, 30, 0), (150, 60, 0)]:
        for arch in ("casual", "greedy"):
            rs = []
            for sk in ("casual", "competent"):
                rs += cohort_runs(P, sk, arch, n, 300, shock=shock)
            print("%-16s %-7s bankrupt runs %2d/%d  events %d  loans %d  token recoveries %d  quit %d" % (
                shock, arch, sum(1 for r in rs if r["bankrupt_events"]), len(rs), sum(r["bankrupt_events"] for r in rs),
                sum(r["loans"] for r in rs), sum(r["token_rec"] for r in rs), sum(1 for r in rs if r["quit"])))


def sens_report(P, n=12):
    print("=== sensitivities (casual and competent profiles, casual habits, median): T3-all | T4-all | T5-all day | purchase-days d6-30 | cash at day 400")
    base_land = dict(LAND)

    def row(label, P2, start_cash=None):
        out = []
        for sk in ("casual", "competent"):
            rs = cohort_runs(P2, sk, "casual", n, 400, start_cash=start_cash)
            t = [fmt(pct([r["all"][k] for r in rs if k in r["all"]], .5)) for k in (3, 4, 5)]
            pd = pct([len([x for x in set(r.get("buy_days", [])) if 5 < x <= 30]) for r in rs], .5)
            out.append("%s: T3 %s T4 %s T5 %s pd %s cash400 $%s" % (sk, t[0], t[1], t[2], pd, format(pct([r["final_cash"] for r in rs], .5) // 100, ",")))
        print("%-30s %s" % (label, " || ".join(out)))
    for sc in (20000, 30000, 50000, 80000):
        row("start cash $%s" % format(sc, ","), P, sc * 100)
    for base, growth in ((8000, 115), (8000, 130), (12000, 115), (25000, 130)):
        LAND["parcel_base_cost"] = base
        LAND["parcel_growth_pct"] = growth
        row("parcels $%s x %d%%" % (format(base, ","), growth), P)
    LAND.update(base_land)


def token_report(P):
    print("=== time-skip value (DEC-053): clock drains 1/2/4 tokens per real minute at 2x/4x/8x, so one game day sped up costs 7.5 tokens at any speed")
    print("Time saved per accelerated day: 7.5 min at 2x, 11.25 min at 4x, 13.125 min at 8x. No instant day skip.")
    for label, tiers, h, par, r, mem in (("start (6 holes, no buildings)", [0] * 10, 6, 5, 34, 0), ("T2 stage", [2] * 10, 8, 8, 40, 40),
                                         ("T3 stage", [3] * 10, 12, 10, 46, 100), ("T4 stage", [4] * 10, 16, 13, 56, 200),
                                         ("T5 stage", [5] * 10, 18, 15, 66, 350)):
        f = E.suggest_fee_cents(P, UPK, tiers, h, r)
        d = E.day_estimate(P, UPK, tiers, h, par, r, mem * 1000, f)
        print("%-30s net/day $%s -> 7.5 tokens accelerate one day = $%s net per token" % (
            label, format(d["net"] // 100, ","), format(d["net"] // 750, ",")))


def write_final():
    P = derive(load())
    with open(os.path.join(HERE, "economy_params.json"), "w", newline="\n") as f:
        json.dump(P, f, indent=1)
        f.write("\n")
    return P


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "report"
    if cmd == "write":
        make_params.write_base() if "--base" in sys.argv else None
        P = write_final()
        for i, b in enumerate(BIDS):
            print("%-14s added $/day %s  price $ %s" % (b, P["added_daily_income_dollars"][b], P["price_dollars"][b]))
    elif cmd == "report":
        P = write_final()
        report(P, int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    elif cmd == "demo":
        demo_report(write_final())
    elif cmd == "stress":
        stress_report(write_final())
    elif cmd == "sens":
        sens_report(write_final())
    elif cmd == "tokens":
        token_report(write_final())
    elif cmd == "all":
        P = write_final()
        n = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        report(P, n)
        print()
        demo_report(P, n)
        print()
        stress_report(P, max(n // 3, 6))
        print()
        sens_report(P, max(n // 3, 6))
        print()
        token_report(P)
