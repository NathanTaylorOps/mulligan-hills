"""Self checks for the staff reference. Run:  python3 tools/reference/staff/selftest.py   (about 2 seconds)."""
import json
import os
import random
import sys

import mh_staff as S

fails = []


def check(cond, msg):
    if not cond:
        fails.append(msg)
        print("FAIL", msg)


D = S.load_data()
d = S.Defs(D)
TOURN = json.load(open(os.path.join(S.ROOT, "docs", "spec", "data", "tournaments.json")))
BUILD = json.load(open(os.path.join(S.ROOT, "docs", "spec", "data", "buildings.json")))
BIDS = [b["id"] for b in BUILD["buildings"]]

# data shape
check(len(d.role_ids) == len(set(d.role_ids)), "role ids unique")
for r in D["roles"]:
    check(r["building"] in BIDS, "role building known: " + r["id"])
    check(r["caps_by_tier"] == sorted(r["caps_by_tier"]), "caps non-decreasing: " + r["id"])
    check(r["daily_wage_cents"] > 0, "wage positive: " + r["id"])
check({r["building"] for r in D["roles"]} == set(BIDS), "every one of the 10 buildings has at least one role")
check(D["grid"] == {"cols": BUILD["land"]["grid"]["cols"], "rows": BUILD["land"]["grid"]["rows"]}, "grid equals buildings.json land grid")
check(S.land_kinds() == [p["kind"] for p in BUILD["land"]["parcels"]], "kinds from buildings.json")
check(set(D["decay_by_parcel_kind"]) == {"golf", "facility", "homes"}, "decay kinds")
check(D["params"]["cond_hard_floor"] <= D["params"]["cond_untended_floor"] <= D["params"]["cond_start"], "condition limits ordered")

# the tournament staff gate can be met using only the buildings that level requires, at their required tiers (DEC-027:
# a tier 5 building is never needed, and no circular gate exists)
for L in TOURN["levels"]:
    tiers = {b["building"]: b["min_tier"] for b in L["entry"]["buildings"]}
    cap_total = 0
    for rid in d.role_ids:
        cap_total += d.cap(rid, tiers.get(d.roles[rid]["building"], 0))
    check(cap_total >= L["entry"]["min_staff"], "gate %s: max head count %d >= min_staff %d" % (L["level"], cap_total, L["entry"]["min_staff"]))
    print("gate %-8s min_staff %2d reachable with required buildings only: %2d" % (L["level"], L["entry"]["min_staff"], cap_total))
all5 = {b: 5 for b in BIDS}
total_cap = sum(d.cap(r, 5) for r in d.role_ids)
check(total_cap <= D["params"]["max_employees"], "all caps fit max_employees")
print("max head count with every building at tier 5:", total_cap)

# wages
for x in (0, 1, 7, 10, 12345, 999999):
    check(sum(S.split_hour(x, h) for h in range(11)) == x, "split sums to %d" % x)
st = S.Staff()
v = S.make_view({"maintenance": 3, "clubhouse": 3})
st.hire("groundskeeper", 0, v, 10**9)
check(sum(st.hour_wage(h) for h in range(11)) == st.payroll(), "hour wages sum to payroll")
check(d.wage("groundskeeper", 0) == 2200 and d.wage("groundskeeper", 20) == 2750 and d.wage("groundskeeper", 60) == 3300, "grade wages")

# gate head count needs tenure
st = S.Staff()
st.hire("marshal", 0, v, 10**9)
check(st.gate_count(v) == 0, "fresh hire does not count for the gate")
for day in range(1, 4):
    st.on_day(day, v, 1)
check(st.gate_count(v) == 1, "hire counts after tenure_gate_days")

# legacy counters sum to head count
st = S.Staff()
vv = S.make_view(dict((b, 5) for b in BIDS))
for rid in d.role_ids:
    for _ in range(3):
        st.hire(rid, 0, vv, 10**9)
lc = st.legacy_counts()
check(sum(lc.values()) == len(st.employees), "legacy counts sum to head count")
check(all(0 <= x <= 200 for x in lc.values()), "legacy counts within schema max 200")

