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

SCHEMAS = ["course","save","buildings","tournaments","commission_templates","event_cards","remote_config","analytics_catalog","analytics_event","strings",
           "achievements","daily_challenges","progression","staff"]
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

docs = {"one_hole_save.example.json": "save", "live_save.example.json": "save", "course.example.json": "course", "save.example.json": "save", "buildings.json": "buildings", "tournaments.json": "tournaments",
        "commission_templates.example.json": "commission_templates", "event_cards.example.json": "event_cards",
        "remote_config.example.json": "remote_config", "analytics_catalog.json": "analytics_catalog",
        "analytics_event.example.json": "analytics_event", "strings.example.en.json": "strings",
        "event_cards.json": "event_cards", "achievements.json": "achievements", "daily_challenges.json": "daily_challenges",
        "progression.json": "progression", "staff.json": "staff"}
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

# Reader-2 exact accounting fixture; independent schema rejection checks.
for path, value, label in [(('min_reader_version',),1,'runtime with old reader'), (('runtime','economy','loan_balance'),-1,'negative live loan'), (('runtime','clock','paused'),1,'numeric pause'), (('runtime','economy','cash'),1.5,'fractional live cents'), (('runtime','clock','speed'),3,'unsupported live speed')]:
    sv = copy.deepcopy(loaded['live_save.example.json'])
    target = sv
    for key in path[:-1]: target = target[key]
    target[path[-1]] = value
    must_reject('save', sv, label)
sv = copy.deepcopy(loaded['live_save.example.json']); del sv['runtime']['ledger_hash']; must_reject('save', sv, 'missing ledger generation hash')

# Reader-3 exact primitive/practice examples.
sv = copy.deepcopy(loaded['one_hole_save.example.json']); sv['min_reader_version'] = 2; must_reject('save', sv, 'primitive layout with reader 2')
sv = copy.deepcopy(loaded['one_hole_save.example.json']); sv['course']['schema_version'] = 1; must_reject('save', sv, 'primitive layout under polygon course v1')
sv = copy.deepcopy(loaded['one_hole_save.example.json']); sv['runtime']['practice']['skill'] = 1001; must_reject('save', sv, 'practice skill over limit')
sv = copy.deepcopy(loaded['one_hole_save.example.json']); sv['course']['holes'][0]['layout']['features'][0]['circle'] = [0,30,5]; must_reject('save', sv, 'ambiguous area rect plus circle')

# --- semantic: buildings
B = loaded["buildings.json"]; by = {b["id"]: b for b in B["buildings"]}
if len(by) != 10: bad("buildings: ids not unique")
GATE_SCORES = [0, 32, 42, 52, 62]; GATE_HOLES = [0, 6, 10, 14, 18]
LIGHT_PARCELS = [5, 5, 8, 11, 14]
DEMO_CAPS = {"clubhouse": 2, "pro_shop": 2, "driving_range": 2, "restaurant": 1}
for b in B["buildings"]:
    for i, t in enumerate(b["tiers"]):
        if t["tier"] != i + 1: bad(f"{b['id']}: tier order")
        if "cost" in t or "base_cost" in b: bad(f"{b['id']} t{t['tier']}: fixed cost present, DEC-050 uses target_payback_days")
        r = t["requires"]
        if r["min_avg_hole_score"] != GATE_SCORES[i]: bad(f"{b['id']} t{t['tier']}: score gate {r['min_avg_hole_score']} != {GATE_SCORES[i]} (DEC-048)")
        if r["min_holes"] != GATE_HOLES[i]: bad(f"{b['id']} t{t['tier']}: hole gate {r['min_holes']} != {GATE_HOLES[i]}")
        want_p = LIGHT_PARCELS[i] + (B["land"]["heavy_extra_parcels"] if b["land_class"] == "heavy" and t["tier"] >= 2 else 0)
        if r["min_parcels_owned"] != want_p: bad(f"{b['id']} t{t['tier']}: min_parcels_owned {r['min_parcels_owned']} != {want_p} (DEC-056 heavy +1 at tiers 2-5)")
    pays = [t["target_payback_days"] for t in b["tiers"]]
    if pays != sorted(pays): bad(f"{b['id']}: target_payback_days must not decrease with tier")
    if b["demo_max_tier"] != DEMO_CAPS.get(b["id"], 0): bad(f"{b['id']}: demo_max_tier {b['demo_max_tier']} != DEC-055 {DEMO_CAPS.get(b['id'], 0)}")
    if b.get("needs_parcel_kind") != ("homes" if b["id"] == "homes" else None): bad(f"{b['id']}: needs_parcel_kind belongs on homes only")
    if ("home_slots" in b) != (b["id"] == "homes"): bad(f"{b['id']}: home_slots belongs on homes only")
