"""Generate runtime params and golden vectors for the GDScript economy.
Run from the repo root or this folder:  python3 tools/reference/economy/gen_golden.py
Writes:
  game/data/economy_params.json                      (runtime constants + derived price tables, from sim.py)
  game/tests/economy/golden/economy_golden.json      (vectors the gdUnit4 tests compare against)
JSON numbers stay far below 2**53 so GDScript's float-based JSON parser reads them exactly."""
import json
import os

import mh_economy as E
import sim

ROOT = sim.ROOT
OUT_PARAMS = os.path.join(ROOT, "game", "data", "economy_params.json")
OUT_GOLD = os.path.join(ROOT, "game", "tests", "economy", "golden", "economy_golden.json")


def dump(path, obj, indent=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="\n") as f:
        json.dump(obj, f, indent=indent, separators=None if indent else (",", ":"))
        f.write("\n")
    print("wrote", os.path.relpath(path, ROOT), os.path.getsize(path), "bytes")


def run_ticks(eco, n):
    rows = []
    for _ in range(n):
        r = eco.tick_hour()
        rows.append({"rev": r["revenue"], "golfers": r["golfers"], "paid": r["upkeep_paid"], "state": eco.state_list()})
    return rows


def main():
    P = sim.write_final()          # also rewrites tools/reference/economy/economy_params.json
    rt = {k: v for k, v in P.items() if not k.startswith("_")}
    dump(OUT_PARAMS, rt, indent=1)
    UP = sim.UPK
    G = {"params_digest": [P["core"]["start_cash_cents"], P["core"]["fee_max_cents"], sum(P["hour_profile"])]}

    G["wtp"] = [[h, r, E.wtp_cents(P, r, h)] for h, r in ((0, 50), (6, 34), (9, 40), (18, 66), (18, 100), (30, 120), (12, -5))]
    G["acc"] = [[f, w, E.acceptance_permille(f, w)] for f, w in ((500, 1000), (1000, 1000), (2000, 1000), (25000, 3000), (0, 500), (700, 0), (100, 100000))]
    G["attract"] = [E.attract_permille(r) for r in range(0, 101)]
    G["arrivals"] = [[h, r, d, rep, ext, E.arrivals_milli(P, h, r, d, rep, ext)]
                     for h, r, d, rep, ext in ((6, 34, 0, 1000, 1000), (10, 42, 20000, 1000, 1000), (18, 66, 120000, 850, 1000),
                                               (18, 80, 5000, 1000, 400), (4, 20, 0, 500, 1500))]
    G["split"] = [[d, [E.split_hour(d, h) for h in range(E.HOURS_PER_DAY)]] for d in (0, 1, 7, 10, 12345, 999999)]
    G["members_target"] = [[t, r, rep, E.members_target_milli(P, t, r, rep)] for t, r, rep in
                           ((0, 50, 1000), (1, 20, 1000), (2, 44, 1000), (3, 60, 1000), (5, 90, 1000), (4, 56, 850))]
    G["members_step"] = [[m, t, E.step_members_milli(P, m, t)] for m, t in ((0, 50000), (50000, 50000), (80000, 20000), (1000, 1001), (0, 0))]
    G["parcel_cost"] = [E.parcel_cost_cents(sim.LAND["parcel_base_cost"], sim.LAND["parcel_growth_pct"], n) for n in range(0, 11)]
    G["hole_cost"] = [E.hole_cost_cents(P, h) for h in range(6, 18)]
    G["payback"] = [[t, a, E.payback_price_cents(t, a)] for t, a in ((6, 12345), (15, 0), (0, 500), (10, 99999), (8, -3))]
    G["speed_tokens"] = [E.speed_tokens_for_days(d) for d in range(0, 13)]
    G["renovation"] = {"cost": [E.renovation_cost_cents(P, n) for n in range(-1, P["core"]["renov_max_levels"] + 2)],
                       "dem": [E.renovation_dem_milli(P, n) for n in range(0, P["core"]["renov_max_levels"] + 2)],
                       "upkeep": [E.renovation_upkeep_cents(P, n) for n in range(0, P["core"]["renov_max_levels"] + 2)]}
    G["course_upkeep"] = [[h, p, c, E.course_upkeep_cents(P, h, p, c)] for h, p, c in ((6, 5, 0), (18, 15, 600), (10, 8, 250))]

    est = []
    states = [
        ([0] * 10, 6, 5, 34, 0, 1500, 1000, 1000),
        ([1] * 10, 6, 5, 36, 20000, 900, 1000, 1000),
        ([2, 2, 1, 1, 0, 0, 1, 0, 0, 0], 10, 8, 42, 45000, 2200, 1000, 1000),
        ([3] * 10, 12, 10, 46, 100000, 1600, 900, 1000),
        ([4, 4, 3, 3, 3, 3, 3, 3, 3, 2], 16, 13, 56, 200000, 2800, 1000, 600),
        ([5] * 10, 18, 15, 66, 350000, 4100, 1000, 1000, 0),
        ([5] * 10, 18, 15, 70, 400000, 4100, 1000, 1000, 4),
    ]
    for tiers, h, par, r, mem, fee, rep, ext, *rest in states:
        reno = rest[0] if rest else 0
        d = E.day_estimate(P, UP, tiers, h, par, r, mem, fee, rep, ext, reno)
        est.append({"tiers": tiers, "holes": h, "parcels": par, "rating": r, "members_milli": mem, "fee": fee,
                    "rep": rep, "ext": ext, "renovation": reno, "out": d,
                    "suggest": E.suggest_fee_cents(P, UP, tiers, h, r, rep, reno)})
    G["estimates"] = est

    # scenario A: three ordinary days
    ea = E.Economy(P, UP)
    ea.from_dict({"cash": 3000000, "fee": 1200, "members_milli": 15000, "holes": 8, "rating": 40, "parcels": 7,
                  "tiers": [2, 1, 1, 1, 0, 0, 1, 0, 0, 0]})
    init_a = ea.to_dict()
    rows_a = run_ticks(ea, 33)
    G["scenario_day_cycle"] = {"init": init_a, "rows": rows_a, "final": ea.to_dict()}

    # scenario B: income collapses (course closed: rating 0 and no demand), arrears build, bankruptcy, free loan
    eb = E.Economy(P, UP)
    eb.from_dict({"cash": 150000, "fee": 1500, "holes": 10, "rating": 0, "parcels": 8, "ext_permille": 0, "tiers": [3] * 10})
    init_b = eb.to_dict()
    rows_b = []
    bankrupt_tick = -1
    for i in range(80):
        rows_b += run_ticks(eb, 1)
        if eb.bankrupt:
            bankrupt_tick = i
            break
    opts_b = eb.recovery_options(0)
    opts_b_tokens = eb.recovery_options(5)
    loan = eb.take_bank_loan()
    after_loan = eb.to_dict()
    eb.rating = 40
    eb.ext_permille = 1000
    eb.set_green_fee(900)
    rows_b2 = run_ticks(eb, 22)
    G["scenario_loan"] = {"init": init_b, "rows": rows_b, "bankrupt_tick": bankrupt_tick, "options_no_tokens": opts_b,
                          "options_tokens5": opts_b_tokens, "loan": loan, "after_loan": after_loan, "rows_after": rows_b2,
                          "final": eb.to_dict()}

    # scenario C: same collapse, token recovery instead of the loan
    ec = E.Economy(P, UP)
    ec.from_dict(init_b)
    rows_c = []
    for i in range(80):
        rows_c += run_ticks(ec, 1)
        if ec.bankrupt:
            break
    rc = ec.apply_token_recovery()
    after_c = ec.to_dict()
    ec.rating = 40
    ec.ext_permille = 1000
    ec.set_green_fee(900)
    rows_c2 = run_ticks(ec, 66)
    G["scenario_tokens"] = {"init": init_b, "rows": rows_c, "result": rc, "after": after_c, "rows_after": rows_c2,
                            "final": ec.to_dict(), "token_cost": P["core"]["recovery_token_cost"]}

    # scenario D: late-game renovation sink. Full course, every building at tier 5, cash for two levels and a bit more.
    ed = E.Economy(P, UP)
    c0 = E.renovation_cost_cents(P, 0)
    c1 = E.renovation_cost_cents(P, 1)
    ed.from_dict({"cash": c0 + c1 + 123456, "fee": 4000, "members_milli": 300000, "holes": 18, "rating": 66,
                  "parcels": 15, "tiers": [5] * 10})
    init_d = ed.to_dict()
    e_not = E.Economy(P, UP)
    e_not.from_dict({"cash": 10 ** 9, "holes": 17, "tiers": [5] * 10})
    e_not2 = E.Economy(P, UP)
    e_not2.from_dict({"cash": 10 ** 9, "holes": 18, "tiers": [5] * 9 + [3]})
    r_not = [e_not.purchase_renovation(), e_not2.purchase_renovation()]
    r1 = ed.purchase_renovation()
    after1 = ed.to_dict()
    r2 = ed.purchase_renovation()
    after2 = ed.to_dict()
    r3 = ed.purchase_renovation()            # not enough cash for level 3
    rows_d = run_ticks(ed, 22)
    G["scenario_renovation"] = {"init": init_d, "not_available": r_not, "results": [r1, r2, r3], "after1": after1,
                                "after2": after2, "rows": rows_d, "final": ed.to_dict()}

    G["tier_prices_dollars"] = P["price_dollars"]
    G["spend_cases"] = {"start_cash": P["core"]["start_cash_cents"]}
    dump(OUT_GOLD, G)


if __name__ == "__main__":
    main()
