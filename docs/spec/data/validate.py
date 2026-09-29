#!/usr/bin/env python3
"""Validate every spec example against its JSON Schema (draft 2020-12) plus semantic checks.
Run from anywhere:  python3 docs/spec/data/validate.py
Needs the 'jsonschema' package (4.x). Exit code 0 = all good, 1 = failures.
"""
import json, os, re, sys
try:
    from jsonschema import Draft202012Validator
    from referencing import Registry, Resource
    from referencing.jsonschema import DRAFT202012
except ImportError:
    print("ERROR: needs jsonschema>=4.18 and referencing (pip install jsonschema). Cannot validate without it.")
    sys.exit(1)

HERE = os.path.dirname(os.path.abspath(__file__))
fails = []
def load(n):
    with open(os.path.join(HERE, n), encoding="utf-8") as f: return json.load(f)
def bad(msg): fails.append(msg); print("FAIL", msg)
def ok(msg): print("ok  ", msg)

SCHEMAS = ["course","save","buildings","tournaments","commission_templates","event_cards","remote_config","analytics_catalog","analytics_event","strings"]
schemas = {s: load(s + ".schema.json") for s in SCHEMAS}
reg = Registry()
for s in schemas.values():
    reg = reg.with_resource(s["$id"], Resource.from_contents(s, default_specification=DRAFT202012))
for n, s in schemas.items():
    try: Draft202012Validator.check_schema(s); ok(f"{n}.schema.json is a valid 2020-12 schema")
    except Exception as e: bad(f"{n}.schema.json invalid schema: {e}")

def check(schema, doc, label):
    v = Draft202012Validator(schemas[schema], registry=reg)
    errs = sorted(v.iter_errors(doc), key=lambda e: list(e.absolute_path))
    if errs:
        for e in errs[:8]: bad(f"{label}: {'/'.join(map(str, e.absolute_path))}: {e.message[:200]}")
    else: ok(f"{label} validates against {schema}.schema.json")
    return not errs

def no_floats(o, label, path=""):
    if isinstance(o, float): bad(f"{label}: float at {path}")
    elif isinstance(o, dict): [no_floats(v, label, path + "/" + k) for k, v in o.items()]
    elif isinstance(o, list): [no_floats(v, label, f"{path}[{i}]") for i, v in enumerate(o)]

docs = {"course.example.json": "course", "save.example.json": "save", "buildings.json": "buildings", "tournaments.json": "tournaments",
        "commission_templates.example.json": "commission_templates", "event_cards.example.json": "event_cards",
        "remote_config.example.json": "remote_config", "analytics_catalog.json": "analytics_catalog",
        "analytics_event.example.json": "analytics_event", "strings.example.en.json": "strings"}
loaded = {}
for f, s in docs.items():
    d = load(f); loaded[f] = d; check(s, d, f); no_floats(d, f)

# --- negative tests: things that MUST be rejected
def must_reject(schema, doc, label):
    v = Draft202012Validator(schemas[schema], registry=reg)
    if v.is_valid(doc): bad(f"negative test accepted: {label}")
    else: ok(f"negative test rejected: {label}")
import copy
sv = copy.deepcopy(loaded["save.example.json"]); sv["unlocked"] = True; must_reject("save", sv, "save with an 'unlocked' key")
sv = copy.deepcopy(loaded["save.example.json"]); sv["course"]["holes"][0]["green"]["outline"][0][0] = 1.5; must_reject("save", sv, "float coordinate in embedded course")
sv = copy.deepcopy(loaded["save.example.json"]); sv["course"]["holes"] = [copy.deepcopy(sv["course"]["holes"][0]) for _ in range(19)]; must_reject("save", sv, "19 holes")
c = copy.deepcopy(loaded["course.example.json"]); c["holes"][0]["green"]["outline"][0] = [70000, 5]; must_reject("course", c, "coordinate out of range")
c = copy.deepcopy(loaded["course.example.json"]); c["holes"][0]["score"] = 99; must_reject("course", c, "embedded score in course")
c = copy.deepcopy(loaded["course.example.json"]); c["objects"] = [{"kind": "tree_oak", "pos": [1, 1]}] * 4001; must_reject("course", c, "4001 objects")
e = copy.deepcopy(loaded["analytics_event.example.json"]); e["props"]["player_name"] = "x"; must_reject("analytics_event", e, "PII-like extra prop")
e = copy.deepcopy(loaded["analytics_event.example.json"]); e["props"]["tier"] = 9; must_reject("analytics_event", e, "tier out of range")
r = copy.deepcopy(loaded["remote_config.example.json"]); r["economy"]["start_cash"] = 99999999; must_reject("remote_config", r, "remote config over clamp")
r = copy.deepcopy(loaded["remote_config.example.json"]); r["rating_weights"] = {"beauty": 5}; must_reject("remote_config", r, "rating parameter in remote config")
b = copy.deepcopy(loaded["buildings.json"]); b["buildings"][0]["tiers"][4]["requires"]["specific"] = [{"building": "landmark", "min_tier": 6}]; must_reject("buildings", b, "min_tier 6")

