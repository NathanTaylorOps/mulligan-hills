"""Generate golden vectors into game/tests/core/golden/*.json.
Run: python3 tools/reference/determinism/gen_golden.py
JSON numbers are exact only below 2**53 in GDScript's JSON parser (floats), so any
value with |v| >= 2**53 is written as a decimal string; 64-bit hashes are hex strings."""
import json
import os
import mh_fixed as F
import mh_trig as T
from mh_rng import Pcg32
from mh_hash import Fnv64
import mh_shotsim as S

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "tests", "core", "golden")
LIM = 1 << 53


def jn(v):
    return v if -LIM < v < LIM else str(v)


def dump(name, obj):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, name), "w", newline="\n") as f:
        json.dump(obj, f, separators=(",", ":"))
        f.write("\n")
    print("wrote", name, os.path.getsize(os.path.join(OUT, name)), "bytes")


def gen_rng():
    cases = []
    for seed, stream in [(42, 54), (0, 0), (12345, 1), (1 << 40 | 7, 99), ((1 << 62) + 12345, (1 << 61) + 5), (20260929, 1000)]:
        r = Pcg32(seed, stream)
        u32 = [r.next_u32() for _ in range(32)]
        r = Pcg32(seed, stream)
        b100 = [r.bounded(100) for _ in range(32)]
        r = Pcg32(seed, stream)
        b3 = [r.bounded(3) for _ in range(32)]
        r = Pcg32(seed, stream)
        rng_incl = [r.range_incl(-5, 5) for _ in range(32)]
        r = Pcg32(seed, stream)
        gs = [r.gauss_q16() for _ in range(32)]
        r = Pcg32(seed, stream)
        f = Fnv64()
        for i in range(1000):
            k = i % 4
            if k == 0:
                v = r.next_u32()
            elif k == 1:
                v = r.bounded(1000)
            elif k == 2:
                v = r.range_incl(-100, 100)
            else:
                v = r.gauss_q16()
            f.add_i64(v)
        cases.append({"seed": jn(seed), "stream": jn(stream), "u32": u32, "bounded100": b100,
                      "bounded3": b3, "range_m5_5": rng_incl, "gauss": gs, "mixed1000_hash": f.hex()})
    dump("rng.json", {"cases": cases})


def gen_fixed():
    r = Pcg32(4242, 1)

    def s32():
        return r.next_u32() - (1 << 31)

    mul_edges = [(0, 0), (65536, 65536), (-65536, 65536), (1, 1), (-1, 1), (-1, -1), (1, -1),
                 (32768, 32768), (98304, 131072), (-98304, 131072), (1 << 31, 1 << 31), (-(1 << 31), 1 << 31),
                 (3, 21845), (-3, 21845), (65535, 65535), (-65535, 65535), (100, -655)]
    mulv = [[a, b, F.mul(a, b)] for a, b in mul_edges]
    for _ in range(300):
        a, b = s32(), s32()
        mulv.append([a, b, F.mul(a, b)])
    div_edges = [(65536, 65536), (-65536, 65536), (65536, -65536), (1, 3), (-1, 3), (1, -3), (0, 5), (5, 0), (-5, 0), (0, 0),
                 (98304, 65536), (65536, 3 * 65536), (-65536, 3 * 65536), (1 << 40, 1), (-(1 << 40), 7)]
    divv = [[a, b, F.div(a, b)] for a, b in div_edges]
    for _ in range(300):
        a, b = s32() * 8, s32()
        if b == 0:
            b = 1
        divv.append([jn(a), b, jn(F.div(a, b))])
    sq_edges = [0, 1, 2, 3, 65535, 65536, 131072, 262144, 4 * 65536, 2 * 65536, -5, -65536, 1 << 30, (1 << 46) - 1]
    sqv = [[jn(a), F.sqrt(a)] for a in sq_edges]
    for _ in range(300):
        a = (r.next_u32() << r.bounded(15)) + r.next_u32() % 1000
        sqv.append([jn(a), F.sqrt(a)])
    isq = [[jn(a), F.isqrt(a)] for a in [0, 1, 2, 3, 4, 15, 16, 17, (1 << 32) - 1, 1 << 32, (1 << 62) - 1, (1 << 63) - 1, 999999999999]]
    for _ in range(200):
        a = (r.next_u32() << 31) | (r.next_u32() >> 1)
        a &= (1 << 63) - 1
        isq.append([jn(a), F.isqrt(a)])
    lerpv = []
    for _ in range(120):
        a, b = s32() // 2, s32() // 2
        t = r.bounded(3 * 65536) - 65536
        lerpv.append([a, b, t, F.lerp(a, b, t)])
    lerpv += [[0, 65536, 32768, 32768], [65536, 0, 32768, 32768], [-65536, 65536, 16384, F.lerp(-65536, 65536, 16384)]]
    clampv = [[a, lo, hi, F.clamp(a, lo, hi)] for a, lo, hi in
              [(5, 0, 10), (-5, 0, 10), (15, 0, 10), (0, 0, 10), (10, 0, 10), (-7, -9, -3), (-1, -9, -3), (-20, -9, -3)]]
    trunc_v = [[a, F.trunc_int(a), F.floor_int(a)] for a in
               [0, 1, -1, 65535, -65535, 65536, -65536, 65537, -65537, 131071, -131071, 3 * 65536 + 100, -3 * 65536 - 100, 1 << 40, -(1 << 40)]]
    hyp = []
    for _ in range(100):
        dx, dy = s32() // 16, s32() // 16
        hyp.append([dx, dy, F.hypot(dx, dy)])
    dump("fixed.json", {"mul": mulv, "div": divv, "sqrt": sqv, "isqrt": isq, "lerp": lerpv,
                        "clamp": clampv, "trunc_floor": trunc_v, "hypot": hyp})


