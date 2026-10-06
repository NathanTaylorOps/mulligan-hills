"""MHRATE-1.0.0 / MHSIM-1.0.0 reference, part 1: integer math, params, hole model, validation, golfer sim.

Integer only in the simulation and rating path. Every `//` below is floor division (== GDScript fdiv).
This file is the arithmetic definition the GDScript in game/core/rating/ must reproduce bit for bit.
Spec: docs/spec/rating/*.md. Differences from the older sanity model are listed in docs/phase1/rating.md.
"""
import json
import os
from math import isqrt

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
PARAMS_PATH = os.path.join(ROOT, "docs", "spec", "rating", "params.json")
with open(PARAMS_PATH, "rb") as _f:
    PARAMS_BYTES = _f.read().replace(b"\r\n", b"\n")
P = json.loads(PARAMS_BYTES.decode("utf-8"))
M32 = 0xFFFFFFFF
Z = P["z256"]
CY = 100
ENGINE = P["engine_version"]
SIM = P["sim_version"]

LIE_TEE, LIE_FAIRWAY, LIE_FRINGE, LIE_ROUGH, LIE_DEEP, LIE_BUNKER, LIE_GREEN, LIE_WATER, LIE_OB = range(9)
LIE_KEYS = ["tee", "fairway", "fringe", "rough", "deep", "bunker"]
LIES = [P["lies"][k] for k in LIE_KEYS]            # [carry, dispersion, mishit] permille
LIE_ADD = [P["lie_add"][k] for k in LIE_KEYS] + [P["lie_add"]["green"]]
TMAX = [600, 550, 450, 400, 350, 300, 280, 260, 240, 220, 200, 200]
CLUB_BASE = [c[1] for c in P["clubs"]]
CLUB_LOFT = P["club_loft_pm"]
STYLE_W = [0, 8, 30]
FRACS = [1000, 850, 700, 550]
PREVIEW_COUNTS = [3, 5, 8, 8, 4, 2]


