"""Generate the data copy and the golden vectors for the GDScript staff module.
Run from anywhere:  python3 tools/reference/staff/gen_golden.py
Writes:
  game/data/staff.json                          (byte copy of docs/spec/data/staff.json)
  game/tests/staff/golden/staff_golden.json     (vectors the gdUnit4 tests compare against)
Scenarios are lists of operations. The GDScript test interprets the same operations through MHStaff and compares every
recorded result and state vector, so a divergence in any rule shows up as a failing op index."""
import json
import os
import shutil

import mh_staff as S

ROOT = S.ROOT
OUT_DATA = os.path.join(ROOT, "game", "data", "staff.json")
OUT_GOLD = os.path.join(ROOT, "game", "tests", "staff", "golden", "staff_golden.json")

ALL5 = {b: 5 for b in ("clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn", "maintenance", "lodging", "homes", "landmark")}


def agg(st, view):
    ov = st.overlay(view)
    return [st.demand_permille(view), st.pace_points(), st.gate_count(view), st.condition_penalty_permille(view),
            ov["beauty_delta_pm"], ov["fairness_delta_pm"], st.payroll(), st.avg_cond(view), st.avg_pest(view),
            st.service_avg(view), len(st.employees)]


def run_scenario(name, ops, view0, secret):
    st = S.Staff()
    view = {"tiers": dict(view0["tiers"]), "owned": list(view0["owned"]), "kinds": S.land_kinds()}
    rows = []
    for op in ops:
        k = op["op"]
        row = {"op": op}
        if k == "view":
            view = {"tiers": dict(op["tiers"]), "owned": list(op["owned"]), "kinds": S.land_kinds()}
            row["r"] = 0
        elif k == "hire":
            r = st.hire(op["role"], op["day"], view, op["cash"])
            row["r"] = [1 if r["ok"] else 0, r["reason"], r["serial"], r["cost"]]
        elif k == "fire":
            row["r"] = 1 if st.fire(op["serial"]) else 0
        elif k == "assign":
            row["r"] = st.assign(op["serial"], op["areas"], view)
        elif k == "auto":
            row["r"] = st.auto_assign(view)
        elif k == "mow":
            row["r"] = st.personal_mow(op["parcel"], op["cells"], op["cpp"], view)
        elif k == "patrol":
            row["r"] = st.personal_patrol(op["parcel"], op["cells"], op["cpp"], view)
        elif k == "pay":
            row["r"] = st.pay_hour(op["hour"])
        elif k == "day":
            res = st.on_day(op["day"], view, secret)
            row["r"] = [1 if res["ran"] else 0, [[i["parcel"], i["kind"], 1 if i["positive"] else 0, 1 if i["handled"] else 0] for i in res["incidents"]]]
            row["s"] = st.state_list()
            row["a"] = agg(st, view)
        else:
            raise ValueError(k)
        rows.append(row)
    return {"name": name, "secret": secret, "view": {"tiers": view0["tiers"], "owned": view0["owned"]}, "ops": rows,
            "final_block": st.to_block(), "final_agg": agg(st, view)}


def days(a, b):
    return [{"op": "day", "day": d} for d in range(a, b + 1)]


def scen_starter():
    cash = 10_000_00
    ops = [{"op": "hire", "role": "groundskeeper", "day": 0, "cash": cash},
           {"op": "hire", "role": "groundskeeper", "day": 0, "cash": cash},
           {"op": "hire", "role": "marshal", "day": 0, "cash": cash},
           {"op": "hire", "role": "wildlife_ranger", "day": 0, "cash": cash},   # no: maintenance tier 1 caps rangers at 0
           {"op": "hire", "role": "caddie", "day": 0, "cash": cash},          # no: no cart barn
           {"op": "hire", "role": "marshal", "day": 0, "cash": 1000},         # no: role_cap (the cash check is a unit test)
           {"op": "auto"},
           {"op": "assign", "serial": 3, "areas": [5]},                       # marshal is not an area role
           {"op": "assign", "serial": 1, "areas": [5, 6, 99]},
           {"op": "assign", "serial": 1, "areas": [5, 5]},
           {"op": "assign", "serial": 1, "areas": [4]},                       # not owned
           {"op": "assign", "serial": 9, "areas": [5]},
           {"op": "assign", "serial": 1, "areas": [5, 6, 9, 10]},
           {"op": "assign", "serial": 2, "areas": [8]}]
    for h in (0, 5, 10):
        ops.append({"op": "pay", "hour": h})
    ops += days(1, 6)
    ops += [{"op": "mow", "parcel": 8, "cells": 512, "cpp": 1024}, {"op": "mow", "parcel": 8, "cells": 4096, "cpp": 1024}, {"op": "mow", "parcel": 4, "cells": 1024, "cpp": 1024},
            {"op": "patrol", "parcel": 8, "cells": 1024, "cpp": 1024}, {"op": "patrol", "parcel": 9, "cells": 1024, "cpp": 1024}]
    ops += days(7, 7)
    ops += [{"op": "view", "tiers": {"maintenance": 2, "clubhouse": 2, "cart_barn": 1}, "owned": [1, 4, 5, 6, 8, 9, 10]},
            {"op": "hire", "role": "wildlife_ranger", "day": 7, "cash": cash},
            {"op": "hire", "role": "caddie", "day": 7, "cash": cash},
            {"op": "hire", "role": "groundskeeper", "day": 7, "cash": cash},
            {"op": "hire", "role": "groundskeeper", "day": 7, "cash": cash},    # third keeper, cap at maintenance 2 is 3
            {"op": "hire", "role": "groundskeeper", "day": 7, "cash": cash},    # no: role_cap
            {"op": "auto"},
            {"op": "fire", "serial": 3}, {"op": "fire", "serial": 3}]
    ops += days(8, 50)
    ops += days(30, 31)    # replayed days are ignored
    return run_scenario("starter", ops, {"tiers": {"maintenance": 1, "clubhouse": 1}, "owned": [5, 6, 8, 9, 10]}, 123456789)