if {b["id"] for b in B["buildings"] if b["land_class"] == "heavy"} != {"driving_range", "pool_spa", "lodging", "homes", "landmark"}: bad("heavy set must be driving_range, pool_spa, lodging, homes, landmark (DEC-056)")
if B["demo"]["max_holes"] != 9: bad("demo max_holes must be 9 (DEC-055)")
# land layout
L = B["land"]; P = L["parcels"]
if [p["id"] for p in P] != list(range(16)): bad("land: parcel ids must be 0..15 in order")
for k, n in (("golf", L["golf_parcels"]), ("facility", L["facility_parcels"]), ("homes", L["homes_parcels"])):
    if sum(1 for p in P if p["kind"] == k) != n: bad(f"land: {k} parcel count != {n}")
if (L["golf_parcels"], L["facility_parcels"], L["homes_parcels"]) != (12, 2, 2): bad("land: must be 12 golf, 2 facility, 2 homes (DEC-056)")
if L["golf_parcels"] * L["holes_per_two_golf_parcels"] // 2 != B["hole_cap"]: bad("land: all golf parcels must hold exactly hole_cap holes")
if L["homes_parcels"] * L["home_slots_per_homes_parcel"] != B["buildings"][8]["home_slots"]["max_slots"]: bad("land: homes parcels x slots != homes max_slots")
if any(p["col"] != p["id"] % L["grid"]["cols"] or p["row"] != p["id"] // L["grid"]["cols"] for p in P): bad("land: col/row must be id-derived (row-major)")
own = {p["id"] for p in P if p["start_owned"]}
if len(own) != L["start_parcels"]: bad("land: start_owned count != start_parcels")
if sum(1 for p in P if p["start_owned"] and p["kind"] == "golf") * L["holes_per_two_golf_parcels"] // 2 != 6: bad("land: start plot must hold 6 holes (DEC-056)")
def nbrs(i): 
    c, r = i % L["grid"]["cols"], i // L["grid"]["cols"]
    return [rr * L["grid"]["cols"] + cc for cc, rr in ((c+1, r), (c-1, r), (c, r+1), (c, r-1)) if 0 <= cc < L["grid"]["cols"] and 0 <= rr < L["grid"]["rows"]]
seen = {min(own)}; fr = [min(own)]
while fr:
    x = fr.pop()
    for y in nbrs(x):
        if y in own and y not in seen: seen.add(y); fr.append(y)
if seen != own: bad("land: start plot must be one connected block")
ok("buildings: gates, payback, heavy parcels, demo caps and land layout match DEC-048/050/055/056")
# runtime copy shipped in the game (docs/ and tests/ are not exported to Android)
COPY = os.path.join(HERE, "..", "..", "..", "game", "data", "buildings.json")
if not os.path.exists(COPY): bad("game/data/buildings.json (runtime copy) missing")
else:
    with open(COPY, encoding="utf-8") as f1, open(os.path.join(HERE, "buildings.json"), encoding="utf-8") as f2:
        if json.load(f1) != json.load(f2): bad("game/data/buildings.json differs from docs/spec/data/buildings.json")
        else: ok("game/data/buildings.json equals docs/spec/data/buildings.json")
# every building (this loop used to run on the last building only)
for b in B["buildings"]:
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

# --- negative tests: save fields added after the first v1 files (all optional, v1 files stay valid) and ironman (DEC-058)
sv = copy.deepcopy(loaded["save.example.json"]); sv["ironman"] = True; must_reject("save", sv, "ironman true (DEC-058)")
sv = copy.deepcopy(loaded["save.example.json"]); sv["slot_kind"] = "ironman"; must_reject("save", sv, "slot_kind ironman (DEC-058)")
sv = copy.deepcopy(loaded["save.example.json"]); sv["world"]["minute_of_day"] = 660; must_reject("save", sv, "minute_of_day 660 (day has 660 minutes, 0..659)")
sv = copy.deepcopy(loaded["save.example.json"]); sv["progress"]["stats"]["unlocked_everything"] = 1; must_reject("save", sv, "unknown progress.stats key")
sv = copy.deepcopy(loaded["save.example.json"]); sv["progress"]["stats"]["level"] = 1.5; must_reject("save", sv, "float in progress.stats")
sv = copy.deepcopy(loaded["save.example.json"]); sv["progress"]["daily"]["best_pm"] = 1001; must_reject("save", sv, "daily best_pm over 1000")
sv = copy.deepcopy(loaded["save.example.json"]); sv["progress"]["daily"]["board"] = [{"day": 1, "score_pm": 1, "fairness_pm": 1}] * 91; must_reject("save", sv, "daily board over 90 rows")
sv = copy.deepcopy(loaded["save.example.json"]); sv["progress"]["streak"]["last_day"] = -2; must_reject("save", sv, "streak last_day below -1")
# a legacy v1 save written before those fields existed must still validate
sv = copy.deepcopy(loaded["save.example.json"])
sv["ironman"] = False; del sv["world"]["minute_of_day"]
for k in ("playtime_s", "stats", "streak", "daily"): del sv["progress"][k]
for k in ("hosted_count", "attempted_count"): del sv["progress"]["tournaments"][k]
check("save", sv, "legacy v1 save (ironman false, none of the later optional fields)")
# stats keys equal the achievement stat enum plus bonus_prestige
def _find_stat_enum(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "enum" and isinstance(v, list) and "holes_max" in v: return v
            r = _find_stat_enum(v)
            if r: return r
    elif isinstance(o, list):
        for v in o:
            r = _find_stat_enum(v)
            if r: return r
    return None
stat_enum = _find_stat_enum(schemas["achievements"])
if set(schemas["save"]["properties"]["progress"]["properties"]["stats"]["properties"]) != set(stat_enum) | {"bonus_prestige"}:
    bad("save progress.stats keys differ from the achievement stat enum plus bonus_prestige")
else: ok("save progress.stats keys equal the achievement stat enum plus bonus_prestige")

# --- semantic: event cards (the full file, not only the example)
EC = loaded["event_cards.json"]; ids = [c["id"] for c in EC["cards"]]
if len(ids) != len(set(ids)): bad("event_cards: duplicate card ids")
if len(ids) < 40: bad(f"event_cards: {len(ids)} cards, DEC-043 wants about 40 at launch")
EC_OPS = {"add_cash", "add_reputation", "add_members", "add_prestige", "set_flag", "clear_flag", "weather_next_day", "golfer_flow_pct"}
for c in EC["cards"]:
    if c["weight"] < 1: bad(f"event card {c['id']}: weight below 1")
    if len({ch["id"] for ch in c["choices"]}) != len(c["choices"]): bad(f"event card {c['id']}: duplicate choice ids")
    for ch in c["choices"]:
        for e in ch["effects"]:
            if e["op"] not in EC_OPS: bad(f"event card {c['id']}/{ch['id']}: unknown effect op {e['op']}")
    if c["id"] not in c["title_key"]: bad(f"event card {c['id']}: title_key does not contain the id")
ECS = json.load(open(os.path.join(HERE, "..", "..", "..", "game", "core", "events", "event_cards_strings_en.json"), encoding="utf-8"))["strings"]
for c in EC["cards"]:
    for k in [c["title_key"], c["body_key"]] + [x for ch in c["choices"] for x in (ch["label_key"], ch["outcome_key"])]:
        if k not in ECS: bad(f"event card {c['id']}: no draft string for {k}")
        elif len(ECS[k]["text"]) > {"title": 28, "body": 300}.get(k.rsplit(".", 1)[1], 160 if k.endswith("_out") else 40): bad(f"event string {k}: {len(ECS[k]['text'])} chars is over the localization limit")
ok(f"event_cards.json: {len(ids)} cards, unique ids, known effect ops, every text key has a draft string within the length limits")

# --- semantic + negative: staff (docs/spec/staff.md)
ST = loaded["staff.json"]
if {r["building"] for r in ST["roles"]} != {b["id"] for b in B["buildings"]}: bad("staff: roles must cover all 10 buildings")
if len({r["id"] for r in ST["roles"]}) != len(ST["roles"]): bad("staff: duplicate role ids")
if ST["grid"] != B["land"]["grid"] and (ST["grid"]["cols"], ST["grid"]["rows"]) != (B["land"]["grid"]["cols"], B["land"]["grid"]["rows"]): bad("staff: grid differs from the buildings land grid")
for r in ST["roles"]:
    if r["caps_by_tier"] != sorted(r["caps_by_tier"]): bad(f"staff: {r['id']} caps must not decrease with tier")
    if r["daily_wage_cents"] <= 0: bad(f"staff: {r['id']} wage must be positive")
T = loaded["tournaments.json"]
need_staff = max(l["entry"]["min_staff"] for l in T["levels"])
reach = sum(max(r["caps_by_tier"]) for r in ST["roles"])
if reach < need_staff: bad(f"staff: caps sum {reach} cannot reach the highest tournament min_staff {need_staff} (DEC-027 no circular gate)")
tg = [g["min_tenure_days"] for g in ST["grades"]]
if tg != sorted(set(tg)) or tg[0] != 0: bad("staff: grade tenure must rise strictly from 0")
if not (0 < ST["params"]["tenure_gate_days"] <= 30): bad("staff: tenure_gate_days out of range")
SS = json.load(open(os.path.join(HERE, "..", "..", "..", "game", "core", "staff", "staff_strings_en.json"), encoding="utf-8"))["strings"]
keys = [g["name_key"] for g in ST["grades"]] + [r["name_key"] for r in ST["roles"]] + [k["name_key"] for k in ST["incident_kinds"] + ST["sighting_kinds"] if "name_key" in k]
for k in keys:
    if k not in SS: bad(f"staff: no draft string for {k}")
    elif "\u2014" in SS[k]["text"]: bad(f"staff string {k} contains an em dash")
sv = copy.deepcopy(loaded["save.example.json"])
if "staff_roster" in sv["club"]: bad("save.example.json should stay a legacy save without staff_roster (proves the field is optional)")
sr = {"v": 1, "next_serial": 3, "last_day": 4, "employees": [{"serial": 1, "role": "groundskeeper", "hired_day": 0, "tenure": 4, "areas": [5, 6]}],
      "condition": [600]*16, "pest": [0]*16, "personal_work": [0]*16, "personal_pest": [0]*16,
      "stats": {"hires": 1, "fires": 0, "wages_cents": 8800, "incidents_hit": 0, "incidents_handled": 0, "sightings": 0}}
sv["club"]["staff_roster"] = copy.deepcopy(sr); check("save", sv, "save.example.json with a staff_roster block")
sv2 = copy.deepcopy(sv); sv2["club"]["staff_roster"]["condition"] = [600]*15; must_reject("save", sv2, "staff_roster with 15 parcels")
sv2 = copy.deepcopy(sv); sv2["club"]["staff_roster"]["employees"][0]["areas"] = [5, 5]; must_reject("save", sv2, "staff_roster duplicate areas")
sv2 = copy.deepcopy(sv); sv2["club"]["staff_roster"]["pest"][0] = 1001; must_reject("save", sv2, "staff_roster pest over 1000")
sv2 = copy.deepcopy(sv); sv2["club"]["staff_roster"]["employees"][0]["wage"] = 1; must_reject("save", sv2, "staff_roster employee with an extra key")
sv2 = copy.deepcopy(sv); sv2["club"]["staff_roster"]["stats"]["wages_cents"] = 1.5; must_reject("save", sv2, "staff_roster float stat")
d = copy.deepcopy(ST); d["roles"][0]["daily_wage_cents"] = 22.5; must_reject("staff", d, "staff.json float wage")
d = copy.deepcopy(ST); d["roles"][0]["building"] = "casino"; must_reject("staff", d, "staff.json unknown building")
d = copy.deepcopy(ST); d["params"]["rating_bonus"] = 5; must_reject("staff", d, "staff.json rating parameter")
ok("staff.json: roles cover the ten buildings, caps rise, tournament gate reachable, strings drafted, optional roster block validated")

# --- runtime copies shipped in the game (docs/ is not exported)
GAME_DATA = os.path.join(HERE, "..", "..", "..", "game", "data")
for fn in ("tournaments.json", "daily_challenges.json", "achievements.json", "progression.json", "event_cards.json", "economy_params.json", "staff.json"):
    p = os.path.join(GAME_DATA, fn)
    if not os.path.exists(p): bad(f"game/data/{fn} (runtime copy) missing"); continue
    with open(p, encoding="utf-8") as f1, open(os.path.join(HERE, fn), encoding="utf-8") as f2:
        if json.load(f1) != json.load(f2): bad(f"game/data/{fn} differs from docs/spec/data/{fn}")
        else: ok(f"game/data/{fn} equals docs/spec/data/{fn}")

# --- semantic: progression, achievements, daily challenges
P = loaded["progression.json"]
if [l["level"] for l in P["levels"]] != list(range(1, len(P["levels"]) + 1)): bad("progression: levels must be numbered 1.. in order")
if [l["prestige_needed"] for l in P["levels"]] != sorted({l["prestige_needed"] for l in P["levels"]}) or P["levels"][0]["prestige_needed"] != 0: bad("progression: prestige_needed must rise strictly from 0")
A = loaded["achievements.json"]["achievements"]
if len({a["id"] for a in A}) != len(A): bad("achievements: duplicate ids")
for a in A:
    for c in a["all"]:
        if c["stat"] not in stat_enum: bad(f"achievement {a['id']}: unknown stat {c['stat']}")
D = loaded["daily_challenges.json"]
if len({t["id"] for t in D["templates"]}) != len(D["templates"]): bad("daily_challenges: duplicate template ids")
ok("progression, achievements and daily challenges: semantic checks done")

# --- export presets must pack the runtime JSON (res://data/*.json is read at runtime and is not a Godot resource)
PRESETS = os.path.join(HERE, "..", "..", "..", "game", "export_presets.cfg.template")
if not os.path.exists(PRESETS): bad("game/export_presets.cfg.template missing")
else:
    with open(PRESETS, encoding="utf-8") as f: txt = f.read()
    filters = re.findall(r'^include_filter="([^"]*)"', txt, re.M)
    names = re.findall(r'^name="([^"]*)"', txt, re.M)
    if len(filters) < 5 or len(filters) != len([n for n in names if n in ("Android Debug APK", "Android Debug AAB", "Android Release AAB", "Windows Desktop", "iOS")]): bad(f"export presets: {len(filters)} include_filter lines for presets {names}")
    for fl in filters:
        parts = [p.strip() for p in fl.split(",")]
        for need in ("build_info.json", "data/*.json", "data/*/*.json"):
            if need not in parts: bad(f"export preset include_filter {fl!r} lacks {need}")
    for sub in os.listdir(os.path.join(HERE, "..", "..", "..", "game", "data")):
        pth = os.path.join(HERE, "..", "..", "..", "game", "data", sub)
        if os.path.isdir(pth):
            for _r, ds, _f in os.walk(pth):
                if ds: bad(f"game/data/{sub} nests deeper than the data/*/*.json filter covers")
    ok("export presets pack build_info.json and game/data/*.json and game/data/*/*.json")

# --- unit sanity: no bare 'unlocked' or 'entitlement' key anywhere in save schema properties
if re.search(r'"(unlocked|entitlement|is_paid|premium)"', json.dumps(schemas["save"]["properties"])): bad("save schema must not carry entitlement fields")
else: ok("save schema carries no entitlement field")

print("\nRESULT:", "FAIL (%d)" % len(fails) if fails else "ALL PASS")
sys.exit(1 if fails else 0)
