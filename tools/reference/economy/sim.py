"""Mulligan Hills economy simulation. Python 3 stdlib only.
Money in the accounting path goes through mh_economy.Economy (integer cents, same code the GDScript mirrors).
Demand behaviour is float and is a MODEL: every constant marked ASSUMPTION is invented and must be re-tuned
against the closed test. Run: python3 sim.py   (writes economy_params.json, prints the report)."""
import json
import math
import os
import random
import sys

import mh_economy as E

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BUILD = json.load(open(os.path.join(ROOT, "docs", "spec", "data", "buildings.json")))
BIDS = [b["id"] for b in BUILD["buildings"]]
REQ = {b["id"]: [t["requires"] for t in b["tiers"]] for b in BUILD["buildings"]}
HEAVY = {b["id"] for b in BUILD["buildings"] if b["land_class"] == "heavy"}
UPKEEP_FILE = {b["id"]: [t["upkeep_per_day"] * 100 for t in b["tiers"]] for b in BUILD["buildings"]}

# ---------------- tunable constants (ASSUMPTION unless stated)
T = {
    "targets": [6, 8, 10, 12, 15],          # DEC-050 starting targets (game days), tiers 1..5
    "score_gates": [0, 32, 42, 52, 62],     # DEC-048 gates for tiers 1..5 (buildings.json still has 25/30/36/42)
    "hole_gates": [0, 6, 10, 14, 18],
    "ref_holes": [6, 8, 12, 16, 18],
    "ref_rating": [34, 36, 46, 56, 66],
    "start_holes": 6, "start_golf_parcels": 4, "start_other_parcels": 1,
    "golf_parcels_max": 12, "other_parcels_max": 4, "holes_per_2_parcels": 3,
    "hole_cost_base_cents": 600000, "hole_cost_growth_permille": 1060,
    "hole_upkeep_cents": 4000, "parcel_upkeep_cents": 1500,
    "arrivals_base": 30.0, "arrivals_per_hole": 14.0, "attract_exp": 1.5,
    "tee_cap_per_day": 180,                 # 5 groups/h (12 min interval, DEC-052) x 3 golfers x 12 h
    "hour_profile": [3, 5, 8, 10, 10, 9, 9, 10, 10, 8, 5, 3],
    "member_cap": [0, 40, 80, 140, 220, 320], "member_dues_cents": 600, "member_join_rate": 0.03,
    "tournament_cost_cents": 2500000,
    "rating_start": 34.0,
    "heavy_extra_parcel": 0,                 # already encoded in buildings.json min_parcels_owned (heavy 5,6,9,12,15 vs light 5,5,8,11,14)
}
# per building, per tier 1..5 effects. anc = ancillary cents per golfer; dem = arrivals bonus permille;
# flat = cents per day at rating 50 (scaled by rating/50); cut = permille cut of hole+parcel upkeep
EFF = {
    "clubhouse":     {"dem": [40, 80, 120, 170, 230]},
    "pro_shop":      {"anc": [300, 600, 1000, 1500, 2100]},
    "driving_range": {"anc": [200, 400, 700, 1000, 1400], "dem": [30, 60, 100, 140, 180]},
    "restaurant":    {"anc": [400, 900, 1600, 2400, 3400]},
    "pool_spa":      {"flat": [4000, 9000, 16000, 26000, 40000], "dem": [10, 20, 30, 40, 50]},
    "cart_barn":     {"anc": [200, 400, 600, 800, 1000], "dem": [10, 20, 30, 40, 50]},
    "maintenance":   {"cut": [50, 100, 150, 200, 250], "dem": [15, 30, 45, 60, 75]},
    "lodging":       {"flat": [5000, 12000, 24000, 40000, 65000]},
    "homes":         {"flat": [3000, 8000, 16000, 30000, 50000]},
    "landmark":      {"dem": [50, 120, 200, 300, 420], "flat": [0, 0, 5000, 12000, 25000]},
}
CORE = dict(E.CORE_DEFAULTS)
_EFF0 = json.loads(json.dumps(EFF))


def apply_scale(anc=1.0, flat=1.0, dem=1.0):
    for b in EFF:
        for k, arr in _EFF0[b].items():
            f = anc if k == "anc" else (flat if k == "flat" else (dem if k == "dem" else 1.0))
            EFF[b][k] = [int(round(v * f)) for v in arr]


def eff(bid, key, tier):
    if tier <= 0:
        return 0
    arr = EFF[bid].get(key)
    return arr[tier - 1] if arr else 0