def scen_neglect():
    ops = days(1, 60)
    return run_scenario("neglect", ops, {"tiers": {}, "owned": [5, 6, 8, 9, 10]}, 0x5EED1234)


def scen_personal():
    ops = []
    for d in range(1, 41):
        if d % 3 == 1:
            for p in (5, 6, 9, 10):
                ops.append({"op": "mow", "parcel": p, "cells": 1024, "cpp": 1024})
        if d % 4 == 0:
            ops.append({"op": "patrol", "parcel": 6, "cells": 700, "cpp": 1024})
        ops.append({"op": "day", "day": d})
    return run_scenario("personal", ops, {"tiers": {}, "owned": [5, 6, 8, 9, 10]}, 424242)


def scen_rangers():
    """Three rangers on ten golf parcels (parcels 4, 7, 11 single covered at exactly handled_min_control, parcel 0 uncovered), no keepers: pest climbs, incidents are handled or not."""
    cash = 10**9
    ops = [{"op": "hire", "role": "wildlife_ranger", "day": 0, "cash": cash} for _ in range(3)]
    ops += [{"op": "hire", "role": "wildlife_ranger", "day": 0, "cash": cash}]          # no: role_cap 3 at maintenance 4
    ops += [{"op": "assign", "serial": 1, "areas": [1, 2, 4, 5, 6]}, {"op": "assign", "serial": 2, "areas": [5, 6, 7, 9, 10]}, {"op": "assign", "serial": 3, "areas": [9, 10, 11, 1, 2]}]
    ops += days(1, 90)
    return run_scenario("rangers", ops, {"tiers": {"maintenance": 4}, "owned": [0, 1, 2, 4, 5, 6, 7, 9, 10, 11]}, 20261005)


def scen_late():
    cash = 10**9
    ops = []
    roles = ["groundskeeper", "wildlife_ranger", "marshal", "caddie", "pro_shop_assistant", "range_attendant", "server", "spa_attendant", "housekeeper", "concierge", "guide"]
    for r in roles:
        for _ in range(9):
            ops.append({"op": "hire", "role": r, "day": 0, "cash": cash})
    ops.append({"op": "auto"})
    for h in range(0, 11):
        ops.append({"op": "pay", "hour": h})
    ops += days(1, 75)
    ops.append({"op": "view", "tiers": dict(ALL5, maintenance=3), "owned": list(range(16))})
    ops += days(76, 80)
    return run_scenario("late", ops, {"tiers": ALL5, "owned": list(range(16))}, 987654321)


def main():
    shutil.copyfile(S.DATA_PATH, OUT_DATA)
    print("wrote", os.path.relpath(OUT_DATA, ROOT))
    D = S.load_data()
    d = S.Defs(D)
    G = {"kinds": S.land_kinds()}
    G["split"] = [[x, [S.split_hour(x, h) for h in range(S.HOURS_PER_DAY)]] for x in (0, 1, 7, 10, 12345, 999999)]
    G["h32"] = [[sec, day, parcel, S.H32(sec, day, parcel, S.INCIDENT_SALT)] for sec, day, parcel in ((1, 1, 0), (123456789, 7, 5), (0x5EED1234, 30, 15), (0xFFFFFFFF, 1000, 9), (0, 0, 0))]
    G["wage"] = [[rid, t, d.wage(rid, t)] for rid in d.role_ids for t in (0, 19, 20, 59, 60, 400)]
    G["hire_cost"] = [[rid, d.hire_cost(rid)] for rid in d.role_ids]
    G["caps"] = [[rid] + [d.cap(rid, t) for t in range(0, 6)] for rid in d.role_ids]
    G["parcel_of_cell"] = [[cx, cy, w, h, S.parcel_of_cell(cx, cy, w, h, 4, 4)] for cx, cy, w, h in
                           ((0, 0, 128, 128), (31, 31, 128, 128), (32, 0, 128, 128), (127, 127, 128, 128), (64, 96, 128, 128), (128, 5, 128, 128), (-1, 5, 128, 128),
                            (50, 70, 200, 300), (199, 299, 200, 300), (5, 5, 3, 3))]
    G["scenarios"] = [scen_starter(), scen_neglect(), scen_personal(), scen_rangers(), scen_late()]
    os.makedirs(os.path.dirname(OUT_GOLD), exist_ok=True)
    with open(OUT_GOLD, "w", newline="\n") as f:
        json.dump(G, f, separators=(",", ":"))
        f.write("\n")
    print("wrote", os.path.relpath(OUT_GOLD, ROOT), os.path.getsize(OUT_GOLD), "bytes")
    for sc in G["scenarios"]:
        fa = sc["final_agg"]
        inc = [r for r in sc["ops"] if r["op"]["op"] == "day"]
        n_inc = sum(len(r["r"][1]) for r in inc)
        print("  %-9s ops %3d incidents %3d final agg demand %d pace %d gate %d penalty %d payroll %d cond %d pest %d service %d staff %d" % (
            sc["name"], len(sc["ops"]), n_inc, fa[0], fa[1], fa[2], fa[3], fa[6], fa[7], fa[8], fa[9], fa[10]))


if __name__ == "__main__":
    main()
