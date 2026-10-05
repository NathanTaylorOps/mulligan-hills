#!/usr/bin/env python3
"""Writes golden vectors for the GDScript rating tests and copies params.json to game/data/rating/.

Output:
  game/tests/rating/golden/rating_golden.json   (read by game/tests/rating/test_rating_*.gd)
  game/data/rating/params.json                  (runtime table file, byte identical to docs/spec/rating/params.json)
Usage: python3 tools/reference/rating/gen_golden.py   (about 1 minute)
"""
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rating_eng as E  # noqa: E402
from rating_core import (ROOT, Hole, H32, hash64, i32le, Z, hole_seed, daily_seed, tournament_seed, rdiv, interp,
                         isqrt, validate_input, expand_tree_rect, PARAMS_HASH, ENGINE, SIM, P, PARAMS_PATH,
                         PREVIEW_COUNTS)  # noqa: E402

FIX = os.path.join(ROOT, "docs", "spec", "fixtures", "rating")
OUT = os.path.join(ROOT, "game", "tests", "rating", "golden", "rating_golden.json")
DATA = os.path.join(ROOT, "game", "data", "rating", "params.json")
SECRET = 0x12345678


def fx(n):
    for f in sorted(os.listdir(FIX)):
        if f.startswith(n):
            return json.load(open(os.path.join(FIX, f)))


def hole_obj(d):
    d = dict(d)
    d.setdefault("slot_id", 1)
    return Hole(d)


SYN_PAR3 = {"slot_id": 41, "tee": [0, 0], "green": [-6, 168, 12], "tee_z_mm": 0, "green_z_mm": 4200, "features": [
    {"t": "fairway", "circle": [-3, 150, 22]}, {"t": "bunker", "circle": [-16, 160, 7]}, {"t": "bunker", "rect": [6, 150, 18, 172]},
    {"t": "water", "rect": [-40, 60, -20, 120]}, {"t": "rock", "count": 3}, {"t": "flower", "count": 6},
    {"t": "tree", "at": [[20, 40], [24, 90], [-26, 130], [26, 175], [-20, 175]]}]}
SYN_PAR5 = {"slot_id": 42, "tee": [0, 0], "green": [30, 520, 15], "tee_z_mm": -2000, "green_z_mm": 3000, "features": [
    {"t": "fairway", "rect": [-30, 0, 40, 160]}, {"t": "fairway", "rect": [0, 160, 60, 330]}, {"t": "fairway", "rect": [10, 330, 50, 505]},
    {"t": "deep_rough", "rect": [-60, 200, -20, 400]}, {"t": "ob", "rect": [70, 100, 100, 450]},
    {"t": "water", "circle": [25, 300, 18]}, {"t": "bunker", "rect": [38, 480, 52, 500]},
    {"t": "tree", "at": [[-10, 180], [-12, 182], [-14, 250], [65, 300], [66, 301], [0, 420]]},
    {"t": "rock", "count": 2}, {"t": "flower", "count": 3}]}


def sim_case(name, hd, cond=None, counts=None, secret=SECRET, epoch=1):
    h = hole_obj(hd)
    seed = hole_seed(secret, epoch, h.slot)
    cond = cond or E.CALM
    r = E.rate_hole(h, seed, cond, counts=counts, epoch=epoch, want_recs=True)
    out = dict(name=name, hole=hd, secret=secret, epoch=epoch, cond=cond, preview=counts is not None, hole_seed=seed,
               valid=r["valid"], reasons=r["reasons"], all_reasons=r["all_reasons"], sim_hash=r["hash"],
               content_hash=r["content_hash"] if h.valid else "", par=r["par"], L=r["L"])
    if r["valid"]:
        for k in ("score_pm", "score", "A", "I", "Len", "B", "F", "forced_pm", "pickup_pm", "tree_pm", "risk_pm", "raw_corr",
                  "comps", "pace_pm", "pace_pen", "spread", "T_par", "inversions", "over", "bend_s", "elev", "Oc", "R",
                  "shape", "PQ", "B_raw", "n_tree", "raw_trees", "wat", "cats", "stacked", "dead", "golfers"):
            out[k] = r[k]
        out["means"] = r["means"]
        recs = r["recs"]
        out["band_strokes"] = [sum(x["strokes"] for x in recs if x["band"] == b) for b in range(6)]
        out["band_time"] = [sum(x["time_s"] for x in recs if x["band"] == b) for b in range(6)]
        out["first_rec"] = [recs[0]["gid"], recs[0]["strokes"], recs[0]["flags"], recs[0]["time_s"], recs[0]["first"][0], recs[0]["first"][1]]
    return out