# determinism and idempotence
a = S.Staff(); b = S.Staff()
va = S.make_view({"maintenance": 3}, [5, 6, 9, 10, 8])
for s_ in (a, b):
    s_.hire("groundskeeper", 0, va, 10**9)
    s_.hire("wildlife_ranger", 0, va, 10**9)
    s_.auto_assign(va)
    for day in range(1, 50):
        s_.on_day(day, va, 777)
check(a.state_list() == b.state_list(), "replay is deterministic")
before = a.state_list()
r = a.on_day(49, va, 777)
check((not r["ran"]) and a.state_list() == before, "same day twice is ignored")

# personal work caps
st = S.Staff()
v2 = S.make_view({}, [5, 6])
st.cond[5] = 100
g1 = st.personal_mow(5, 1024, 1024, v2)
g2 = st.personal_mow(5, 1024, 1024, v2)
g3 = st.personal_mow(5, 1024, 1024, v2)
check((g1, g2, g3) == (300, 300, 0), "personal mow capped at 600 a day: %s" % ((g1, g2, g3),))
st.on_day(1, v2, 5)
check(st.personal_mow(5, 1024, 1024, v2) > 0, "personal cap resets next day")
check(st.personal_mow(4, 1024, 1024, v2) == 0, "personal mow on an unowned parcel does nothing")

# fuzz: bounds hold under random play
rnd = random.Random(99)
for trial in range(40):
    st = S.Staff()
    owned = rnd.sample(range(16), rnd.randint(1, 16))
    tiers = {b: rnd.randint(0, 5) for b in BIDS}
    view = S.make_view(tiers, owned)
    for day in range(1, 80):
        for _ in range(rnd.randint(0, 3)):
            act = rnd.randint(0, 5)
            if act == 0:
                st.hire(rnd.choice(d.role_ids), day, view, rnd.choice([0, 10**5, 10**8]))
            elif act == 1 and st.employees:
                st.fire(rnd.choice(st.employees)["serial"])
            elif act == 2 and st.employees:
                e = rnd.choice(st.employees)
                st.assign(e["serial"], rnd.sample(owned, min(len(owned), rnd.randint(0, 6))), view)
            elif act == 3:
                st.auto_assign(view)
            elif act == 4:
                st.personal_mow(rnd.randint(-1, 16), rnd.randint(-5, 2000), 1024, view)
            else:
                st.personal_patrol(rnd.randint(-1, 16), rnd.randint(-5, 2000), 1024, view)
        if rnd.random() < 0.1:
            view = S.make_view({b: rnd.randint(0, 5) for b in BIDS}, rnd.sample(range(16), rnd.randint(1, 16)))
        st.on_day(day, view, rnd.randint(0, 2**32 - 1))
        ok = all(0 <= c <= 1000 for c in st.cond) and all(0 <= p <= 1000 for p in st.pest)
        ok = ok and all(0 <= x <= 600 for x in st.pw) and all(0 <= x <= 400 for x in st.pp)
        if not ok:
            check(False, "fuzz bounds trial %d day %d" % (trial, day))
            break
        dm = st.demand_permille(view)
        check(D["params"]["demand_min"] <= dm <= D["params"]["demand_max"], "demand within clamp")
        check(st.payroll() >= 0 and st.pace_points() <= 15, "payroll non-negative, pace <= 15")
        check(0 <= st.condition_penalty_permille(view) <= D["params"]["sat_pen_max"], "penalty within bounds")

# cell to parcel mapping covers the grid evenly on the development patch
cnt = [0] * 16
for cy in range(128):
    for cx in range(128):
        cnt[S.parcel_of_cell(cx, cy, 128, 128, 4, 4)] += 1
check(cnt == [1024] * 16, "128x128 patch: every parcel gets 1024 cells")

print("\nRESULT:", "FAIL (%d)" % len(fails) if fails else "ALL PASS")
sys.exit(1 if fails else 0)