def gen_trig():
    angles = list(range(0, 65536, 37)) + [-1, -16385, 65536, 70000, -70000, 16384, 32768, 49152, 8192, 0, 65535]
    sc = [[a, T.sin_brad(a), T.cos_brad(a)] for a in angles]
    r = Pcg32(999, 7)
    pairs = [(0, 0), (1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (-1, 1), (-1, -1), (1, -1),
             (1000000, 1), (1, 1000000), (-1000000, -1), (65536, 65536), (-65536, 65536), (1 << 30, 1), (1, 1 << 30), (3, 7), (7, 3)]
    for _ in range(2000):
        x = r.next_u32() - (1 << 31)
        y = r.next_u32() - (1 << 31)
        pairs.append((y, x))
    for _ in range(500):
        x = r.range_incl(-50, 50)
        y = r.range_incl(-50, 50)
        pairs.append((y, x))
    at = [[y, x, T.atan2_brad(y, x)] for y, x in pairs]
    h = Fnv64()
    for v in T.SIN_Q:
        h.add_i64(v)
    for v in T.ATAN_T:
        h.add_i64(v)
    dump("trig.json", {"table_hash": h.hex(), "sin_len": len(T.SIN_Q), "atan_len": len(T.ATAN_T),
                       "sincos": sc, "atan2": at})


def gen_hash():
    vecs = []
    for s in [b"", b"a", b"foobar", b"Mulligan Hills"]:
        f = Fnv64()
        for b in s:
            f.add_byte(b)
        vecs.append({"bytes": list(s), "hex": f.hex()})
    ints = []
    r = Pcg32(31337, 3)
    vals = [0, 1, -1, 255, 256, 65535, 1 << 32, -(1 << 32), (1 << 62) - 1, -(1 << 62), 123456789012]
    vals += [r.next_u32() - (1 << 31) for _ in range(20)]
    f = Fnv64()
    for v in vals:
        f.add_i64(v)
    single = []
    for v in vals:
        g = Fnv64()
        g.add_i64(v)
        single.append([jn(v), g.hex()])
    u32s = []
    for v in [0, 1, 255, 65536, 0xFFFFFFFF, 0xDEADBEEF]:
        g = Fnv64()
        g.add_u32(v)
        u32s.append([v, g.hex()])
    dump("hash.json", {"bytes": vecs, "single_i64": single, "u32": u32s,
                       "seq_i64": [jn(v) for v in vals], "seq_hash": f.hex()})


COURSE_SEED = 20260929
BASE_SEED = 777


def gen_shotsim():
    holes = []
    for i in range(18):
        h = S.make_hole(COURSE_SEED, i)
        holes.append({"index": i, "par": h.par, "w": h.w, "h": h.h, "tee_x": h.tee_x, "tee_y": h.tee_y,
                      "pin_x": h.pin_x, "pin_y": h.pin_y, "lie_hash": S.hole_lie_hash(h)})
    sims = []
    for (hi, skill, wx, wy, seed, stream) in [(0, 10, 0, 0, 1, 1), (1, 50, 5 * 65536, -3 * 65536, 2, 2), (2, 99, -5 * 65536, 4 * 65536, 3, 3),
                                              (5, 30, 65536, 65536, 4, 4), (7, 70, 0, 0, 5, 5), (12, 20, -2 * 65536, 0, 6, 6), (17, 60, 3 * 65536, -1 * 65536, 7, 7)]:
        h = S.make_hole(COURSE_SEED, hi)
        res = S.simulate_hole(h, skill, wx, wy, Pcg32(seed, stream), True)
        sims.append({"hole": hi, "skill": skill, "wind_x": wx, "wind_y": wy, "seed": seed, "stream": stream,
                     "strokes": res["strokes"], "holed": res["holed"], "time": res["time"],
                     "trace_len": len(res["trace"]), "trace_hash": S.trace_hash(res["trace"]),
                     "trace": res["trace"] if hi == 1 else None})
    runs = []
    for (n, m) in [(4, 3), (10, 18), (60, 18)]:
        r = S.run_sim_hash(COURSE_SEED, BASE_SEED, n, m, True)
        q = S.run_sim_hash(COURSE_SEED, BASE_SEED, n, m, False)
        assert q["total_strokes"] == r["total_strokes"] and q["max_time"] == r["max_time"]
        runs.append({"golfers": n, "holes": m, "hash": r["hash"], "total_strokes": r["total_strokes"], "max_time": r["max_time"]})
    dump("shotsim.json", {"course_seed": COURSE_SEED, "base_seed": BASE_SEED, "holes": holes, "sims": sims, "runs": runs})


if __name__ == "__main__":
    gen_rng()
    gen_fixed()
    gen_trig()
    gen_hash()
    gen_shotsim()
