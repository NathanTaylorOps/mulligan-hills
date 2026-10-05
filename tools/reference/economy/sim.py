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
SKILL = {"low": 46, "mid": 56, "high": 66, "expert": 78}
SKILL_W = {"low": 0.25, "mid": 0.40, "high": 0.25, "expert": 0.10}


class Run:
    def __init__(self, P, seed, arch, skill_name, days, demo=False, tokens=12, shock=None, start_cash=None):
        self.P = P
        self.c = P["core"]
        self.rnd = random.Random(seed)
        self.arch = arch
        self.skill_cap = SKILL[skill_name] + self.rnd.uniform(-3, 3)
        self.half_life = self.rnd.uniform(60, 130)   # game days to close half of the gap to the skill cap
        self.days = days
        self.demo = demo
        self.eco = E.Economy(P, UPK, -1 if start_cash is None else start_cash)
        self.shock = shock                      # (start_day, length_days, ext_permille) demand shock, or None
        self.fee_reset = False
        self.nbuys = 0
        self.gp, self.fp, self.hp = 4, 1, 0
        self.tourn_rank = 0
        self.tourn_pending = (0, -1)
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
    def can_upgrade(self, b, tier):
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
        if ht and self.tourn_rank < LEVEL_RANK[ht["min_level"]]:
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
    def candidates(self):
        e = self.eco
        cands = []
        hb = self.next_hole_bundle()
        if hb:
            cost, buy, _ = hb
            pc = 0
            if buy:
                pc = self.parcel_cost()
            par = e.parcels + len(buy)
            d = self.net_now(e.tiers, e.holes + 1, par, e.fee) - self.net_now(e.tiers, e.holes, e.parcels, e.fee)
            cands.append(("hole", None, cost + pc, d, buy))
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
            cands.append(("tier", (b, tier), cost, d, buy))
        # tournaments (ASSUMPTION: local needs 14 holes, rating 52, clubhouse 3; regional needs 18 holes, rating 62)
        if self.tourn_pending[1] < 0:
            if self.tourn_rank == 0 and e.holes >= 14 and e.rating >= 52 and e.tiers[0] >= 3:
                cands.append(("tourn", 1, self.c["tournament_cost_cents"], 1, []))
            elif self.tourn_rank == 1 and e.holes >= 18 and e.rating >= 62 and e.tiers[0] >= 4:
                cands.append(("tourn", 2, self.c["tournament_regional_cost_cents"], 1, []))
        return cands

    def buy(self, cand, day):
        kind, arg, cost, d, buy = cand
        e = self.eco
        if e.spend(cost) != E.OK:
            return False
        self.nbuys += 1
        self.res["last_buy_day"] = day
        self.apply_land(buy)
        if kind == "hole":
            e.holes += 1
            if e.holes >= 18 and self.res["h18"] is None:
                self.res["h18"] = day
        elif kind == "tourn":
            self.tourn_pending = (arg, day + 5)
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
                afford.sort(key=lambda c: -c[2])
            else:
                afford.sort(key=lambda c: (c[0] != "tourn", -(c[3] * 1.0 / max(c[2], 1))))
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
        e.set_green_fee(self.c["fee_start_cents"])
        gross = 1
        upkeep = 1
        for day in range(eco_days):
            gap = self.skill_cap - self.c["start_rating"]
            e.rating = int(self.c["start_rating"] + gap * (1.0 - 0.5 ** (day / self.half_life)))
            if self.tourn_pending[1] >= 0 and day >= self.tourn_pending[1]:
                self.tourn_rank = self.tourn_pending[0]
                self.tourn_pending = (0, -1)
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
            if e.cash > 30 * gross and status != "bought":
                self.res["pile_days"] += 1
            rev0 = e.total_revenue
            for h in range(E.HOURS_PER_DAY):
                e.tick_hour()
            gross = max(e.total_revenue - rev0, 1)
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
            if day + 1 in (30, 100):
                self.res.setdefault("buys", {})[day + 1] = self.nbuys
            if day + 1 in (60, 180, 360, 540, 720, 1080, 1440):
                self.res["snap"][day + 1] = {"cash": e.cash, "gross": gross, "net": gross - e.daily_upkeep(),
                                             "holes": e.holes, "tsum": sum(e.tiers), "rating": e.rating,
                                             "members": e.members(), "parcels": e.parcels}
            if len(self.res["all"]) == 5 and self.res["t5_full"] is None:
                self.res["t5_full"] = day
        self.res["final_cash"] = e.cash
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