# --- semantic: buildings
B = loaded["buildings.json"]; by = {b["id"]: b for b in B["buildings"]}
if len(by) != 10: bad("buildings: ids not unique")
mult = B["cost_multiplier_x100"]
for b in B["buildings"]:
    for i, t in enumerate(b["tiers"]):
        if t["tier"] != i + 1: bad(f"{b['id']}: tier order")
        if t["cost"] != b["base_cost"] * mult[i] // 100: bad(f"{b['id']} t{t['tier']}: cost != base*multiplier")
    costs = [t["cost"] for t in b["tiers"]]
    if costs != sorted(costs): bad(f"{b['id']}: costs not increasing")
    for t in b["tiers"]:
        r = t["requires"]
        if t["tier"] == 5 and not r["hosted_tournament"]: bad(f"{b['id']}: tier 5 needs a hosted tournament")
        if t["tier"] < 5 and r["hosted_tournament"]: bad(f"{b['id']} t{t['tier']}: only tier 5 may need a tournament")
        for s in r["specific"]:
            if s["building"] == b["id"]: bad(f"{b['id']}: requires itself")
# acyclic: node (building,tier) depends on (other, min_tier) via specific links; any_others handled as 'lower tier of any' (always lower tier => acyclic by tier order)
graph = {}
for b in B["buildings"]:
    for t in b["tiers"]:
        node = (b["id"], t["tier"]); deps = [(s["building"], s["min_tier"]) for s in t["requires"]["specific"]]
        if t["requires"]["any_others"]: 
            if t["requires"]["any_others"]["min_tier"] >= t["tier"]: bad(f"{node}: any_others needs tier >= own tier")
        graph[node] = deps
state = {}
def visit(n, stack):
    if state.get(n) == 2: return
    if state.get(n) == 1: bad(f"prerequisite cycle: {' -> '.join(map(str, stack + [n]))}"); return
    state[n] = 1
    for d in graph[n]: visit(d, stack + [n])
    state[n] = 2
for n in graph: visit(n, [])
# reachability: simulate buying everything in dependency order, ignoring holes/score/members (course gates)
have = {b: 0 for b in by}; prog = True
while prog:
    prog = False
    for b in B["buildings"]:
        nxt = have[b["id"]] + 1
        if nxt > 5: continue
        r = b["tiers"][nxt - 1]["requires"]
        if any(have[s["building"]] < s["min_tier"] for s in r["specific"]): continue
        ao = r["any_others"]
        if ao and sum(1 for o, v in have.items() if o != b["id"] and v >= ao["min_tier"]) < ao["count"]: continue
        have[b["id"]] = nxt; prog = True
if all(v == 5 for v in have.values()): ok("buildings: all 50 tiers reachable (prerequisite graph acyclic, no deadlock)")
else: bad(f"buildings: deadlock, stuck at {have}")

# --- semantic: tournaments (no tier 5 dependency, non-circular with tier 5 gate)
T = loaded["tournaments.json"]
for L in T["levels"]:
    for r in L["entry"]["buildings"]:
        if r["min_tier"] > 4: bad(f"tournament {L['level']}: requires tier > 4 building")
    cap = T["spectator_capacity_by_clubhouse_tier"]
    ch = max(r["min_tier"] for r in L["entry"]["buildings"] if r["building"] == "clubhouse")
    if L["entry"]["min_spectator_capacity"] > cap[ch - 1]: bad(f"tournament {L['level']}: spectator need {L['entry']['min_spectator_capacity']} exceeds Clubhouse tier {ch} capacity {cap[ch-1]}")
    if L["entry"]["min_holes"] > B["hole_cap"]: bad(f"tournament {L['level']}: holes above cap")
