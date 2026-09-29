#!/usr/bin/env python3
"""Reference model for MHRATE-1.0.0 / MHSIM-1.0.0 (Mulligan Hills rating engine).

Integer-only in the simulation and rating path (no float, no random module).
Reads normative tables from docs/spec/rating/params.json and test cases from
docs/spec/fixtures/rating/*.json. Run:  python3 tools/reference/rating_sanity.py
This is a sanity model, not the shipping code. GDScript must reproduce its
numbers exactly (golden hashes are in fixture 08).
"""
import json, os, sys, glob
from math import isqrt

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
P = json.load(open(os.path.join(ROOT, "docs/spec/rating/params.json")))
M32 = 0xFFFFFFFF
Z = P["z256"]
CY = 100  # centiyards per yard


# ---------------------------------------------------------------- integer helpers
def rdiv(a, b):
    """Round-half-away-from-zero integer division, b > 0."""
    if a >= 0:
        return (2 * a + b) // (2 * b)
    return -((-2 * a + b) // (2 * b))


def clamp(x, lo, hi):
    return lo if x < lo else hi if x > hi else x


def interp(table, x):
    """Piecewise-linear over [[x,y],...] ascending, integer, round half away."""
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


def fnv_lane(data, basis):
    h = basis
    for b in data:
        h = ((h ^ b) * 16777619) & M32
    return h


def hash64(data):
    return "%08x%08x" % (fnv_lane(data, 0x811C9DC5), fnv_lane(data, 0x9747B28C))


def i32le(v):
    return (v & M32).to_bytes(4, "little")


# ---------------------------------------------------------------- hole model
def par_for(L):
    lim = P["par_limits"]
    return 3 if L <= lim[0] else 4 if L <= lim[1] else 5


class Hole:
    def __init__(self, d):
        self.d = d
        self.valid = True
        self.reasons = []
        self.slot = d.get("slot_id", 1)
        tee, green = d.get("tee"), d.get("green")
        feats = d.get("features", [])
        if tee is None:
            self.valid = False; self.reasons.append("RC001")
        if green is None:
            self.valid = False; self.reasons.append("RC002")
        if len(feats) > 3000:
            self.valid = False; self.reasons.append("RC005")
        self.rects = {}
        self.circles = {}
        self.trees = []
        self.counts = {}
        if not self.valid:
            return
        self.tee = (tee[0] * CY, tee[1] * CY)
        self.gc = (green[0] * CY, green[1] * CY)
        self.gr = green[2]
        dx, dy = green[0] - tee[0], green[1] - tee[1]
        self.L = isqrt(dx * dx + dy * dy)
        self.par = par_for(self.L)
        self.tee_z = d.get("tee_z_mm", 0)
        self.green_z = d.get("green_z_mm", 0)
        for f in feats:
            t = f["t"]
            if t == "tree":
                pts = []
                if "at" in f:
                    pts = [tuple(p) for p in f["at"]]
                else:
                    x0, y0, x1, y1 = f["rect"]
                    n = f["count"]
                    area = max(1, (x1 - x0) * (y1 - y0))
                    s = max(1, isqrt(area // max(1, n)))
                    nx = max(1, (x1 - x0) // s)
                    k = 0
                    j = 0
                    while k < n and y0 + s // 2 + j * s <= y1:
                        for i in range(nx):
                            if k >= n:
                                break
                            pts.append((x0 + s // 2 + i * s, y0 + s // 2 + j * s))
                            k += 1
                        j += 1
                self.trees += [(p[0] * CY, p[1] * CY) for p in pts]
                continue
            if t in ("rock", "flower"):
                self.counts[t] = self.counts.get(t, 0) + f.get("count", len(f.get("at", [])) or 1)
                continue
            if "rect" in f:
                self.rects.setdefault(t, []).append(tuple(v * CY for v in f["rect"]))
            elif "circle" in f:
                self.circles.setdefault(t, []).append(tuple(v * CY for v in f["circle"]))
        self.counts["tree"] = len(self.trees)
        self.tree_buckets = {}
        for (tx, ty) in sorted(self.trees):
            self.tree_buckets.setdefault((tx // 1000, ty // 1000), []).append((tx, ty))
        gd = self.d.get("green_hazard_check", True)
        if gd and self.in_type("water", self.gc) or self.in_type("ob", self.gc):
            self.valid = False; self.reasons.append("RC004")
        if self.in_type("water", self.tee) or self.in_type("ob", self.tee):
            self.valid = False; self.reasons.append("RC008")
        if self.L < 60 or self.L > 1000:
            self.valid = False; self.reasons.append("RC003")
        if self.gr < 5 or self.gr > 30:
            self.valid = False; self.reasons.append("RC006")

    def in_type(self, t, pt):
        x, y = pt
        for (x0, y0, x1, y1) in self.rects.get(t, ()):
            if x0 <= x <= x1 and y0 <= y <= y1:
                return True
        for (cx, cy, r) in self.circles.get(t, ()):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                return True
        return False

    def lie_at(self, pt):
        x, y = pt
        L = self.L * CY
        if x < -12000 or x > 12000 or y < -3000 or y > L + 8000 or self.in_type("ob", pt):
            return "ob"
        if self.in_type("water", pt):
            return "water"
        d2 = (x - self.gc[0]) ** 2 + (y - self.gc[1]) ** 2
        if d2 <= (self.gr * CY) ** 2:
            return "green"
        if d2 <= ((self.gr + 3) * CY) ** 2:
            return "fringe"
        if self.in_type("bunker", pt):
            return "bunker"
        if self.in_type("fairway", pt):
            return "fairway"
        if self.in_type("deep_rough", pt):
            return "deep"
        return "rough"

    def tree_hit(self, a, b, tmax_pm):
        """First tree intercepting segment a->b (t<=tmax) or covering b. Returns point or None."""
        ax, ay = a
        bx, by = b
        ex, ey = bx - ax, by - ay
        e2 = ex * ex + ey * ey
        r = 200
        best = None
        x0, x1 = sorted((ax, bx))
        y0, y1 = sorted((ay, by))
        for bxk in range((x0 - r) // 1000, (x1 + r) // 1000 + 1):
            for byk in range((y0 - r) // 1000, (y1 + r) // 1000 + 1):
                for (tx, ty) in self.tree_buckets.get((bxk, byk), ()):
                    if e2 == 0:
                        t_pm = 0
                    else:
                        t_pm = clamp(((tx - ax) * ex + (ty - ay) * ey) * 1000 // e2, 0, 1000)
                    px = ax + ex * t_pm // 1000
                    py = ay + ey * t_pm // 1000
                    d2 = (tx - px) ** 2 + (ty - py) ** 2
                    if d2 <= r * r:
                        at_end = (tx - bx) ** 2 + (ty - by) ** 2 <= r * r
                        if t_pm <= tmax_pm or at_end:
                            if best is None or t_pm < best[0]:
                                best = (t_pm, px, py)
        return best


# ---------------------------------------------------------------- sim
def es_here(lie, dist_cy, skill):
    """Expected strokes remaining, x100, for decision making (tables in params)."""
    if lie == "green":
        v = interp(P["es_green_ft"], dist_cy * 3 // CY)
    else:
        v = interp(P["es_fw"], dist_cy // CY) + P["lie_add"][lie]
    scale = 1350 - skill * 350 // 1000
    return rdiv(v * scale, 1000)


def dist(a, b):
    return isqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2)


def unit(dx, dy):
    d = isqrt(dx * dx + dy * dy)
    if d == 0:
        return 0, 1024, 0
    return rdiv(dx * 1024, d), rdiv(dy * 1024, d), d


def carry_max(club_i, skill, lie):
    base = P["clubs"][club_i][1] * CY
    return base * (600 + skill * 400 // 1000) // 1000 * P["lies"][lie][0] // 1000


def pick_club(desired_cy, skill, lie):
    n = len(P["clubs"])
    for i in range(n - 1, -1, -1):  # shortest club first (LW is last)
        if carry_max(i, skill, lie) >= desired_cy:
            return i
    return 0


def spread_pm(skill):
    return 130 - skill * 90 // 1000


def depth_pm(skill):
    return 25 + (1000 - skill) * 35 // 1000


def mishit_pm(skill):
    return 30 + (1000 - skill) * 200 // 1000


def wind_terms(cond, ux, uy, D, loft):
    wa = (cond["wx"] * ux + cond["wy"] * uy) // 1024
    wc = (cond["wx"] * (-uy) + cond["wy"] * ux) // 1024
    along = D * wa * 8 * loft // 1000000
    lat = D * wc * 6 * loft // 1000000
    return along, lat


def land(hole, ball, lie0, aim, skill, cond, noise):
    """Resolve one shot. noise=(zl,zd,mishit_roll,mishit_sev). Returns (pos, lie, pen, treehit, walk_cy)."""
    ux, uy, D = unit(aim[0] - ball[0], aim[1] - ball[1])
    ci = pick_club(D, skill, lie0)
    Dm = carry_max(ci, skill, lie0)
    Deff = min(D, Dm)
    disp = P["lies"][lie0][1]
    sgm = interp(P["short_game_mult"], Deff // CY)
    sl = Deff * spread_pm(skill) // 1000 * disp // 1000 * sgm // 1000
    sd = Deff * depth_pm(skill) // 1000 * disp // 1000 * sgm // 1000
    zl, zd, mroll, msev = noise
    dl = zl * sl // 1000
    dd = zd * sd // 1000
    if mroll < mishit_pm(skill) * P["lies"][lie0][2] // 1000:
        Deff = Deff * (500 + msev % 300) // 1000
        dl *= 2
    loft = P["club_loft_pm"][ci]
    wa, wl = wind_terms(cond, ux, uy, Deff, loft)
    along = max(0, Deff + dd + wa) * (1000 - 40 * cond.get("rain", 0)) // 1000
    lat = dl + wl
    px, py = -uy, ux
    tx = ball[0] + rdiv(ux * along + px * lat, 1024)
    ty = ball[1] + rdiv(uy * along + py * lat, 1024)
    tgt = (tx, ty)
    # trees
    tmax = [600, 550, 450, 400, 350, 300, 280, 260, 240, 220, 200, 200][ci]
    th = hole.tree_hit(ball, tgt, tmax)
    treehit = False
    if th is not None:
        treehit = True
        _, hx, hy = th
        bux, buy, bd = unit(hx - ball[0], hy - ball[1])
        back = min(bd, 100)
        tgt = (hx - bux * back // 1024, hy - buy * back // 1024)
        lie = hole.lie_at(tgt)
        if lie in ("fairway", "rough", "fringe", "tee"):
            lie = "deep"
        if lie == "green":
            lie = "green"
    else:
        lie = hole.lie_at(tgt)
    pen = 0
    walk = dist(ball, tgt)
    if lie == "ob":
        pen = 1
        return ball, lie0, pen, treehit, walk
    if lie == "water":
        pen = 1
        vx, vy = tgt[0] - ball[0], tgt[1] - ball[1]
        vux, vuy, vd = unit(vx, vy)
        step = 0
        cur = tgt
        found = False
        while step * 200 < vd:
            step += 1
            cur = (tgt[0] - vux * step * 200 // 1024, tgt[1] - vuy * step * 200 // 1024)
            l2 = hole.lie_at(cur)
            if l2 not in ("water", "ob"):
                found = True
                break
        if not found:
            return ball, lie0, pen, treehit, walk
        return cur, hole.lie_at(cur), pen, treehit, walk
    return tgt, lie, pen, treehit, walk


LATS = (-3, -2, -1, 0, 1, 2, 3)
FRACS = (1000, 850, 700, 550)


def candidates(hole, pos, lie, skill):
    gx, gy = hole.gc
    ux, uy, Dg = unit(gx - pos[0], gy - pos[1])
    Dm = carry_max(pick_club_longest(skill, lie), skill, lie)
    base = min(Dm, Dg)
    sp = clamp(Dg // 16, 300, 1000)
    out = []
    px, py = -uy, ux
    for fi, f in enumerate(FRACS):
        dd = base * f // 1000
        for j in LATS:
            ax = pos[0] + (ux * dd + px * j * sp) // 1024
            ay = pos[1] + (uy * dd + py * j * sp) // 1024
            out.append((fi, j, (ax, ay)))
    return out, Dg


def pick_club_longest(skill, lie):
    for i in range(len(P["clubs"])):
        if carry_max(i, skill, lie) > 0:
            return i
    return 0


def plan_table(hole, pos, lie, skill, cond):
    """Per-candidate (mean_cost_x100, pen_eighths, cand list). Deterministic, no RNG."""
    cands, Dg = candidates(hole, pos, lie, skill)
    here = es_here(lie, Dg, skill) if lie != "tee" else es_here("fairway", Dg, skill)
    tab = []
    ps = P["plan_samples"]
    for (fi, j, aim) in cands:
        tot = 0
        pens = 0
        for s in range(8):
            noise = (ps[s][0], ps[s][1], 999, 0)
            p2, l2, pen, th, _ = land(hole, pos, lie, aim, skill, cond, noise)
            if l2 == "green":
                v = es_here("green", dist(p2, hole.gc), skill)
            else:
                v = es_here(l2 if l2 != "tee" else "fairway", dist(p2, hole.gc), skill)
            tot += 100 + v + pen * 100 + (0)
            pens += pen
        tab.append((rdiv(tot, 8), pens, fi, j))
    return tab, here


STYLE_W = {0: 0, 1: 8, 2: 30}  # aggressive, neutral, cautious per penalty-eighth


def style_of(gid):
    r = H32(0xC0FFEE, gid) % 100
    return 0 if r < 25 else 1 if r < 75 else 2


def roster():
    out = []
    gid = 0
    for b, n in enumerate(P["band_counts"]):
        lo, hi = P["band_skill_range"][b]
        for k in range(n):
            out.append((gid, b, lo + (hi - lo) * (2 * k + 1) // (2 * n)))
            gid += 1
    return out


def band_mid(b):
    lo, hi = P["band_skill_range"][b]
    return (lo + hi) // 2


def putt_count(d_cy, skill, roll):
    ft = d_cy * 3 // CY
    base = interp([[0, P["putt_p1_base"][0][1]]] + P["putt_p1_base"], ft) if False else None
    for lim, p in P["putt_p1_base"]:
        if ft <= lim:
            base = p
            break
    p1 = base * (500 + skill // 2) // 1000
    p3 = min(600, ft * 6 * (1100 - skill) // 1000)
    if roll < p1:
        return 1
    if roll >= 1000 - p3:
        return 3
    return 2


def hole_seed(secret, epoch, slot):
    return H32(secret, epoch, slot, 0x4D48)


def simulate(hole, seed, cond, ros=None):
    """Returns list of per-golfer dict records in gid order."""
    ros = ros or roster()
    cap = hole.par + 4
    cache = {}
    recs = []
    kin = {}
    for (gid, band, skill) in ros:
        kin[gid] = sum(1 for g2, b2, _ in ros if b2 == band and g2 < gid)
    for (gid, band, skill) in ros:
        nid = kin[gid]  # noise stream id: index within band (common random numbers across bands)
        pos, lie = hole.tee, "tee"
        strokes = 0
        shot = 1
        flags = 0  # 1 unchosen pen, 2 chosen pen, 4 pickup, 8 treehit
        walk = 0
        tsec = 0
        first_land = None
        holed = False
        style = style_of(gid)
        while True:
            if lie == "green":
                n = putt_count(dist(pos, hole.gc), skill, H32(seed, nid, shot, 4) % 1000)
                strokes += n
                tsec += 25 * n
                if strokes > cap:
                    strokes = cap
                    flags |= 4
                holed = True
                break
            bmid = band_mid(band)
            key = (band, pos[0] // 400, pos[1] // 400, lie)
            if key not in cache:
                cpos = (pos[0] // 400 * 400 + 200, pos[1] // 400 * 400 + 200)
                cache[key] = plan_table(hole, cpos, lie, bmid, cond)
            tab, here = cache[key]
            cands, Dg = candidates(hole, pos, lie, bmid)
            amp = (1000 - skill) * 30 // 1000
            best = None
            for idx, (cost, pens, fi, j) in enumerate(tab):
                nz = rdiv(amp * ((H32(seed, gid, shot, 10 + idx) & 1023) - 512), 512)
                adj = cost + STYLE_W[style] * pens + nz
                if best is None or adj < best[0]:
                    best = (adj, idx)
            idx = best[1]
            cost, pens, fi, j = tab[idx]
            aim = cands[idx][2]
            if pens >= 2 and any(c[1] <= 1 and c[0] <= here + 160 for c in tab):
                flags |= 16
            noise = (Z[H32(seed, nid, shot, 0) & 255], Z[H32(seed, nid, shot, 1) & 255],
                     H32(seed, nid, shot, 2) % 1000, H32(seed, nid, shot, 3))
            p2, l2, pen, th, w = land(hole, pos, lie, aim, skill, cond, noise)
            strokes += 1 + pen
            walk += w
            tsec += 40 + (30 if lie == "bunker" else 0) + (90 if pen and l2 != "ob" else 0) + (150 if pen and hole.lie_at(aim) == "ob" else 0)
            if th:
                flags |= 8
            if pen:
                safe = any(c[1] <= 1 and c[0] <= here + 160 for c in tab)
                if pens >= 2 and safe:
                    flags |= 2      # chosen risk that went wrong
                elif pens >= 2:
                    flags |= 1      # forced: no safe option existed
                else:
                    flags |= 32     # variance (mishit on a safe aim), not counted against fairness
            if first_land is None:
                first_land = p2
            pos, lie = p2, l2
            if lie == "tee":
                lie = "fairway"
            shot += 1
            if strokes >= cap:
                strokes = cap
                flags |= 4
                break
            if shot > 40:
                strokes = cap
                flags |= 4
                break
        tsec += walk * 6 // 1000  # 0.6 s per yard
        recs.append({"gid": gid, "band": band, "skill": skill, "strokes": strokes, "flags": flags,
                     "time_s": tsec, "first": first_land})
    return recs


def sim_hash(hole, seed, recs, engine=P["engine_version"]):
    b = bytearray(engine.encode() + b"|" + P["sim_version"].encode() + b"|")
    b += i32le(seed) + i32le(len(recs))
    for r in recs:
        b += i32le(r["gid"]) + i32le(r["strokes"]) + i32le(r["flags"]) + i32le(r["time_s"])
        fx, fy = r["first"] if r["first"] else (0, 0)
        b += i32le(fx) + i32le(fy)
    return hash64(bytes(b))


# ---------------------------------------------------------------- rating
def band_means(recs):
    out = []
    for b in range(6):
        xs = [r["strokes"] for r in recs if r["band"] == b]
        out.append(rdiv(sum(xs) * 100, len(xs)))
    return out


def components(tab, bc_slack=25, max_pen=2):
    bc = min(t[0] for t in tab)
    viable = {}
    for t in tab:
        if t[0] <= bc + bc_slack and t[1] <= max_pen:
            viable[(t[2], t[3])] = True
    seen = set()
    comps = 0
    for k in sorted(viable):
        if k in seen:
            continue
        comps += 1
        stack = [k]
        seen.add(k)
        while stack:
            a = stack.pop()
            for di in (-1, 0, 1):
                for dj in (-1, 0, 1):
                    nb = (a[0] + di, a[1] + dj)
                    if nb in viable and nb not in seen:
                        seen.add(nb)
                        stack.append(nb)
    return max(comps, 1)


def decision_probe(hole, cond):
    """Band-representative neutral planner at the tee and at the second shot.
    Returns (components for band C, number of bands taking a chosen risk)."""
    comps = 1
    n_aggr = 0
    for b in range(6):
        sk = band_mid(b)
        pos, lie = hole.tee, "tee"
        aggr = False
        for step in range(2):
            tab, here = plan_table(hole, pos, lie, sk, cond)
            key = lambda i: (tab[i][0] + STYLE_W[1] * tab[i][1], i)
            chosen = min(range(len(tab)), key=key)
            safe_exists = any(t[1] <= 1 and t[0] <= here + 160 for t in tab)
            if tab[chosen][1] >= 2 and safe_exists:
                aggr = True
            if b == 2:
                comps = max(comps, components(tab))
            cands, Dg = candidates(hole, pos, lie, sk)
            aim = cands[chosen][2]
            l2 = hole.lie_at(aim)
            if l2 in ("water", "ob", "green") or dist(aim, hole.gc) < 4000 or hole.par == 3:
                break
            pos, lie = aim, ("fairway" if l2 == "tee" else l2)
        if aggr:
            n_aggr += 1
    return comps, n_aggr


def corridor_runs(hole):
    """Geometric option count: max number of separate playable corridors (>= 12 yd wide) over 4 slices."""
    best = 0
    gx = hole.gc[0] - hole.tee[0]
    gy = hole.gc[1] - hole.tee[1]
    L = max(1, hole.L)
    for pct in (25, 40, 55, 70):
        s = L * pct // 100
        runs = 0
        run = 0
        for lat in range(-60, 62, 2):
            px = hole.tee[0] + (gx * s - gy * lat) // L
            py = hole.tee[1] + (gy * s + gx * lat) // L
            pt = (px, py)
            lie = hole.lie_at(pt)
            blocked = lie in ("water", "ob", "bunker", "deep")
            if not blocked and hole.tree_hit(pt, pt, 1000) is not None:
                blocked = True
            if blocked:
                if run >= 6:
                    runs += 1
                run = 0
            else:
                run += 1
        if run >= 6:
            runs += 1
        best = max(best, runs)
    return best


def length_score(L):
    return interp(P["length_table"], L)


def beauty(hole, PQ):
    L = max(1, hole.L)
    gx = hole.gc[0] - hole.tee[0]
    gy = hole.gc[1] - hole.tee[1]
    Lc = isqrt(gx * gx + gy * gy)
    # polish
    pol = 0
    if hole.valid:
        pol = 100
        n = 0
        ok = 0
        for yy in range(0, hole.L, 10):
            xx = hole.tee[0] + gx * yy * CY // max(1, hole.L * CY)
            n += 1
            pt = (xx, hole.tee[1] + yy * CY)
            if hole.lie_at(pt) in ("fairway", "green", "fringe"):
                ok += 1
        if n and ok * 100 >= 60 * n:
            pol += 50
    # trees: dedupe 3 yd cells, corridor 60 yd, cap 60
    cells = set()
    for (tx, ty) in hole.trees:
        rel = ((tx - hole.tee[0]) * gy - (ty - hole.tee[1]) * gx) // max(1, Lc)
        if abs(rel) <= 60 * CY and -1000 <= ty <= hole.L * CY + 3000:
            cells.add((tx // 300, ty // 300))
    n_tree = min(60, len(cells))
    tr = 120 * n_tree // (n_tree + 25)
    # water view (sampled 4 yd grid within corridor)
    wa = 0
    for xi in range(-60, 61, 4):
        for yi in range(0, hole.L + 1, 4):
            if hole.in_type("water", (xi * CY + hole.tee[0], yi * CY + hole.tee[1])):
                wa += 16
    wat = 120 * wa // (wa + 800)
    cats = 0
    cats += 1 if n_tree >= 3 else 0
    cats += 1 if hole.counts.get("rock", 0) >= 1 else 0
    cats += 1 if hole.counts.get("flower", 0) >= 3 else 0
    cats += 1 if wa >= 200 else 0
    cats += 1 if hole.rects.get("bunker") or hole.circles.get("bunker") else 0
    var = 25 * cats
    dz = abs(hole.green_z - hole.tee_z)
    rel_ = min(100, dz * 100 // 5486)
    B = pol + tr + wat + var + rel_
    return clamp(B, 0, 700), min(700, B), dict(pol=pol, tr=tr, wat=wat, var=var, rel=rel_)


def rate_hole(hole, seed, cond, want_recs=False):
    if not hole.valid:
        return dict(valid=False, score_pm=0, score=0, A=0, I=0, Len=0, B=0, F=0, reasons=hole.reasons, par=0)
    recs = simulate(hole, seed, cond)
    par = hole.par
    bm = band_means(recs)
    n = len(recs)
    # unplayable check
    a_pick = sum(1 for r in recs if r["band"] == 0 and r["flags"] & 4)
    if a_pick == P["band_counts"][0]:
        return dict(valid=False, score_pm=0, score=0, A=0, I=0, Len=0, B=0, F=0, reasons=["RC007"], par=par, means=bm)
    # Accuracy
    # spread = fitted strokes(x100) difference across a reference skill gap of 530, by least squares over all golfers
    n_g = len(recs)
    sk_sum = sum(r["skill"] for r in recs)
    st_sum = sum(r["strokes"] for r in recs)
    sxy = sum((r["skill"] * n_g - sk_sum) * (r["strokes"] * n_g - st_sum) for r in recs)
    sxx = sum((r["skill"] * n_g - sk_sum) ** 2 for r in recs)
    spread = max(0, rdiv(-sxy * 100 * 530, sxx)) if sxx else 0
    T = P["acc_target"][str(par)]
    if spread <= T:
        A = 1000 * max(0, spread) // T
    else:
        A = max(400, 1000 - (spread - T) * 600 // T)
    inv = sum(1 for i in range(5) if bm[i + 1] < bm[i] - 15)
    A = clamp(A - min(300, 100 * inv), 0, 1000)
    # Fairness
    unch = sum(1 for r in recs if r["flags"] & 1) * 1000 // n
    pick = sum(1 for r in recs if r["flags"] & 4) * 1000 // n
    blk = sum(1 for r in recs if r["flags"] & 8) * 1000 // n
    over = max(0, bm[2] - (par * 100 + 180))
    P1 = min(700, unch * 2)
    P2 = min(200, 2 * pick)
    P3 = min(100, blk)
    P4 = min(250, 2 * over)
    F = clamp(1000 - P1 - P2 - P3 - P4, 0, 1000)
    # Imagination
    raw_corr = corridor_runs(hole)
    comps = max(1, raw_corr)
    Oc = 0 if comps <= 1 else 800 if comps == 2 else 1000
    risk = sum(1 for r in recs if r["flags"] & 16) * 1000 // n
    n_aggr = risk
    R = 0
    if Oc > 0:
        if risk < 150:
            R = 300 + 700 * risk // 150
        elif risk <= 500:
            R = 1000
        elif risk <= 750:
            R = 1000 - (risk - 500) * 700 // 250
        else:
            R = max(0, 300 - (risk - 750) * 300 // 250)
    # shape
    bend = 0
    if par > 3:
        xs = sorted(r["first"][0] for r in recs if r["band"] == 2)
        ys = sorted(r["first"][1] for r in recs if r["band"] == 2)
        mx, my = xs[(len(xs) - 1) // 2], ys[(len(ys) - 1) // 2]
        a = (mx - hole.tee[0], my - hole.tee[1])
        b = (hole.gc[0] - mx, hole.gc[1] - my)
        la, lb = isqrt(a[0] ** 2 + a[1] ** 2), isqrt(b[0] ** 2 + b[1] ** 2)
        if la > 0 and lb > 0:
            bend = abs(a[0] * b[1] - a[1] * b[0]) * 1000 // (la * lb)
    bend_s = min(1000, max(0, bend - 60) * 1000 // 240)
    elev = min(1000, abs(hole.green_z - hole.tee_z) * 1000 // 5486)
    shape = (600 * bend_s + 400 * elev) // 1000
    I = (450 * Oc + 350 * R + 200 * shape) // 1000
    I = I * min(1000, 2 * F) // 1000
    Ln = length_score(hole.L)
    PQ = (A + I + Ln + F) // 4
    Braw, _, bparts = beauty(hole, PQ)
    B = min(Braw, PQ + 300)
    W = P["hole_weights"]
    base = (W["A"] * A + W["I"] * I + W["L"] * Ln + W["B"] * B) // 1000
    m = 400 + 600 * F // 1000
    score = base * m // 1000
    cs = [r["time_s"] for r in recs if r["band"] == 2]
    pace = sum(cs) * 1000 // (len(cs) * P["pace_std_s"][str(par)])
    pace_pen = clamp((pace - 1150) // 4, 0, 80)
    score = clamp(score - pace_pen, 0, 1000)
    out = dict(valid=True, score_pm=score, score=rdiv(score, 10), A=A, I=I, Len=Ln, B=B, F=F, par=par,
               means=bm, unch=unch, pick=pick, comps=comps, raw_corr=raw_corr, n_aggr=n_aggr, pace=pace, Braw=Braw, bparts=bparts,
               hash=sim_hash(hole, seed, recs))
    if want_recs:
        out["recs"] = recs
    return out


# ---------------------------------------------------------------- course roll-up
def descriptor(hole):
    """72 coverage cells (6 along x 3 |lateral| bands x 4 types) in the hole frame. Mirror invariant."""
    if not hole.valid:
        return None
    gx = hole.gc[0] - hole.tee[0]
    gy = hole.gc[1] - hole.tee[1]
    L = max(1, hole.L)
    cells = [0] * 72
    counts = [0] * 18
    for s in range(0, L, 4):
        for lat in range(-50, 51, 4):
            px = hole.tee[0] + (gx * s - gy * lat) // L
            py = hole.tee[1] + (gy * s + gx * lat) // L
            a = min(5, s * 6 // L)
            ab = abs(lat)
            band = 0 if ab <= 10 else 1 if ab <= 25 else 2
            c = a * 3 + band
            counts[c] += 1
            if hole.in_type("water", (px, py)):
                cells[c * 4 + 0] += 1
            if hole.in_type("bunker", (px, py)):
                cells[c * 4 + 1] += 1
            if hole.in_type("ob", (px, py)):
                cells[c * 4 + 3] += 1
    for (tx, ty) in hole.trees:
        rx, ry = tx - hole.tee[0], ty - hole.tee[1]
        s_yd = (rx * gx + ry * gy) // (L * CY) // CY
        lat_yd = (rx * (-gy) + ry * gx) // (L * CY) // CY
        if 0 <= s_yd < L and abs(lat_yd) <= 50:
            a = min(5, s_yd * 6 // L)
            ab = abs(lat_yd)
            band = 0 if ab <= 10 else 1 if ab <= 25 else 2
            cells[(a * 3 + band) * 4 + 2] += 1
    out = []
    for c in range(18):
        tot = max(1, counts[c])
        for t in range(4):
            v = cells[c * 4 + t]
            out.append(min(1000, v * 1000 // tot if t != 2 else v * 1000 // 20))
    return out


def similarity(h1, d1, h2, d2, bend1=0, bend2=0):
    if d1 is None or d2 is None:
        return 0
    Dc = sum(abs(a - b) for a, b in zip(d1, d2)) // 3
    dz = abs((h1.green_z - h1.tee_z) - (h2.green_z - h2.tee_z)) // 914
    pen = Dc + 3 * abs(h1.L - h2.L) + 5 * dz + 20 * abs(h1.par - h2.par)
    return 1000 - min(1000, pen)


def dup_factor(S):
    return 1000 if S <= 700 else 1000 - 2 * (S - 700)


def rollup(holes, results):
    n = len(holes)
    ds = [descriptor(h) for h in holes]
    adj = []
    facs = []
    for i in range(n):
        f = 1000
        if results[i]["valid"]:
            for j in range(i):
                if results[j]["valid"]:
                    S = similarity(holes[i], ds[i], holes[j], ds[j])
                    f = min(f, dup_factor(S))
        facs.append(f)
        adj.append(results[i]["score_pm"] * f // 1000)
    order = sorted(range(n), key=lambda i: (adj[i], i))
    k = -(-n // 3)
    W = sum(adj[i] for i in order[:k]) // k
    M = sum(adj) // n
    base = (70 * M + 30 * W) // 100
    pars = set(r["par"] for r in results if r["valid"])
    if n >= 6 and len(pars) < 2:
        base = base * 920 // 1000
    return dict(course_x10=clamp(base, 0, 1000), mean=M, low_third=W, factors=facs, adj=adj, n_dup=sum(1 for f in facs if f <= 500))


# ---------------------------------------------------------------- tournament prestige
def sustained(checkpoints):
    last = ([0] * 8 + list(checkpoints))[-8:]
    s = sorted(last)
    med = (s[3] + s[4]) // 2
    return min(med, checkpoints[-1] if checkpoints else 0)


def prestige(sustained_x10, pace_pm, fac_pts, unfair_holes, recent_events):
    course = 600 * sustained_x10 // 1000
    pace = 200 * clamp(2000 - pace_pm, 0, 1000) // 1000  # pace_pm 1000 = on standard
    fac = min(200, fac_pts)
    p = course + pace + fac - 40 * unfair_holes
    p = p * (1000 - 100 * min(5, recent_events)) // 1000
    return clamp(p, 0, 1000)



# ---------------------------------------------------------------- input validation (untrusted hole data)
LIMITS = dict(max_features=3000, max_trees=1500, coord_abs=1200, max_len=1000, min_len=60, max_json_bytes=262144,
              schema_version=1, allowed_types=("fairway", "deep_rough", "bunker", "water", "ob", "tree", "rock", "flower"))


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def validate_input(raw):
    """Deterministic reject. Returns (ok, code). Never reads a claimed score. O(size) with early count checks."""
    if not isinstance(raw, dict):
        return False, "E01_NOT_OBJECT"
    if raw.get("schema") != LIMITS["schema_version"]:
        return False, "E02_BAD_SCHEMA_VERSION"
    if raw.get("engine") != P["engine_version"]:
        return False, "E03_ENGINE_MISMATCH"
    h = raw.get("hole")
    if not isinstance(h, dict) or "tee" not in h or "green" not in h or "features" not in h:
        return False, "E04_MISSING_FIELD"
    feats = h["features"]
    n = feats.get("_len") if isinstance(feats, dict) else (len(feats) if isinstance(feats, list) else None)
    if n is None:
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
        if not isinstance(f, dict) or f.get("t") not in LIMITS["allowed_types"]:
            return False, "E10_BAD_FEATURE_TYPE"
        for key in ("rect", "circle", "at"):
            if key in f:
                vals = f[key] if key != "at" else [c for pt in f[key] for c in pt]
                for v in vals:
                    if not is_int(v):
                        return False, "E07_NON_INTEGER"
                    if abs(v) > LIMITS["coord_abs"]:
                        return False, "E08_OUT_OF_RANGE"
        if "rect" in f and (f["rect"][2] < f["rect"][0] or f["rect"][3] < f["rect"][1]):
            return False, "E09_NEGATIVE_SIZE"
        if "circle" in f and f["circle"][2] < 0:
            return False, "E09_NEGATIVE_SIZE"
        if f.get("t") == "tree":
            trees += f.get("count", len(f.get("at", [])))
    if trees > LIMITS["max_trees"]:
        return False, "E05_TOO_MANY_OBJECTS"
    return True, "OK"


# ---------------------------------------------------------------- leaderboard tie-break
def rank(entries):
    """entries: dicts with score_pm, F, recv_ms (server clock), sub_id. Best first."""
    return [e["sub_id"] for e in sorted(entries, key=lambda e: (-e["score_pm"], -e["F"], e["recv_ms"], e["sub_id"]))]


# ---------------------------------------------------------------- fixtures
CALM = {"wx": 0, "wy": 0, "rain": 0}
SECRET, EPOCH = 0x12345678, 1


def load_hole(d, slot=1):
    d = dict(d)
    d.setdefault("slot_id", slot)
    return Hole(d)


def rate_fixture_hole(d, cond=CALM, secret=SECRET, epoch=EPOCH):
    h = load_hole(d)
    return h, rate_hole(h, hole_seed(secret, epoch, h.slot if h.valid else d.get("slot_id", 1)), cond)


def main():
    files = sorted(glob.glob(os.path.join(ROOT, "docs/spec/fixtures/rating/*.json")))
    fails = 0
    for fp in files:
        fx = json.load(open(fp))
        print("==", os.path.basename(fp), "-", fx.get("title", ""))
        res = run_fixture(fx)
        for line in res["log"]:
            print("  ", line)
        for chk in res["checks"]:
            ok = chk[0]
            print("   [%s] %s" % ("PASS" if ok else "FAIL", chk[1]))
            if not ok:
                fails += 1
    print("\nTOTAL FAILS:", fails)
    return 1 if fails else 0


def fmt(r):
    if not r["valid"]:
        return "INVALID %s score=0" % ",".join(r.get("reasons", []))
    return "score=%d A=%d I=%d Len=%d B=%d F=%d par=%d means=%s unch=%d pick=%d comps=%d aggr=%d pace=%d" % (
        r["score_pm"], r["A"], r["I"], r["Len"], r["B"], r["F"], r["par"], r["means"], r["unch"], r["pick"],
        r["comps"], r["n_aggr"], r["pace"])


def run_fixture(fx):
    """Generic evaluator: fx['holes'] = {name: hole}, fx['checks'] = list of rule dicts."""
    log = []
    checks = []
    R = {}
    H = {}
    for name, hd in fx.get("holes", {}).items():
        if isinstance(hd, dict) and hd.get("_raw_invalid"):
            R[name] = dict(valid=False, score_pm=0, A=0, I=0, Len=0, B=0, F=0, reasons=["RAW"], par=0)
            continue
        h, r = rate_fixture_hole(hd)
        H[name], R[name] = h, r
        log.append("%s: %s" % (name, fmt(r)))
    kind = fx.get("kind", "holes")
    if kind == "course":
        for cname, spec in fx["courses"].items():
            hs = [H[n] for n in spec]
            rs = [R[n] for n in spec]
            ro = rollup(hs, rs)
            R["course:" + cname] = ro
            log.append("course %s: x10=%d mean=%d low_third=%d factors=%s" % (cname, ro["course_x10"], ro["mean"], ro["low_third"], sorted(set(ro["factors"]))))
    if kind == "determinism":
        for v in fx.get("hash_vectors", []):
            if v["fn"] == "H32":
                got = H32(*v["args"])
            elif v["fn"] == "hash64":
                got = hash64(bytes.fromhex(v["hex_input"]))
            elif v["fn"] == "z256_hash":
                got = hash64(b"".join(i32le(z) for z in Z))
            elif v["fn"] == "hole_seed":
                got = hole_seed(*v["args"])
            checks.append((got == v["expect"], "hash vector %s %s" % (v["fn"], v.get("args", ""))))
        h = H["base"]
        seed = hole_seed(SECRET, EPOCH, h.slot)
        hs = set()
        for _ in range(3):
            hs.add(rate_hole(h, seed, CALM)["hash"])
        R["hashes"] = hs
        R["n_hashes"] = len(hs)
        log.append("hash runs distinct=%d %s" % (len(hs), sorted(hs)))
        for name in ("nudged",):
            pass
        h2 = H["nudged"]
        r1, r2 = R["base"], R["nudged"]
        R["nudge_delta"] = abs(r1["score_pm"] - r2["score_pm"])
        # seed variance across epochs
        vals = []
        for ep in range(1, 9):
            vals.append(rate_hole(h, hole_seed(SECRET, ep, h.slot), CALM)["score_pm"])
        R["epoch_vals"] = vals
        log.append("epoch scores %s spread=%d nudge_delta=%d" % (vals, max(vals) - min(vals), R["nudge_delta"]))
        R["epoch_spread"] = max(vals) - min(vals)
    if kind == "fuzz":
        for c in fx["cases"]:
            ok, code = validate_input(c["input"])
            R["fuzz:" + c["name"]] = dict(ok=int(ok), code=code)
            log.append("fuzz %s -> %s" % (c["name"], code))
            checks.append((code == c["expect_code"], "fuzz case %s rejected with %s" % (c["name"], c["expect_code"])))
        emb = fx["embedded_score_case"]
        ok, code = validate_input(emb["input"])
        h, r = rate_fixture_hole(emb["input"]["hole"])
        R["embedded"] = dict(ok=int(ok), score_pm=r["score_pm"])
        log.append("embedded claimed score ignored: ok=%s rated=%d" % (ok, r["score_pm"]))
    if kind == "weather":
        h = H["base"]
        seed = hole_seed(SECRET, EPOCH, h.slot)
        for cn, cond in fx["conds"].items():
            r = rate_hole(h, seed, cond)
            r["mean_all"] = sum(r["means"]) // 6
            R["w:" + cn] = r
            log.append("cond %s: %s mean_all=%d" % (cn, fmt(r)[:60], r["mean_all"]))
    if kind == "ranking":
        R["order"] = rank(fx["entries"])
        log.append("order %s" % R["order"])
        checks.append((R["order"] == fx["expect_order"], "tie-break order equals expected %s" % fx["expect_order"]))
    if kind == "mirror":
        a, b = H["orig"], H["mirror"]
        S = similarity(a, descriptor(a), b, descriptor(b))
        R["sim"] = dict(S=S)
        log.append("similarity(orig,mirror)=%d" % S)
    if kind == "tournament":
        t = fx["tournament"]
        honest = t["honest_checkpoints"]
        gamed = t["gamed_checkpoints"]
        ph = prestige(sustained(honest), 1000, t["fac_pts"], 0, 0)
        pg = prestige(sustained(gamed), 1000, t["fac_pts"], 0, 0)
        R["prestige_honest"], R["prestige_gamed"] = ph, pg
        R["sust_honest"], R["sust_gamed"] = sustained(honest), sustained(gamed)
        log.append("sustained honest=%d gamed=%d ; prestige honest=%d gamed=%d" % (R["sust_honest"], R["sust_gamed"], ph, pg))
    for rule in fx.get("checks", []):
        ok = eval_rule(rule, R)
        checks.append((ok, rule["text"]))
    return dict(log=log, checks=checks)


def val(expr, R):
    """expr like 'name.F' or 'course:x.course_x10' or literal int."""
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
    if op == "eq":
        return a == rule["b"]
    b = val(rule["b"], R) + rule.get("margin", 0)
    if op == "gt":
        return a > b
    if op == "ge":
        return a >= b
    if op == "lt":
        return a < b
    if op == "le":
        return a <= b
    raise ValueError(op)


if __name__ == "__main__":
    sys.exit(main())
