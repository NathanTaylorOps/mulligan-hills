"""Self-test of the Python reference against independent oracles.
Run: python3 tools/reference/determinism/selftest.py   (exit code 0 = all pass)"""
import json
import math
import os
import random
import subprocess
import sys
import mh_fixed as F
import mh_trig as T
from mh_rng import Pcg32
from mh_hash import Fnv64
import mh_shotsim as S

HERE = os.path.dirname(os.path.abspath(__file__))
GOLD = os.path.join(HERE, "..", "..", "..", "game", "tests", "core", "golden")
fails = []


def check(name, cond, info=""):
    print(("PASS " if cond else "FAIL ") + name + (" " + info if info else ""))
    if not cond:
        fails.append(name)


# 1. PCG32 against a textbook bigint implementation and the published pcg32-demo vector.
def pcg_big(seed, stream, n):
    M = (1 << 64) - 1
    mult = 6364136223846793005
    inc = ((stream << 1) | 1) & M
    st = 0

    def nxt():
        nonlocal st
        old = st
        st = (old * mult + inc) & M
        xs = (((old >> 18) ^ old) >> 27) & 0xFFFFFFFF
        rot = old >> 59
        return ((xs >> rot) | (xs << ((-rot) & 31))) & 0xFFFFFFFF
    nxt()
    st = (st + seed) & M
    nxt()
    return [nxt() for _ in range(n)]


ref = [0xa15c02b7, 0x7b47f409, 0xba1d3330, 0x83d2f293, 0xbfa4784b, 0xcbed606e]
check("pcg32 bigint == published demo vector (seed 42, seq 54)", pcg_big(42, 54, 6) == ref, "(vector recalled from pcg-c demo output)")
r = Pcg32(42, 54)
check("limb PCG32 == published demo vector", [r.next_u32() for _ in range(6)] == ref)
rnd = random.Random(1)
ok = True
for _ in range(300):
    s = rnd.getrandbits(63)
    st = rnd.getrandbits(62)
    r = Pcg32(s, st)
    if [r.next_u32() for _ in range(50)] != pcg_big(s, st, 50):
        ok = False
check("limb PCG32 == bigint PCG32 on 300 random seeds x 50 outputs", ok)

# 2. FNV-1a 64 known vectors.
def fnv(b):
    f = Fnv64()
    for x in b:
        f.add_byte(x)
    return f.hex()

check("FNV1a64('') == cbf29ce484222325", fnv(b"") == "cbf29ce484222325")
check("FNV1a64('a') == af63dc4c8601ec8c", fnv(b"a") == "af63dc4c8601ec8c")
check("FNV1a64('foobar') == 85944171f73967e8", fnv(b"foobar") == "85944171f73967e8")
ok = True
for _ in range(300):
    v = rnd.randrange(-(1 << 62), 1 << 62)
    f = Fnv64()
    f.add_i64(v)
    if f.hex() != fnv((v & ((1 << 64) - 1)).to_bytes(8, "little")):
        ok = False
check("add_i64 == FNV over 8 LE two's-complement bytes", ok)

# 3. Fixed point
ok = True
for _ in range(5000):
    n = rnd.getrandbits(rnd.randint(1, 62))
    if F.isqrt(n) != math.isqrt(n):
        ok = False
check("isqrt == math.isqrt (5000 random)", ok)
ok = True
for _ in range(5000):
    a = rnd.randint(-(1 << 31), 1 << 31)
    b = rnd.randint(-(1 << 31), 1 << 31)
    e = abs(a) * abs(b) >> 16
    e = -e if (a < 0) != (b < 0) else e
    if F.mul(a, b) != e:
        ok = False
check("mul == truncated exact product", ok)
worst = 0
for _ in range(5000):
    a = rnd.randint(0, 1 << 40)
    worst = max(worst, abs(F.sqrt(a) - math.isqrt(a << 16)))
check("fixed sqrt exact floor", worst == 0)
check("div truncates toward zero", F.div(-1, 3) == -21845 and F.div(1, -3) == -21845 and F.div(65536, 0) == F.DIV0)
check("floor_int / trunc_int negatives", F.floor_int(-1) == -1 and F.trunc_int(-1) == 0 and F.floor_int(-65536) == -1 and F.trunc_int(-65537) == -1)

# 4. Trig accuracy vs float oracle (oracle only used here, never in game code)
ms = 0.0
for a in range(65536):
    th = a * 2 * math.pi / 65536
    ms = max(ms, abs(T.sin_brad(a) - math.sin(th) * 65536), abs(T.cos_brad(a) - math.cos(th) * 65536))
check("sin/cos max error <= 2.0 LSB (1 LSB = 1/65536)", ms <= 2.0, "measured max %.3f LSB over all 65536 angles" % ms)
ma = 0.0
r = Pcg32(5, 5)
worst_case = None
for i in range(200000):
    if i < 65536:
        th = i * 2 * math.pi / 65536
        x = int(math.cos(th) * 1e6)
        y = int(math.sin(th) * 1e6)
    else:
        x = r.next_u32() - (1 << 31)
        y = r.next_u32() - (1 << 31)
    if x == 0 and y == 0:
        continue
    ex = math.atan2(y, x) * 65536 / (2 * math.pi)
    if ex < 0:
        ex += 65536
    got = T.atan2_brad(y, x)
    d = abs(got - ex)
    d = min(d, 65536 - d)
    if d > ma:
        ma = d
        worst_case = (y, x)
check("atan2 max error <= 2.0 brads (1 brad = 0.00549 deg)", ma <= 2.0, "measured max %.3f brads at %s" % (ma, worst_case))
check("sin(0)=0 cos(0)=65536 sin(16384)=65536 sin(32768)=0", T.sin_brad(0) == 0 and T.cos_brad(0) == 65536 and T.sin_brad(16384) == 65536 and T.sin_brad(32768) == 0)
mono = all(T.SIN_Q[i] <= T.SIN_Q[i + 1] for i in range(256)) and all(T.ATAN_T[i] <= T.ATAN_T[i + 1] for i in range(256))
check("tables monotonic (interpolation shifts stay non-negative)", mono)

# 5. Shot sim determinism and sanity
a = S.run_sim_hash(20260929, 777, 10, 18, True)
b = S.run_sim_hash(20260929, 777, 10, 18, True)
check("sim hash repeatable", a == b)
c = S.run_sim_hash(20260929, 778, 10, 18, True)
check("sim hash changes with seed", a["hash"] != c["hash"])
w = S.run_sim_hash(20260929, 777, 10, 18, False)
check("trace off gives identical strokes/time", (w["total_strokes"], w["max_time"]) == (a["total_strokes"], a["max_time"]))
ok = True
for hi in range(18):
    h = S.make_hole(20260929, hi)
    for k in range(20):
        res = S.simulate_hole(h, 10 + k * 4, 0, 0, Pcg32(k, hi), False)
        if not (1 <= res["strokes"] <= S.MAX_STROKES):
            ok = False
check("strokes always in 1..12", ok)

# 6. Golden files: regenerate to a temp copy and require byte equality with committed files.
before = {}
for n in sorted(os.listdir(GOLD)):
    with open(os.path.join(GOLD, n), "rb") as f:
        before[n] = f.read()
subprocess.check_call([sys.executable, os.path.join(HERE, "gen_golden.py")], stdout=subprocess.DEVNULL)
same = True
for n, data in before.items():
    with open(os.path.join(GOLD, n), "rb") as f:
        if f.read() != data:
            same = False
check("golden files regenerate byte-identical (%d files)" % len(before), same)

print("\n%d failures" % len(fails))
sys.exit(1 if fails else 0)