def course_case(name, holes_d, names):
    hs, rs, summ = [], [], []
    for n in names:
        hd = dict(holes_d[n])
        h = hole_obj(hd)
        r = E.rate_hole(h, hole_seed(SECRET, 1, h.slot), epoch=1)
        hs.append(h)
        rs.append(r)
        summ.append(dict(valid=r["valid"], score_pm=r["score_pm"], par=r["par"], pace_pm=r["pace_pm"]))
    ro = E.rollup(hs, rs)
    ds = [E.descriptor(h) for h in hs]
    return dict(name=name, holes=[holes_d[n] for n in names], results=summ, course_x10=ro["course_x10"], mean=ro["mean"],
                low_third=ro["low_third"], factors=ro["factors"], adj=ro["adj"], n_dup=ro["n_dup"], tier=ro["tier"],
                valid_non_dead=ro["valid_non_dead"], codes_course=ro["codes"]["course"],
                codes_per_hole=[[c, i] for c, i in ro["codes"]["per_hole"]],
                descriptor_hash=[hash64(b"".join(i32le(v) for v in d)) for d in ds if d is not None])


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    os.makedirs(os.path.dirname(DATA), exist_ok=True)
    shutil.copyfile(PARAMS_PATH, DATA)
    g = dict(engine=ENGINE, sim_version=SIM, params_hash=PARAMS_HASH, secret=SECRET)
    g["fn_vectors"] = dict(
        rdiv=[[a, b, rdiv(a, b)] for a, b in [(7, 2), (-7, 2), (5, 10), (-5, 10), (0, 3), (14, 4), (-14, 4), (99, 100)]],
        fdiv=[[a, b, a // b] for a, b in [(7, 2), (-7, 2), (-1, 400), (-400, 400), (-401, 400), (0, 5), (123456789012, 1000)]],
        isqrt=[[n, isqrt(n)] for n in (0, 1, 15, 16, 17, 10 ** 12, 10 ** 12 - 1, 2 ** 40 + 12345)],
        interp=[[x, interp(P["length_table"], x)] for x in (0, 60, 100, 135, 170, 245, 280, 520, 700, 849, 900)],
        h32=[[list(a), H32(*a)] for a in [(1, 2, 3), (0, 0, 0, 0), (-1, 4294967295, 7), (0xC0FFEE, 5), (SECRET, 1, 7, 0x4D48)]],
        hash64=[["", hash64(b"")], ["abc", hash64(b"abc")]],
        z256_hash=hash64(b"".join(i32le(z) for z in Z)),
        hole_seed=[[SECRET, 1, 7, hole_seed(SECRET, 1, 7)], [1, 2, 3, hole_seed(1, 2, 3)]],
        daily_seed=[[5, 9, daily_seed(5, 9)]], tournament_seed=[[SECRET, 3, 9, tournament_seed(SECRET, 3, 9)]],
        tree_expand=[[[0, 0, 30, 20], 12, [list(p) for p in expand_tree_rect([0, 0, 30, 20], 12)]],
                     [[-10, 5, 12, 9], 7, [list(p) for p in expand_tree_rect([-10, 5, 12, 9], 7)]]],
    )
    f02, f03, f05, f06, f08, f12, f14 = fx("02"), fx("03"), fx("05"), fx("06"), fx("08"), fx("12"), fx("14")
    sims = [
        sim_case("plain_par4", f02["holes"]["plain"]),
        sim_case("choice_par4", f05["holes"]["choice"]),
        sim_case("forced_water", f06["holes"]["forced"]),
        sim_case("determinism_base", f08["holes"]["base"], secret=f08["secret"]),
        sim_case("tree_spam", f03["holes"]["spam"]),
        sim_case("synthetic_par3", SYN_PAR3),
        sim_case("synthetic_par5", SYN_PAR5, epoch=2),
        sim_case("preview_n30", f02["holes"]["strategic"], counts=PREVIEW_COUNTS),
        sim_case("headwind", f14["holes"]["base"], cond=f14["conds"]["head15"]),
        sim_case("rain2_epoch3", f14["holes"]["base"], cond=f14["conds"]["wet2"], epoch=3),
    ]
    for k, v in f12["holes"].items():
        sims.append(sim_case("unplayable_" + k, v))
    g["sims"] = sims
    f01 = fx("01")
    g["invalid_holes"] = [dict(name=k, hole=v, reasons=hole_obj(v).reasons) for k, v in f01["holes"].items()]
    extra = {"far": {"slot_id": 9, "tee": [0, 0], "green": [0, 1100, 12], "features": []},
             "near": {"slot_id": 9, "tee": [0, 0], "green": [0, 30, 12], "features": []},
             "small_green": {"slot_id": 9, "tee": [0, 0], "green": [0, 300, 3], "features": []},
             "green_in_water": {"slot_id": 9, "tee": [0, 0], "green": [0, 300, 12], "features": [{"t": "water", "rect": [-20, 290, 20, 310]}]},
             "tee_oob": {"slot_id": 9, "tee": [0, -100], "green": [0, 300, 12], "features": []}}
    g["invalid_holes"] += [dict(name=k, hole=v, reasons=hole_obj(v).reasons) for k, v in extra.items()]
    f09 = fx("09")
    g["fuzz"] = [dict(name=c["name"], input=c["input"], code=validate_input(c["input"])[1]) for c in f09["cases"]]
    emb = f09["embedded_score_case"]
    g["fuzz_embedded"] = dict(input=emb["input"], ok=validate_input(emb["input"])[0])
    f07, f11, f13 = fx("07"), fx("11"), fx("13")
    g["courses"] = [course_case("varied", f07["holes"], f07["courses"]["varied"]),
                    course_case("copies", f07["holes"], f07["courses"]["copies"]),
                    course_case("mixed", f11["holes"], f11["courses"]["mixed"])]
    a, b = hole_obj(f13["holes"]["orig"]), hole_obj(f13["holes"]["mirror"])
    g["mirror"] = dict(orig=f13["holes"]["orig"], mirror=f13["holes"]["mirror"],
                       S=E.similarity(a, E.descriptor(a), b, E.descriptor(b)))
    f10 = fx("10")["tournament"]
    g["tournament"] = dict(
        sustained=[[c, E.sustained(c)] for c in (f10["honest_checkpoints"], f10["gamed_checkpoints"], [500, 510], [])],
        prestige=[[E.sustained(f10["honest_checkpoints"]), 1000, f10["fac_pts"], 0, 0, E.prestige(522, 1000, 120, 0, 0)],
                  [380, 1500, 60, 2, 3, E.prestige(380, 1500, 60, 2, 3)], [1000, 0, 400, 0, 0, E.prestige(1000, 0, 400, 0, 0)]],
        facility=[[[1, 2, 3, 4, 5], E.facility_points([1, 2, 3, 4, 5])], [[9, 9, 9, 9, 9], E.facility_points([9, 9, 9, 9, 9])]],
        codes=[dict(args=a_, codes=E.tournament_codes(*a_)) for a_ in
               [[500, 3, True, True, 2, 1400], [600, 8, False, False, 0, 1000]]],
        wind=[[463, 513, E.wind_codes(463, 513)], [463, 480, E.wind_codes(463, 480)]],
        stale=["MHRATE-0.9.0", E.stale_codes("MHRATE-0.9.0")],
        near=dict(origins=[[0, 0], [5, 5], [200, 200]], tg=[[[0, 0], [0, 300]], [[3, 4], [0, 300]], [[0, 0], [0, 300]]],
                  hit=E.near_holes([(0, 0), (5, 5), (200, 200)], [((0, 0), (0, 300)), ((3, 4), (0, 300)), ((0, 0), (0, 300))])))
    f15 = fx("15")
    g["rank"] = dict(entries=f15["entries"], order=E.rank(f15["entries"]))
    g["codes"] = dict(table=[[c, s] for c, s in sorted(E.CODES.items())],
                      top=[[["RC040", "RC033", "RC031", "RC017", "RC031", "RC001"], E.top_codes(["RC040", "RC033", "RC031", "RC017", "RC031", "RC001"])]])
    with open(OUT, "w") as fh:
        json.dump(g, fh, indent=0, sort_keys=True)
    print("wrote", OUT, os.path.getsize(OUT), "bytes;", DATA)


if __name__ == "__main__":
    main()