def rdiv(a, b):
    if a >= 0:
        return (2 * a + b) // (2 * b)
    return -((-2 * a + b) // (2 * b))


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def interp(table, x):
    if x <= table[0][0]:
        return table[0][1]
    for i in range(1, len(table)):
        x0, y0 = table[i - 1]
        x1, y1 = table[i]
        if x <= x1:
            return y0 + rdiv((y1 - y0) * (x - x0), x1 - x0)
    return table[-1][1]


def mix32(h):
    h &= M32
    h ^= h >> 16
    h = (h * 0x85EBCA6B) & M32
    h ^= h >> 13
    h = (h * 0xC2B2AE35) & M32
    h ^= h >> 16
    return h


def H32(*xs):
    h = 0x811C9DC5
    for x in xs:
        h = mix32(((h ^ (x & M32)) + 0x9E3779B9) & M32)
    return h


def _lane(data, basis):
    h = basis
    for b in data:
        h = ((h ^ b) * 16777619) & M32
    return h


def hash64(data):
    return "%08x%08x" % (_lane(data, 0x811C9DC5), _lane(data, 0x9747B28C))


def i32le(v):
    return (v & M32).to_bytes(4, "little")


PARAMS_HASH = hash64(PARAMS_BYTES)


def hole_seed(secret, epoch, slot):
    return H32(secret, epoch, slot, 0x4D48)


def daily_seed(challenge_id, slot):
    return H32(0xDA11, challenge_id, slot, 0x4D48)


def tournament_seed(secret, event_id, slot):
    return H32(secret, event_id, slot, 0x7E)


def par_for(L):
    return 3 if L <= P["par_limits"][0] else 4 if L <= P["par_limits"][1] else 5


def unit(dx, dy):
    d = isqrt(dx * dx + dy * dy)
    if d == 0:
        return 0, 1024, 0
    return rdiv(dx * 1024, d), rdiv(dy * 1024, d), d


def dist(ax, ay, bx, by):
    return isqrt((ax - bx) ** 2 + (ay - by) ** 2)


# ------------------------------------------------------------------ hole model
TYPE_CODE = {"fairway": 1, "deep_rough": 2, "bunker": 3, "water": 4, "ob": 5, "tree": 6, "rock": 7, "flower": 8}
FEATURE_TYPES = ("fairway", "deep_rough", "bunker", "water", "ob")


def expand_tree_rect(rect, n):
    """Fixture-only loader for {t:'tree', rect, count}; spec 2.1 (no upper y bound)."""
    x0, y0, x1, y1 = rect
    area = max(1, (x1 - x0) * (y1 - y0))
    s = max(1, isqrt(area // max(1, n)))
    nx = max(1, (x1 - x0) // s)
    pts = []
    j = 0
    while len(pts) < n:
        for i in range(nx):
            if len(pts) >= n:
                break
            pts.append((x0 + s // 2 + i * s, y0 + s // 2 + j * s))
        j += 1
    return pts


class Hole:
    def __init__(self, d):
        self.valid = True
        self.reasons = []
        self.slot = d.get("slot_id", 1)
        tee, green = d.get("tee"), d.get("green")
        feats = d.get("features", [])
        self.L = 0
        self.par = 0
        self.rects = {t: [] for t in FEATURE_TYPES}
        self.circles = {t: [] for t in FEATURE_TYPES}
        self.trees = []
        self.counts = {"rock": 0, "flower": 0}
        self.tree_buckets = {}
        self.tee_z = d.get("tee_z_mm", 0)
        self.green_z = d.get("green_z_mm", 0)
        self.relief = d.get("relief")
        self.relief_range = 0
        if tee is None:
            self.valid = False
            self.reasons.append("RC001")
        if green is None:
            self.valid = False
            self.reasons.append("RC002")
        if len(feats) > 3000:
            self.valid = False
            self.reasons.append("RC005")
        if not self.valid:
            return
        self.tee = (tee[0] * CY, tee[1] * CY)
        self.gc = (green[0] * CY, green[1] * CY)
        self.gr = green[2]
        if self.relief is not None:
            zs = self.relief["z"]
            self.relief_range = max(zs) - min(zs)
            self.tee_z = self.z_at(self.tee[0], self.tee[1])
            self.green_z = self.z_at(self.gc[0], self.gc[1])
        dx, dy = green[0] - tee[0], green[1] - tee[1]
        self.L = isqrt(dx * dx + dy * dy)
        self.par = par_for(self.L)
        pts = []
        for f in feats:
            t = f["t"]
            if t == "tree":
                if "at" in f:
                    pts += [(p[0], p[1]) for p in f["at"]]
                else:
                    pts += expand_tree_rect(f["rect"], f["count"])
            elif t in ("rock", "flower"):
                self.counts[t] += f.get("count", len(f.get("at", [])) or 1)
            elif "rect" in f:
                self.rects[t].append(tuple(v * CY for v in f["rect"]))
            elif "circle" in f:
                self.circles[t].append(tuple(v * CY for v in f["circle"]))
        self.trees = sorted((p[0] * CY, p[1] * CY) for p in pts)
        self.counts["tree"] = len(self.trees)
        for (tx, ty) in self.trees:
            self.tree_buckets.setdefault((tx // 1000, ty // 1000), []).append((tx, ty))
        if self.in_type("water", self.gc) or self.in_type("ob", self.gc) or self.lie_at(self.gc) == LIE_OB:
            self.valid = False
            self.reasons.append("RC004")
        if self.in_type("water", self.tee) or self.in_type("ob", self.tee) or self.lie_at(self.tee) == LIE_OB:
            self.valid = False
            self.reasons.append("RC008")
        if self.L < 60 or self.L > 1000:
            self.valid = False
            self.reasons.append("RC003")
        if self.gr < 5 or self.gr > 30:
            self.valid = False
            self.reasons.append("RC006")

    def z_at(self, xcy, ycy):
        """Bilinear height in mm at a centi-yard point; clamped to the grid edge. 0 with no relief."""
        r = self.relief
        if r is None:
            return 0
        sc = r["step"] * CY
        cols, rows, zs = r["cols"], r["rows"], r["z"]
        fx = xcy - r["x0"] * CY
        fy = ycy - r["y0"] * CY
        i = clamp(fx // sc, 0, cols - 2)
        j = clamp(fy // sc, 0, rows - 2)
        fu = clamp(fx - i * sc, 0, sc)
        fv = clamp(fy - j * sc, 0, sc)
        z00, z10 = zs[j * cols + i], zs[j * cols + i + 1]
        z01, z11 = zs[(j + 1) * cols + i], zs[(j + 1) * cols + i + 1]
        return (z00 * (sc - fu) * (sc - fv) + z10 * fu * (sc - fv) + z01 * (sc - fu) * fv + z11 * fu * fv) // (sc * sc)

    def grad_l1(self, xcy, ycy):
        """|dz/dx| + |dz/dy| in mm per yard, central difference over one yard."""
        gx = (self.z_at(xcy + CY, ycy) - self.z_at(xcy - CY, ycy)) // 2
        gy = (self.z_at(xcy, ycy + CY) - self.z_at(xcy, ycy - CY)) // 2
        return gx, gy

    def elev_mm(self):
        """Height change that drives the elevation axes: end to end, or 60% of the relief range if larger."""
        return max(abs(self.green_z - self.tee_z), self.relief_range * P["relief"]["range_pm"] // 1000)

    def canonical_bytes(self):
        """Spec 2.1 canonical content: tee, green, z, sorted features, rock/flower counts, sorted trees."""
        b = bytearray()
        b += i32le(self.tee[0] // CY) + i32le(self.tee[1] // CY)
        b += i32le(self.gc[0] // CY) + i32le(self.gc[1] // CY) + i32le(self.gr)
        b += i32le(self.tee_z) + i32le(self.green_z)
        rows = []
        for t in FEATURE_TYPES:
            for r in self.rects[t]:
                rows.append((TYPE_CODE[t], 0) + tuple(v // CY for v in r))
            for c in self.circles[t]:
                rows.append((TYPE_CODE[t], 1) + tuple(v // CY for v in c))
        rows.sort()
        b += i32le(len(rows))
        for r in rows:
            for v in r:
                b += i32le(v)
        b += i32le(self.counts["rock"]) + i32le(self.counts["flower"]) + i32le(len(self.trees))
        for (tx, ty) in self.trees:
            b += i32le(tx // CY) + i32le(ty // CY)
        if self.relief is not None:
            r = self.relief
            b += b"RLF1" + i32le(r["x0"]) + i32le(r["y0"]) + i32le(r["step"]) + i32le(r["cols"]) + i32le(r["rows"])
            for v in r["z"]:
                b += i32le(v)
        return bytes(b)

    def content_hash(self):
        return hash64(self.canonical_bytes()) if self.valid else ""

    def in_type(self, t, pt):
        x, y = pt
        for (x0, y0, x1, y1) in self.rects[t]:
            if x0 <= x <= x1 and y0 <= y <= y1:
                return True
        for (cx, cy, r) in self.circles[t]:
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                return True
        return False

    def lie_at(self, pt):
        x, y = pt
        if x < -12000 or x > 12000 or y < -3000 or y > self.L * CY + 8000 or self.in_type("ob", pt):
            return LIE_OB
        if self.in_type("water", pt):
            return LIE_WATER
        d2 = (x - self.gc[0]) ** 2 + (y - self.gc[1]) ** 2
        if d2 <= (self.gr * CY) ** 2:
            return LIE_GREEN
        if d2 <= ((self.gr + 3) * CY) ** 2:
            return LIE_FRINGE
        if self.in_type("bunker", pt):
            return LIE_BUNKER
        if self.in_type("fairway", pt):
            return LIE_FAIRWAY
        if self.in_type("deep_rough", pt):
            return LIE_DEEP
        return LIE_ROUGH

    def tree_hit(self, a, b, tmax_pm):
        ax, ay = a
        bx, by = b
        ex, ey = bx - ax, by - ay
        e2 = ex * ex + ey * ey
        r = 200
        best = None
        x0, x1 = min(ax, bx), max(ax, bx)
        y0, y1 = min(ay, by), max(ay, by)
        for bxk in range((x0 - r) // 1000, (x1 + r) // 1000 + 1):
            for byk in range((y0 - r) // 1000, (y1 + r) // 1000 + 1):
                for (tx, ty) in self.tree_buckets.get((bxk, byk), ()):
                    if e2 == 0:
                        t_pm = 0
                    else:
                        t_pm = clamp(((tx - ax) * ex + (ty - ay) * ey) * 1000 // e2, 0, 1000)
                    px = ax + ex * t_pm // 1000
                    py = ay + ey * t_pm // 1000
                    if (tx - px) ** 2 + (ty - py) ** 2 <= r * r:
                        at_end = (tx - bx) ** 2 + (ty - by) ** 2 <= r * r
                        if t_pm <= tmax_pm or at_end:
                            if best is None or t_pm < best[0]:
                                best = (t_pm, px, py)
        return best


# ------------------------------------------------------------------ input validation (untrusted)
LIMITS = dict(max_features=3000, max_trees=1500, coord_abs=1200, schema_version=1)


def is_int(v):
    if isinstance(v, bool):
        return False
    if isinstance(v, int):
        return True
    return isinstance(v, float) and v == v and v not in (float("inf"), float("-inf")) and v == int(v)


def validate_input(raw):
    """Returns (ok, code). Deterministic, never reads a claimed score. Order per spec 2.2."""
    if not isinstance(raw, dict):
        return False, "E01_NOT_OBJECT"
    sv = raw.get("schema")
    if isinstance(sv, bool) or not isinstance(sv, (int, float)) or sv != LIMITS["schema_version"]:
        return False, "E02_BAD_SCHEMA_VERSION"
    if raw.get("engine") != ENGINE:
        return False, "E03_ENGINE_MISMATCH"
    h = raw.get("hole")
    if not isinstance(h, dict) or "tee" not in h or "green" not in h or "features" not in h:
        return False, "E04_MISSING_FIELD"
    feats = h["features"]
    if isinstance(feats, dict):
        n = feats.get("_len")
        if not is_int(n):
            return False, "E04_MISSING_FIELD"
    elif isinstance(feats, list):
        n = len(feats)
    else:
        return False, "E04_MISSING_FIELD"
    if n > LIMITS["max_features"]:
        return False, "E05_TOO_MANY_OBJECTS"
    for pt, k in ((h["tee"], 2), (h["green"], 3)):
        if not isinstance(pt, list) or len(pt) != k:
            return False, "E06_TRUNCATED_OR_SHAPE"
        for v in pt:
            if not is_int(v):
                return False, "E07_NON_INTEGER"
            if abs(v) > LIMITS["coord_abs"]:
                return False, "E08_OUT_OF_RANGE"
    if h["green"][2] < 0:
        return False, "E09_NEGATIVE_SIZE"
    trees = 0
    for f in feats:
        if not isinstance(f, dict) or f.get("t") not in TYPE_CODE:
            return False, "E10_BAD_FEATURE_TYPE"
        for key, want in (("rect", 4), ("circle", 3), ("at", -1)):
            if key not in f:
                continue
            v = f[key]
            if not isinstance(v, list):
                return False, "E06_TRUNCATED_OR_SHAPE"
            if want > 0 and len(v) != want:
                return False, "E06_TRUNCATED_OR_SHAPE"
            flat = []
            for e in v:
                if key == "at":
                    if not isinstance(e, list) or len(e) != 2:
                        return False, "E06_TRUNCATED_OR_SHAPE"
                    flat += e
                else:
                    flat.append(e)
            for e in flat:
                if not is_int(e):
                    return False, "E07_NON_INTEGER"
                if abs(e) > LIMITS["coord_abs"]:
                    return False, "E08_OUT_OF_RANGE"
        t = f["t"]
        if t in FEATURE_TYPES and "rect" not in f and "circle" not in f:
            return False, "E06_TRUNCATED_OR_SHAPE"
        if "rect" in f and (f["rect"][2] < f["rect"][0] or f["rect"][3] < f["rect"][1]):
            return False, "E09_NEGATIVE_SIZE"
        if "circle" in f and f["circle"][2] < 0:
            return False, "E09_NEGATIVE_SIZE"
        if "count" in f:
            if not is_int(f["count"]):
                return False, "E07_NON_INTEGER"
            if f["count"] < 0:
                return False, "E09_NEGATIVE_SIZE"
        if t == "tree":
            trees += f["count"] if "count" in f else len(f.get("at", []))
            if trees > LIMITS["max_trees"]:
                return False, "E05_TOO_MANY_OBJECTS"
    rl = h.get("relief")
    if rl is not None:
        rp = P["relief"]
        if not isinstance(rl, dict):
            return False, "E06_TRUNCATED_OR_SHAPE"
        for k in ("x0", "y0", "step", "cols", "rows", "z"):
            if k not in rl:
                return False, "E04_MISSING_FIELD"
        if not isinstance(rl["z"], list):
            return False, "E06_TRUNCATED_OR_SHAPE"
        for k in ("x0", "y0", "step", "cols", "rows"):
            if not is_int(rl[k]):
                return False, "E07_NON_INTEGER"
        if rl["cols"] < 2 or rl["rows"] < 2 or rl["step"] < 1:
            return False, "E09_NEGATIVE_SIZE"
        if rl["cols"] * rl["rows"] > rp["max_nodes"]:
            return False, "E05_TOO_MANY_OBJECTS"
        if len(rl["z"]) != rl["cols"] * rl["rows"]:
            return False, "E06_TRUNCATED_OR_SHAPE"
        if abs(rl["x0"]) > LIMITS["coord_abs"] or abs(rl["y0"]) > LIMITS["coord_abs"] or rl["step"] > 64:
            return False, "E08_OUT_OF_RANGE"
        for v in rl["z"]:
            if not is_int(v):
                return False, "E07_NON_INTEGER"
            if abs(v) > rp["z_abs_mm"]:
                return False, "E08_OUT_OF_RANGE"
    return True, "OK"


# ------------------------------------------------------------------ golfer sim
def es_here(lie, dist_cy, skill):
    if lie == LIE_GREEN:
        v = interp(P["es_green_ft"], dist_cy * 3 // CY)
    else:
        v = interp(P["es_fw"], dist_cy // CY) + LIE_ADD[lie]
    return rdiv(v * (1350 - skill * 350 // 1000), 1000)


def carry_max(club, skill, lie):
    return CLUB_BASE[club] * CY * (600 + skill * 400 // 1000) // 1000 * LIES[lie][0] // 1000


def pick_club(desired, skill, lie):
    for i in range(11, -1, -1):
        if carry_max(i, skill, lie) >= desired:
            return i
    return 0


def pick_club_longest(skill, lie):
    for i in range(12):
        if carry_max(i, skill, lie) > 0:
            return i
    return 0


def spread_pm(skill):
    return 130 - skill * 90 // 1000


def depth_pm(skill):
    return 25 + (1000 - skill) * 35 // 1000


def mishit_pm(skill):
    return 30 + (1000 - skill) * 200 // 1000


def land(hole, bx, by, lie0, ax, ay, skill, cond, noise):
    """One ball flight. Returns (x, y, lie, pen, pen_kind, treehit, walk). pen_kind 1 water, 2 ob."""
    ux, uy, D = unit(ax - bx, ay - by)
    rp = P["relief"]
    delta = 0
    if hole.relief is not None:
        delta = (hole.z_at(ax, ay) - hole.z_at(bx, by)) // rp["cy_div"]
        lim = D * rp["delta_clamp_pm"] // 1000
        delta = clamp(delta, -lim, lim)
    want = D + delta
    ci = pick_club(want, skill, lie0)
    Deff = min(want, carry_max(ci, skill, lie0))
    disp = LIES[lie0][1]
    sgm = interp(P["short_game_mult"], Deff // CY)
    sl = Deff * spread_pm(skill) // 1000 * disp // 1000 * sgm // 1000
    sd = Deff * depth_pm(skill) // 1000 * disp // 1000 * sgm // 1000
    zl, zd, mroll, msev = noise
    dl = zl * sl // 1000
    dd = zd * sd // 1000
    if mroll < mishit_pm(skill) * LIES[lie0][2] // 1000:
        Deff = Deff * (500 + msev % 300) // 1000
        dl = dl * 2
    loft = CLUB_LOFT[ci]
    wa = (cond["wx"] * ux + cond["wy"] * uy) // 1024
    wc = (cond["wx"] * (-uy) + cond["wy"] * ux) // 1024
    along_shift = Deff * wa * 8 * loft // 1000000
    lat_shift = Deff * wc * 6 * loft // 1000000
    along = max(0, Deff - delta + dd + along_shift) * (1000 - 40 * cond.get("rain", 0)) // 1000
    lat = dl + lat_shift
    px, py = -uy, ux
    tx = bx + rdiv(ux * along + px * lat, 1024)
    ty = by + rdiv(uy * along + py * lat, 1024)
    th = hole.tree_hit((bx, by), (tx, ty), TMAX[ci])
    treehit = False
    if th is not None:
        treehit = True
        _, hx, hy = th
        bux, buy, bd = unit(hx - bx, hy - by)
        back = min(bd, 100)
        tx = hx - bux * back // 1024
        ty = hy - buy * back // 1024
        lie = hole.lie_at((tx, ty))
        if lie not in (LIE_GREEN, LIE_WATER, LIE_OB):
            lie = LIE_DEEP
    else:
        lie = hole.lie_at((tx, ty))
        if hole.relief is not None and lie not in (LIE_WATER, LIE_OB, LIE_BUNKER):
            gx, gy = hole.grad_l1(tx, ty)
            f = rp["roll_lie_pm"][lie] * (2000 - loft) // 1000
            cap = rp["roll_cap_cy"]
            rx = clamp(-gx * rp["roll_k"] * f // 1000, -cap, cap)
            ry = clamp(-gy * rp["roll_k"] * f // 1000, -cap, cap)
            if rx != 0 or ry != 0:
                tx += rx
                ty += ry
                lie = hole.lie_at((tx, ty))
                if lie == LIE_TEE:
                    lie = LIE_FAIRWAY
    walk = dist(bx, by, tx, ty)
    if lie == LIE_OB:
        return bx, by, lie0, 1, 2, treehit, walk
    if lie == LIE_WATER:
        vux, vuy, vd = unit(tx - bx, ty - by)
        step = 0
        while step * 200 < vd:
            step += 1
            cx = tx - vux * step * 200 // 1024
            cyy = ty - vuy * step * 200 // 1024
            l2 = hole.lie_at((cx, cyy))
            if l2 != LIE_WATER and l2 != LIE_OB:
                return cx, cyy, l2, 1, 1, treehit, walk
        return bx, by, lie0, 1, 1, treehit, walk
    return tx, ty, lie, 0, 0, treehit, walk


def candidates(hole, px_, py_, lie, skill):
    gx, gy = hole.gc
    ux, uy, Dg = unit(gx - px_, gy - py_)
    Dm = carry_max(pick_club_longest(skill, lie), skill, lie)
    base = min(Dm, Dg)
    sp = clamp(Dg // 16, 300, 1000)
    qx, qy = -uy, ux
    out = []
    for f in FRACS:
        dd = base * f // 1000
        for j in range(-3, 4):
            out.append((px_ + (ux * dd + qx * j * sp) // 1024, py_ + (uy * dd + qy * j * sp) // 1024))
    return out, Dg


def plan_table(hole, px_, py_, lie, skill, cond):
    """Returns (costs[28], pens[28], here). Deterministic, no RNG."""
    cands, Dg = candidates(hole, px_, py_, lie, skill)
    here = es_here(lie, Dg, skill)
    costs, pens_l = [], []
    ps = P["plan_samples"]
    for (ax, ay) in cands:
        tot = 0
        pens = 0
        for s in range(8):
            x2, y2, l2, pen, _k, _t, _w = land(hole, px_, py_, lie, ax, ay, skill, cond, (ps[s][0], ps[s][1], 999, 0))
            tot += 100 + es_here(l2, dist(x2, y2, hole.gc[0], hole.gc[1]), skill) + pen * 100
            pens += pen
        costs.append(rdiv(tot, 8))
        pens_l.append(pens)
    return costs, pens_l, here


def style_of(gid):
    r = H32(0xC0FFEE, gid) % 100
    return 0 if r < 25 else 1 if r < 75 else 2


def roster(counts=None):
    counts = counts or P["band_counts"]
    out = []
    gid = 0
    for b, n in enumerate(counts):
        lo, hi = P["band_skill_range"][b]
        for k in range(n):
            out.append((gid, b, k, lo + (hi - lo) * (2 * k + 1) // (2 * n)))
            gid += 1
    return out


def band_mid(b):
    lo, hi = P["band_skill_range"][b]
    return (lo + hi) // 2


def putt_count(d_cy, skill, roll, slope=0, drop=0):
    ft = d_cy * 3 // CY
    base = 25
    for lim, p in P["putt_p1_base"]:
        if ft <= lim:
            base = p
            break
    p1 = base * (500 + skill // 2) // 1000
    p3 = min(600, ft * 6 * (1100 - skill) // 1000)
    if slope or drop:
        rp = P["relief"]
        p1 = p1 * (1000 - min(rp["slope_p1_cap"], slope * rp["slope_p1"])) // 1000
        p3 += min(rp["slope_p3_cap"], slope * rp["slope_p3"]) + clamp(drop // rp["drop_div"], 0, rp["drop_cap"])
    if roll < p1:
        return 1
    if roll >= 1000 - p3:
        return 3
    return 2


def simulate(hole, seed, cond, counts=None):
    """Per-golfer records in gid order."""
    ros = roster(counts)
    cap = hole.par + 4
    cache = {}
    recs = []
    for (gid, band, nid, skill) in ros:
        x, y = hole.tee
        lie = LIE_TEE
        strokes = 0
        shot = 1
        flags = 0
        walk = 0
        tsec = 0
        first = None
        style = style_of(gid)
        bmid = band_mid(band)
        amp = (1000 - skill) * 30 // 1000
        while True:
            if lie == LIE_GREEN:
                slope = drop = 0
                if hole.relief is not None:
                    g1x, g1y = hole.grad_l1(x, y)
                    g2x, g2y = hole.grad_l1(hole.gc[0], hole.gc[1])
                    slope = (abs(g1x) + abs(g1y) + abs(g2x) + abs(g2y)) // 2
                    drop = hole.z_at(x, y) - hole.z_at(hole.gc[0], hole.gc[1])
                n = putt_count(dist(x, y, hole.gc[0], hole.gc[1]), skill, H32(seed, nid, shot, 4) % 1000, slope, drop)
                strokes += n
                tsec += 25 * n
                if strokes > cap:
                    strokes = cap
                    flags |= 4
                break
            key = (band, x // 400, y // 400, lie)
            if key not in cache:
                cache[key] = plan_table(hole, x // 400 * 400 + 200, y // 400 * 400 + 200, lie, bmid, cond)
            costs, pens_l, here = cache[key]
            cands, _dg = candidates(hole, x, y, lie, bmid)
            best_adj = None
            idx = 0
            for i in range(28):
                nz = rdiv(amp * ((H32(seed, gid, shot, 10 + i) & 1023) - 512), 512)
                adj = costs[i] + STYLE_W[style] * pens_l[i] + nz
                if best_adj is None or adj < best_adj:
                    best_adj = adj
                    idx = i
            pens = pens_l[idx]
            safe = False
            for i in range(28):
                if pens_l[i] <= 1 and costs[i] <= here + 160:
                    safe = True
                    break
            if pens >= 2 and safe:
                flags |= 16
            ax, ay = cands[idx]
            noise = (Z[H32(seed, nid, shot, 0) & 255], Z[H32(seed, nid, shot, 1) & 255],
                     H32(seed, nid, shot, 2) % 1000, H32(seed, nid, shot, 3))
            x2, y2, l2, pen, kind, th, w = land(hole, x, y, lie, ax, ay, skill, cond, noise)
            strokes += 1 + pen
            walk += w
            tsec += 40 + (30 if lie == LIE_BUNKER else 0) + (90 if kind == 1 else 0) + (150 if kind == 2 else 0)
            if th:
                flags |= 8
            if pen:
                if pens >= 2 and safe:
                    flags |= 2
                elif pens >= 2:
                    flags |= 1
                else:
                    flags |= 32
            if first is None:
                first = (x2, y2)
            x, y, lie = x2, y2, l2
            if lie == LIE_TEE:
                lie = LIE_FAIRWAY
            shot += 1
            if strokes >= cap or shot > 40:
                strokes = cap
                flags |= 4
                break
        tsec += walk * 6 // 1000
        recs.append(dict(gid=gid, band=band, skill=skill, strokes=strokes, flags=flags, time_s=tsec,
                         first=first if first else (0, 0)))
    return recs


def sim_hash(seed, recs):
    b = bytearray(ENGINE.encode() + b"|" + SIM.encode() + b"|")
    b += i32le(seed) + i32le(len(recs))
    for r in recs:
        b += i32le(r["gid"]) + i32le(r["strokes"]) + i32le(r["flags"]) + i32le(r["time_s"])
        b += i32le(r["first"][0]) + i32le(r["first"][1])
    return hash64(bytes(b))
