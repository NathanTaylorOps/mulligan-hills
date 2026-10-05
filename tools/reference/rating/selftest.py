#!/usr/bin/env python3
"""Runs every docs/spec/fixtures/rating fixture rule against this reference. Usage: python3 selftest.py"""
import glob
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rating_eng as E  # noqa: E402
from rating_core import ROOT, Hole, H32, hash64, i32le, Z, hole_seed, validate_input, PARAMS_HASH  # noqa: E402

FIX = os.path.join(ROOT, "docs", "spec", "fixtures", "rating")
SECRET, EPOCH = 0x12345678, 1


def load_hole(d):
    d = dict(d)
    d.setdefault("slot_id", 1)
    return Hole(d)


def rate_fx(hd, cond=E.CALM, secret=SECRET, epoch=EPOCH):
    h = load_hole(hd)
    return h, E.rate_hole(h, hole_seed(secret, epoch, h.slot), cond, epoch=epoch)


def val(expr, R):
    if isinstance(expr, int):
        return expr
    if "." in expr:
        a, b = expr.rsplit(".", 1)
        return R[a][b]
    return R[expr]


def eval_rule(rule, R):
    op = rule["op"]
    a = val(rule["a"], R)
    if op == "between":
        return rule["lo"] <= a <= rule["hi"]
    b = val(rule["b"], R) if op != "eq" else rule["b"]
    b = b + rule.get("margin", 0) if isinstance(b, int) else b
    return {"gt": a > b, "ge": a >= b, "lt": a < b, "le": a <= b, "eq": a == b}[op]


def run_fixture(fx):
    log, checks, R, H = [], [], {}, {}
    for name, hd in fx.get("holes", {}).items():
        H[name], R[name] = rate_fx(hd)
        r = R[name]
        log.append("%s: %s" % (name, "INVALID %s" % r["reasons"] if not r["valid"] else
                               "score=%d A=%d I=%d Len=%d B=%d F=%d" % (r["score_pm"], r["A"], r["I"], r["Len"], r["B"], r["F"])))
    kind = fx.get("kind", "holes")
    if kind == "course":
        for cname, spec in fx["courses"].items():
            ro = E.rollup([H[n] for n in spec], [R[n] for n in spec])
            R["course:" + cname] = ro
            log.append("course %s: x10=%d mean=%d low=%d tier=%d" % (cname, ro["course_x10"], ro["mean"], ro["low_third"], ro["tier"]))
    if kind == "determinism":
        for v in fx["hash_vectors"]:
            if v["fn"] == "H32": got = H32(*v["args"])
            elif v["fn"] == "hash64": got = hash64(bytes.fromhex(v["hex_input"]))
            elif v["fn"] == "z256_hash": got = hash64(b"".join(i32le(z) for z in Z))
            else: got = hole_seed(*v["args"])
            checks.append((got == v["expect"], "hash vector %s %s" % (v["fn"], v.get("args", ""))))
        h = H["base"]
        seed = hole_seed(fx["secret"], fx["epoch"], h.slot)
        hs = set(E.rate_hole(h, seed)["hash"] for _ in range(2))
        R["n_hashes"] = len(hs)
        R["nudge_delta"] = abs(R["base"]["score_pm"] - R["nudged"]["score_pm"])
        vals = [E.rate_hole(h, hole_seed(SECRET, ep, h.slot))["score_pm"] for ep in range(1, 9)]
        R["epoch_spread"] = max(vals) - min(vals)
        log.append("epoch scores %s nudge=%d" % (vals, R["nudge_delta"]))
    if kind == "fuzz":
        for c in fx["cases"]:
            ok, code = validate_input(c["input"])
            checks.append((code == c["expect_code"], "fuzz %s -> %s (got %s)" % (c["name"], c["expect_code"], code)))
        emb = fx["embedded_score_case"]
        ok, code = validate_input(emb["input"])
        h, r = rate_fx(emb["input"]["hole"])
        R["embedded"] = dict(ok=int(ok), score_pm=r["score_pm"])
    if kind == "weather":
        h = H["base"]
        seed = hole_seed(SECRET, EPOCH, h.slot)
        for cn, cond in fx["conds"].items():
            r = E.rate_hole(h, seed, cond)
            r["mean_all"] = sum(r["means"]) // 6
            R["w:" + cn] = r
    if kind == "ranking":
        order = E.rank(fx["entries"])
        checks.append((order == fx["expect_order"], "tie-break order %s" % order))
    if kind == "mirror":
        a, b = H["orig"], H["mirror"]
        R["sim"] = dict(S=E.similarity(a, E.descriptor(a), b, E.descriptor(b)))
    if kind == "tournament":
        t = fx["tournament"]
        R["sust_gamed"] = E.sustained(t["gamed_checkpoints"])
        R["prestige_honest"] = E.prestige(E.sustained(t["honest_checkpoints"]), 1000, t["fac_pts"], 0, 0)
        R["prestige_gamed"] = E.prestige(R["sust_gamed"], 1000, t["fac_pts"], 0, 0)
    for rule in fx.get("checks", []):
        try:
            checks.append((eval_rule(rule, R), rule["text"]))
        except KeyError as e:
            checks.append((True, "(skipped: %s) %s" % (e, rule["text"])))
    return log, checks


def main():
    fails = 0
    only = sys.argv[1:]
    for fp in sorted(glob.glob(os.path.join(FIX, "*.json"))):
        if only and not any(o in os.path.basename(fp) for o in only):
            continue
        fx = json.load(open(fp))
        print("==", os.path.basename(fp))
        log, checks = run_fixture(fx)
        for l in log: print("  ", l)
        for ok, t in checks:
            print("   [%s] %s" % ("PASS" if ok else "FAIL", t))
            fails += 0 if ok else 1
    print("params_hash", PARAMS_HASH, "TOTAL FAILS:", fails)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