def new_state():
    return {"holes": T["start_holes"], "gp": T["start_golf_parcels"], "op": T["start_other_parcels"],
            "tier": {b: 0 for b in BIDS}, "members": 0.0, "rating": T["rating_start"], "tourn": False,
            "tourn_day": -1}


def clone(s):
    c = dict(s)
    c["tier"] = dict(s["tier"])
    return c


def hole_cap(s):
    return s["gp"] * T["holes_per_2_parcels"] // 2


def hole_cost(n_holes):
    c = T["hole_cost_base_cents"]
    for _ in range(max(0, n_holes - T["start_holes"])):
        c = c * T["hole_cost_growth_permille"] // 1000
    return c


def day_model(s, fee, noise=1.0, rep=1000):
    """Expected one-day figures (floats, cents). No state change."""
    n = min(s["holes"], 18)
    r = s["rating"]
    att = (max(r, 1.0) / 50.0) ** T["attract_exp"]
    arr = T["arrivals_base"] + T["arrivals_per_hole"] * n * att
    dem = 1000
    anc = 0
    flat = 0.0
    for b in BIDS:
        t = s["tier"][b]
        dem += eff(b, "dem", t)
        anc += eff(b, "anc", t)
        flat += eff(b, "flat", t) * (r / 50.0)
    arr = arr * dem / 1000.0 * noise * rep / 1000.0
    wtp = E.wtp_cents(CORE, int(round(r)), n)
    acc = E.fee_acceptance_permille(fee, wtp) / 1000.0
    golfers = min(arr * acc, float(T["tee_cap_per_day"]))
    dues = s["members"] * T["member_dues_cents"]
    revenue = golfers * fee + golfers * anc + flat + dues
    cut = sum(eff(b, "cut", s["tier"][b]) for b in ("maintenance",))
    base_up = (s["holes"] * T["hole_upkeep_cents"] + (s["gp"] + s["op"]) * T["parcel_upkeep_cents"])
    base_up = base_up * (1000 - cut) // 1000
    return {"arrivals": arr, "golfers": golfers, "wtp": wtp, "revenue": revenue, "fee_rev": golfers * fee,
            "anc": golfers * anc, "flat": flat, "dues": dues, "base_upkeep": base_up}


def upkeep_bld_cents(costs_paid, ppm):
    return costs_paid * ppm // 1000000


def best_fee(s, rep=1000):
    best, bf = -1.0, CORE["fee_min_cents"]
    for f in range(500, 25001, 250):
        m = day_model(s, f, 1.0, rep)
        if m["revenue"] > best:
            best, bf = m["revenue"], f
    return bf


def net_income(s, fee, PRICE, ppm):
    m = day_model(s, fee)
    bu = 0
    for b in BIDS:
        for t in range(1, s["tier"][b] + 1):
            bu += PRICE[b][t - 1] * ppm // 1000000
    return m["revenue"] - m["base_upkeep"] - bu


# ---------------- payback pricing (DEC-050)
def ref_state(tier):
    s = new_state()
    s["holes"] = T["ref_holes"][tier - 1]
    s["rating"] = float(T["ref_rating"][tier - 1])
    s["gp"] = 12 if s["holes"] > 6 else 4
    for b in BIDS:
        s["tier"][b] = tier - 1
    ct = s["tier"]["clubhouse"]
    s["members"] = T["member_cap"][ct] * max(0.0, min(1.3, (s["rating"] - 28) / 30.0))
    return s