def report(P, n=30, days=720):
    print("=== balance report: %d runs per cell, %d game days (= %d real hours at 1x)" % (n, days, days * 15 // 60))
    out = {}
    print("\n-- time to tier, balanced bot, casual fee habits (median day, reached/runs). 'any' = first building at that tier, 'all' = all ten")
    for sk in SKILL:
        rs = cohort_runs(P, sk, "casual", n, days)
        line = []
        for k in range(1, 6):
            a = [r["first_any"][k] for r in rs if k in r["first_any"]]
            al = [r["all"][k] for r in rs if k in r["all"]]
            line.append("T%d any %s all %s (%d/%d)" % (k, fmt(pct(a, .5)), fmt(pct(al, .5)), len(al), n))
        print("%-7s %s" % (sk, " | ".join(line)))
        sn = {d: [r["snap"][d] for r in rs if d in r["snap"]] for d in (60, 180, 360, 720)}
        for d in (60, 180, 360, 720):
            if sn[d]:
                print("        day %3d median: cash $%s  gross/day $%s  net/day $%s  holes %s  tiers %s  rating %s  members %s  parcels %s" % (
                    d, *[format(pct([x[k] for x in sn[d]], .5) // (100 if k in ("cash", "gross", "net") else 1), ",") for k in ("cash", "gross", "net")],
                    *[pct([x[k] for x in sn[d]], .5) for k in ("holes", "tsum", "rating", "members", "parcels")]))
        print("        purchases by day 30 / 100 (med): %s / %s" % (pct([r["buys"][30] for r in rs if "buys" in r and 30 in r["buys"]], .5), pct([r["buys"][100] for r in rs if "buys" in r and 100 in r["buys"]], .5)))
        print("        cash-blocked days med %s, gate-blocked days med %s, pile days med %s, first cash stall day med %s, 18 holes day med %s, 50 members day med %s, bankrupt runs %d, quit %d" % (
            pct([r["cash_blocked"] for r in rs], .5), pct([r["gate_blocked"] for r in rs], .5),
            pct([r["pile_days"] for r in rs], .5), fmt(pct([r["first_stall"] for r in rs if r["first_stall"] is not None], .5)),
            fmt(pct([r["h18"] for r in rs if r["h18"] is not None], .5)), fmt(pct([r["m50"] for r in rs if r["m50"] is not None], .5)),
            sum(1 for r in rs if r["bankrupt_events"]), sum(1 for r in rs if r["quit"])))
        out[sk] = rs
    print("\n-- behaviour archetypes (mid skill): bankruptcies and income")
    for arch in ARCH:
        rs = cohort_runs(P, "mid", arch, n, days)
        print("%-8s bankrupt runs %2d/%d  events med %s  loans taken %d  token recoveries %d  quit %d | day-360 gross/day med $%s | day-720 cash med $%s | T3 all med %s" % (
            arch, sum(1 for r in rs if r["bankrupt_events"]), n, pct([r["bankrupt_events"] for r in rs], .5),
            sum(r["loans"] for r in rs), sum(r["token_rec"] for r in rs), sum(1 for r in rs if r["quit"]),
            format((pct([r["snap"][360]["gross"] for r in rs if 360 in r["snap"]], .5) or 0) // 100, ","),
            format((pct([r["final_cash"] for r in rs], .5) or 0) // 100, ","),
            fmt(pct([r["all"][3] for r in rs if 3 in r["all"]], .5))))
    return out


def demo_report(P, n=30):
    print("=== demo cut (DEC-055/063): 9 holes max, Clubhouse T2, Pro shop T2, Range T2, Restaurant T1 (7 building steps)")
    for sk in ("low", "mid", "high"):
        rs = cohort_runs(P, sk, "casual", n, 500, demo=True)
        wall = [r["last_buy_day"] for r in rs if "last_buy_day" in r]
        c100 = [r["snap"][360]["cash"] for r in rs if 360 in r["snap"]]
        net = [r["snap"][360]["net"] for r in rs if 360 in r["snap"]]
        print("%-5s last demo purchase day med %s (p25 %s, p75 %s) = %s real hours at 1x | holes %s | day-360 cash med $%s, net/day $%s" % (
            sk, pct(wall, .5), pct(wall, .25), pct(wall, .75), (pct(wall, .5) or 0) * 15 // 60, pct([r["holes"] for r in rs], .5),
            format((pct(c100, .5) or 0) // 100, ","), format((pct(net, .5) or 0) // 100, ",")))


def stress_report(P, n=10):
    print("=== stress: demand shocks (events agent hook ext_permille). Rows: shock = (start day, days, demand permille of normal)")
    for shock in [(40, 30, 250), (150, 30, 250), (300, 30, 250), (150, 30, 0), (300, 60, 0)]:
        for arch in ("casual", "greedy"):
            rs = []
            for sk in ("mid", "high"):
                rs += cohort_runs(P, sk, arch, n, 500, shock=shock)
            print("%-16s %-7s bankrupt runs %2d/%d  events %d  loans %d  token recoveries %d  quit %d" % (
                shock, arch, sum(1 for r in rs if r["bankrupt_events"]), len(rs), sum(r["bankrupt_events"] for r in rs),
                sum(r["loans"] for r in rs), sum(r["token_rec"] for r in rs), sum(1 for r in rs if r["quit"])))


def sens_report(P, n=10):
    print("=== sensitivities (mid and high skill, casual bot, median): T3-all day | T4-all day | T5-all day (high) | cash at day 720")
    base_land = dict(LAND)
    def row(label, P2, start_cash=None):
        out = []
        for sk in ("mid", "high"):
            rs = cohort_runs(P2, sk, "casual", n, 720, start_cash=start_cash)
            t = []
            for k in (3, 4, 5):
                v = [r["all"][k] for r in rs if k in r["all"]]
                t.append(fmt(pct(v, .5)))
            out.append("%s: T3 %s T4 %s T5 %s cash720 $%s" % (sk, t[0], t[1], t[2], format(pct([r["final_cash"] for r in rs], .5) // 100, ",")))
        print("%-34s %s" % (label, " || ".join(out)))
    for sc in (10000, 20000, 40000, 80000):
        row("start cash $%s" % format(sc, ","), P, sc * 100)
    for base, growth in ((25000, 130), (25000, 115), (12500, 130), (12500, 115)):
        LAND["parcel_base_cost"] = base
        LAND["parcel_growth_pct"] = growth
        row("parcels $%s x %d%%" % (format(base, ","), growth), P)
    LAND.update(base_land)
    for lo, hi in ((6, 8), (8, 12)):
        pass


def token_report(P):
    print("=== time-skip value (DEC-053): clock drains 1/2/4 tokens per real minute at 2x/4x/8x, so one game day sped up costs 7.5 tokens at any speed")
    for label, tiers, h, par, r, mem in (("start (6 holes, no buildings)", [0] * 10, 6, 5, 34, 0), ("T2 stage", [2] * 10, 8, 8, 40, 40),
                                         ("T3 stage", [3] * 10, 12, 10, 46, 100), ("T4 stage", [4] * 10, 16, 13, 56, 200),
                                         ("T5 stage", [5] * 10, 18, 15, 66, 350)):
        f = E.suggest_fee_cents(P, UPK, tiers, h, r)
        d = E.day_estimate(P, UPK, tiers, h, par, r, mem * 1000, f)
        print("%-30s net/day $%s -> 7.5 tokens skip one day = $%s per token (time saved 15 real minutes)" % (
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