if sum(T["prestige"]["weights_permille"].values()) != 1000: bad("tournament prestige weights must sum to 1000")
if T["prestige"]["sustained_min_days"] > T["prestige"]["snapshot_window_days"]: bad("sustained_min_days > snapshot_window_days")
# tier-5 hosted level must be defined
lvls = {L["level"] for L in T["levels"]}
for b in B["buildings"]:
    if b["tiers"][4]["requires"]["hosted_tournament"]["min_level"] not in lvls: bad(f"{b['id']}: tier 5 level missing in tournaments")
ok("tournaments: semantic checks done")

# --- semantic: course example (integer geometry inside world, holes inside owned parcels, sequential hole_no)
C = loaded["course.example.json"]
W = C["world"]
def pts(h):
    for t in h["tees"]: yield t["pos"]
    yield from h["green"]["outline"]; yield from h["green"]["pins"]
    for f in h["fairways"]: yield from f
    for z in h["hazards"]: yield from z["outline"]
owned = [p for p in W["parcels"] if p["owned"]]
for i, h in enumerate(C["holes"]):
    if h["hole_no"] != i + 1: bad("course: hole_no not sequential")
    for x, y in pts(h):
        if not (0 <= x < W["width_dm"] and 0 <= y < W["height_dm"]): bad(f"course hole {h['hole_no']}: point outside world")
        if not any(p["x0"] <= x <= p["x1"] and p["y0"] <= y <= p["y1"] for p in owned): bad(f"course hole {h['hole_no']}: point ({x},{y}) not on an owned parcel")
tr = C["terrain"]
if tr["width_cells"] * tr["cell_size_dm"] < W["width_dm"] or tr["height_cells"] * tr["cell_size_dm"] < W["height_dm"]: bad("course: terrain grid smaller than world")
ok("course example: geometry semantic checks done")

# --- semantic: analytics catalog and event schema stay in sync; no banned prop names
cat = loaded["analytics_catalog.json"]; evs = {e["name"]: e for e in cat["events"]}
if set(evs) != set(schemas["analytics_event"]["properties"]["name"]["enum"]): bad("analytics: event schema names differ from catalog")
for blk in schemas["analytics_event"]["allOf"]:
    n = blk["if"]["properties"]["name"]["const"]; th = blk["then"]["properties"]["props"]
    if th["properties"] != evs[n]["props"] or th["required"] != evs[n]["required"]: bad(f"analytics: schema/catalog mismatch for {n}")
BANNED = re.compile(r"(name|email|phone|address|lat|lon|gps|ip|advert|imei|android_?id|idfa|gaid|text|message|comment)", re.I)
for n, e in evs.items():
    for p in e["props"]:
        if BANNED.search(p) and p not in ("card_id",): bad(f"analytics {n}.{p}: banned-looking property name")
        if e["props"][p].get("type") == "string" and "pattern" not in e["props"][p]: bad(f"analytics {n}.{p}: unbounded string")
    for r in e["required"]:
        if r not in e["props"]: bad(f"analytics {n}: required {r} not in props")
ok("analytics: catalog/schema sync and privacy name checks done")

# --- semantic: strings
S = loaded["strings.example.en.json"]
LIMITS = {"ui.button": 16, "ui.title": 32, "building": 32, "advisor": 120, "card": 300, "toast": 80}
for k, v in S["strings"].items():
    if len(v["text"]) > v["max"]: bad(f"strings {k}: {len(v['text'])} > max {v['max']}")
    found = sorted(set(re.findall(r"\{([a-z][a-z0-9_]*)\}", v["text"])))
    if found != sorted(v.get("placeholders", [])): bad(f"strings {k}: placeholders {found} != declared {v.get('placeholders', [])}")
    if re.search(r"\s\s|^\s|\s$|—", v["text"]): bad(f"strings {k}: double space, edge space or em dash")
ok("strings: length and placeholder checks done")

# --- unit sanity: no bare 'unlocked' or 'entitlement' key anywhere in save schema properties
if re.search(r'"(unlocked|entitlement|is_paid|premium)"', json.dumps(schemas["save"]["properties"])): bad("save schema must not carry entitlement fields")
else: ok("save schema carries no entitlement field")

print("\nRESULT:", "FAIL (%d)" % len(fails) if fails else "ALL PASS")
sys.exit(1 if fails else 0)