def compute_prices(targets=None, ppm=None):
    targets = targets or T["targets"]
    ppm = CORE["upkeep_ppm_per_day"] if ppm is None else ppm
    price, added = {}, {}
    for b in BIDS:
        price[b], added[b] = [], []
        for tier in range(1, 6):
            s0 = ref_state(tier)
            s0["tier"][b] = tier - 1
            s1 = clone(s0)
            s1["tier"][b] = tier
            if b == "clubhouse":
                s0["members"] = T["member_cap"][tier - 1] * max(0.0, min(1.3, (s0["rating"] - 28) / 30.0))
                s1["members"] = T["member_cap"][tier] * max(0.0, min(1.3, (s1["rating"] - 28) / 30.0))
            f = best_fee(s1)
            g = day_model(s1, f)
            g0 = day_model(s0, f)
            base_delta_cut = g0["base_upkeep"] - g["base_upkeep"]
            add = int(g["revenue"] - g0["revenue"] + base_delta_cut)
            added[b].append(add)
            price[b].append(E.payback_price_cents(targets[tier - 1], add, ppm) // 10000 * 10000)
    return price, added


# ---------------- gates
def can_upgrade(s, b, tier, day):
    q = REQ[b][tier - 1]
    if s["tier"][b] != tier - 1:
        return False
    if s["holes"] < q["min_holes"]:
        return False
    if tier >= 2 and s["rating"] < T["score_gates"][tier - 1]:
        return False
    if s["members"] < q["min_members"]:
        return False
    for sp in q["specific"]:
        if s["tier"][sp["building"]] < sp["min_tier"]:
            return False
    ao = q["any_others"]
    if ao:
        cnt = sum(1 for o in BIDS if o != b and s["tier"][o] >= ao["min_tier"])
        if cnt < ao["count"]:
            return False
    if q["hosted_tournament"] and not s["tourn"]:
        return False
    return True


def parcels_needed(s, b, tier):
    """Parcels that would have to be owned; returns (golf_needed_total, other_needed_total)."""
    q = REQ[b][tier - 1]
    other = 1
    heavy = sum(1 for h in HEAVY if (s["tier"][h] >= 2 and h != b))
    if T["heavy_extra_parcel"] and b in HEAVY and tier >= 2:
        heavy += 1
    if T["heavy_extra_parcel"]:
        other += heavy
    return q["min_parcels_owned"], other


def parcel_bundle(s, b, tier):
    """Extra parcels to buy for this upgrade: list of 'g'/'o'. None if impossible."""
    minp, other_need = parcels_needed(s, b, tier)
    buy = []
    gp, op = s["gp"], s["op"]
    while op < other_need:
        if op >= T["other_parcels_max"]:
            return None
        op += 1
        buy.append("o")
    while gp + op < minp:
        if gp < T["golf_parcels_max"]:
            gp += 1
            buy.append("g")
        elif op < T["other_parcels_max"]:
            op += 1
            buy.append("o")
        else:
            return None
    return buy


ARCH = {
    # name: reserve_days, greedy, fee_policy, weight
    "careful": (8, False, "smart", 0.25),
    "typical": (3, False, "smart_slow", 0.35),
    "lazy_fee": (3, False, "fixed", 0.15),
    "greedy": (0, True, "smart_slow", 0.15),
    "gouger": (3, False, "max", 0.10),
}


def run(seed, arch, days, PRICE, ppm, verbose=False, skill=None, heavy_extra=None):
    rnd = random.Random(seed)
    reserve_days, greedy, fee_pol, _w = ARCH[arch]
    if skill is None:
        u = rnd.random()
        skill = rnd.gauss(50, 7) if u < 0.4 else (rnd.gauss(62, 7) if u < 0.8 else rnd.gauss(74, 6))
        skill = max(38.0, min(90.0, skill))
    growth = rnd.uniform(0.06, 0.15)
    eco = E.Economy(CORE)
    s = new_state()
    fee = eco.fee
    res = {"first_any": {}, "all": {}, "bankrupt": 0, "loans": 0, "quit": False, "skill": skill,
           "cash_blocked": 0, "gate_blocked": 0, "bought_days": 0, "snap": {}, "h18": None, "m50": None,
           "first_purchase": None, "cash_ratio_max": 0.0, "hole_days": {}}
    carry = 0.0
    paid_costs = {b: [0] * 5 for b in BIDS}
    for day in range(days):
        s["rating"] = min(skill, T["rating_start"] + growth * day)
        rep = eco.reputation
        # fee policy
        if fee_pol == "smart" and day % 3 == 0:
            fee = best_fee(s, rep)
        elif fee_pol == "smart_slow" and day % 20 == 0:
            fee = best_fee(s, rep)
            fee = int(fee * rnd.uniform(0.7, 1.3)) // 100 * 100
        elif fee_pol == "max":
            fee = CORE["fee_max_cents"]
        eco.set_green_fee(fee)
        fee = eco.fee
        noise = rnd.uniform(0.85, 1.15)
        m = day_model(s, fee, noise, rep)
        dupk = m["base_upkeep"]
        for b in BIDS:
            for t in range(1, s["tier"][b] + 1):
                dupk += PRICE[b][t - 1] * ppm // 1000000
        dupk = int(dupk)
        # hourly ticks
        prof = T["hour_profile"]
        psum = float(sum(prof))
        for h in range(E.HOURS_PER_DAY):
            gh = m["golfers"] * prof[h] / psum + carry
            n = int(gh)
            carry = gh - n
            anc_h = int(m["anc"] * prof[h] / psum)
            eco_fee_rev_ok = n
            eco.tick_hour(eco_fee_rev_ok, anc_h, int(m["flat"] + m["dues"]) if h == 0 else 0, dupk) if False else \
                _tick(eco, n, anc_h, int(m["flat"] + m["dues"]), dupk)
        # members move toward target
        ct = s["tier"]["clubhouse"]
        tgt = T["member_cap"][ct] * max(0.0, min(1.3, (s["rating"] - 28) / 30.0)) * (rep / 1000.0)
        s["members"] += (tgt - s["members"]) * T["member_join_rate"]
        if res["m50"] is None and s["members"] >= 50:
            res["m50"] = day
        # tournament
        if not s["tourn"] and s["tourn_day"] >= 0 and day >= s["tourn_day"] + 5:
            s["tourn"] = True
        # bankruptcy handling
        if eco.bankrupt:
            res["bankrupt"] += 1
            opts = eco.recovery_options()
            if opts & E.OPT_LOAN:
                eco.take_bank_loan()
                res["loans"] += 1
            elif opts & E.OPT_TOKEN:
                eco.use_token_recovery()
            else:
                res["quit"] = True
                res["quit_day"] = day
                break
        # purchases (up to 3 per day)
        bought = False
        blocked_cash = False
        any_feasible = False
        for _ in range(3):
            base_net = net_income(s, fee, PRICE, ppm)
            cands = []
            # holes
            if s["holes"] < 18:
                cost = hole_cost(s["holes"])
                extra = 0
                s2 = clone(s)
                s2["holes"] += 1
                if s2["holes"] > hole_cap(s):
                    if s["gp"] >= T["golf_parcels_max"]:
                        cost = None
                    else:
                        extra = E.parcel_cost_cents(CORE, s["gp"] + s["op"] - T["start_golf_parcels"] - T["start_other_parcels"])
                        s2["gp"] += 1
                if cost is not None:
                    d = net_income(s2, fee, PRICE, ppm) - base_net - T["hole_upkeep_cents"] * 0 
                    cands.append(("hole", None, cost + extra, d, s2))
            for b in BIDS:
                tier = s["tier"][b] + 1
                if tier > 5 or not can_upgrade(s, b, tier, day):
                    continue
                buy = parcel_bundle(s, b, tier)
                if buy is None:
                    continue
                s2 = clone(s)
                cost = PRICE[b][tier - 1]
                pb = s["gp"] + s["op"] - T["start_golf_parcels"] - T["start_other_parcels"]
                for k in buy:
                    cost += E.parcel_cost_cents(CORE, pb)
                    pb += 1
                    if k == "g":
                        s2["gp"] += 1
                    else:
                        s2["op"] += 1
                s2["tier"][b] = tier
                if b == "clubhouse" and tier == 5 and not s["tourn"]:
                    continue
                d = net_income(s2, fee, PRICE, ppm) - base_net
                cands.append(("tier", (b, tier), cost, d, s2))
            # tournament
            if (not s["tourn"] and s["tourn_day"] < 0 and s["holes"] >= 18 and s["tier"]["clubhouse"] >= 3
                    and s["rating"] >= T["score_gates"][3]):
                cands.append(("tourn", None, T["tournament_cost_cents"], 1.0, s))
            if cands:
                any_feasible = True
            reserve = reserve_days * (dupk)
            best = None
            afford = [c for c in cands if eco.cash - c[2] >= reserve]
            if not afford:
                if cands:
                    blocked_cash = True
                break
            if greedy:
                afford.sort(key=lambda c: -c[2])
            else:
                afford.sort(key=lambda c: -(c[3] / max(c[2], 1)) if c[0] != "tourn" else -1e9)
            best = afford[0]
            if best[3] <= 0 and best[0] != "tourn" and not greedy and best[0] == "hole" and False:
                break
            if eco.spend(best[2]) != E.OK:
                break
            bought = True
            if res["first_purchase"] is None:
                res["first_purchase"] = day
            if best[0] == "tourn":
                s["tourn_day"] = day
            else:
                ns = best[4]
                s["holes"], s["gp"], s["op"], s["tier"] = ns["holes"], ns["gp"], ns["op"], ns["tier"]
                if best[0] == "tier":
                    b, tier = best[1]
                    paid_costs[b][tier - 1] = best[2]
                    if tier not in res["first_any"]:
                        res["first_any"][tier] = day
                    if all(s["tier"][x] >= tier for x in BIDS) and tier not in res["all"]:
                        res["all"][tier] = day
                if s["holes"] >= 18 and res["h18"] is None:
                    res["h18"] = day
            # recompute upkeep for later loop iterations
            dupk = int(day_model(s, fee, 1.0, rep)["base_upkeep"] + sum(
                PRICE[x][t - 1] * ppm // 1000000 for x in BIDS for t in range(1, s["tier"][x] + 1)))
        if bought:
            res["bought_days"] += 1
        elif blocked_cash or (not any_feasible and False):
            res["cash_blocked"] += 1
        else:
            res["gate_blocked"] += 1
        gross = max(m["revenue"], 1.0)
        res["cash_ratio_max"] = max(res["cash_ratio_max"], eco.cash / gross)
        if day + 1 in (60, 180, 360, 540, 720, 1080, 1440):
            res["snap"][day + 1] = (eco.cash, int(gross), int(gross - dupk), s["holes"],
                                    sum(s["tier"].values()), round(s["rating"], 1), int(s["members"]))
        if len(res["all"]) == 5 and "done" not in res:
            res["done"] = day
    res["final_cash"] = eco.cash
    res["tiers"] = dict(s["tier"])
    res["holes"] = s["holes"]
    res["gp"], res["op"] = s["gp"], s["op"]
    res["tiers_sum"] = sum(s["tier"].values())
    return res


def _tick(eco, n_played, anc_h, flat_daily, dupk):
    # fee acceptance already folded into n_played by the demand model
    return eco.tick_hour(n_played, anc_h, flat_daily, dupk)


def pct(v, q):
    v = sorted(v)
    if not v:
        return None
    return v[min(len(v) - 1, int(q * len(v)))]


def report(PRICE, ppm, days=1440, n=60, label=""):
    out = {}
    print("=== %s (days=%d, runs/arch=%d)" % (label, days, n))
    agg_first = {k: [] for k in range(1, 6)}
    agg_all = {k: [] for k in range(1, 6)}
    tot = 0
    for arch, (_r, _g, _f, w) in ARCH.items():
        rs = [run(1000 + i, arch, days, PRICE, ppm) for i in range(n)]
        bk = sum(1 for r in rs if r["bankrupt"] > 0)
        quit_ = sum(1 for r in rs if r["quit"])
        fp = [r["first_purchase"] for r in rs if r["first_purchase"] is not None]
        print("%-9s bankrupt_runs %2d/%d quit %d  first_purchase_day med %s | all-tier5 done: %d/%d | blocked cash/gate days med %s/%s | m50 med %s" % (
            arch, bk, n, quit_, pct(fp, .5), sum(1 for r in rs if "done" in r), n,
            pct([r["cash_blocked"] for r in rs], .5), pct([r["gate_blocked"] for r in rs], .5),
            pct([r["m50"] for r in rs if r["m50"] is not None], .5)))
        for k in range(1, 6):
            a = [r["first_any"][k] for r in rs if k in r["first_any"]]
            al = [r["all"][k] for r in rs if k in r["all"]]
            print("    T%d first any: med %s p25 %s p75 %s (reached %d/%d) | all10: med %s (reached %d/%d)" % (
                k, pct(a, .5), pct(a, .25), pct(a, .75), len(a), n, pct(al, .5), len(al), n))
            if arch in ("careful", "typical"):
                agg_first[k] += a
                agg_all[k] += al
        out[arch] = {"bankrupt_runs": bk, "n": n, "quit": quit_,
                     "cash_snap_med": {str(d): pct([r["snap"][d][0] for r in rs if d in r["snap"]], .5) for d in (60, 180, 360, 720, 1440)}}
        for d in (60, 180, 360, 720):
            sn = [r["snap"][d] for r in rs if d in r["snap"]]
            if sn:
                print("    day %4d median: cash $%s income/day $%s net/day $%s holes %s tiers_sum %s rating %s members %s" % (
                    d, *[f"{pct([x[i] for x in sn], .5)/ (100 if i < 3 else 1):,.0f}" if i < 3 else pct([x[i] for x in sn], .5) for i in range(7)]))
    return out


if __name__ == "__main__":
    price, added = compute_prices()
    for b in BIDS:
        print(b, [p // 100 for p in price[b]], [a // 100 for a in added[b]])
    report(price, CORE["upkeep_ppm_per_day"], n=int(sys.argv[1]) if len(sys.argv) > 1 else 20, days=int(sys.argv[2]) if len(sys.argv) > 2 else 1440, label="v0")
