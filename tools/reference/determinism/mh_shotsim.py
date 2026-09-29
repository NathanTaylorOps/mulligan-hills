"""MHShotSim / MHSimHash reference (prototype shot simulator). Mirrors
game/core/mh_hole.gd, mh_shot_sim.gd, mh_sim_hash.gd line for line."""
from mh_fixed import mul, from_int, hypot, trunc_int, tdiv
from mh_trig import sin_brad, cos_brad, atan2_brad
from mh_rng import Pcg32
from mh_hash import Fnv64

LIE_TEE = 0
LIE_FAIRWAY = 1
LIE_ROUGH = 2
LIE_BUNKER = 3
LIE_WATER = 4
LIE_GREEN = 5
LIE_TREES = 6
LIE_OB = 7

KIND_FULL = 1
KIND_PUTT_MISS = 2
KIND_PUTT_HOLE = 3
KIND_PENALTY = 4
KIND_PICKUP = 5

PARS = [4, 3, 5, 4, 4, 3, 4, 5, 4]
GRID_W = 128
CELL_SHIFT = 18  # cell = 4 m = 4 * 65536 raw = 2**18
MAX_STROKES = 12
SHOT_SECONDS = 30
PUTT_SECONDS = 45
PENALTY_SECONDS = 30
HOLE_TRANSIT_SECONDS = 120
WIND_K = 655  # 0.01 in Q16.16: wind (m/s) * dist (m) * 0.01 = drift (m)

MODE_WATER = 0
MODE_BUNKER = 1
MODE_GREEN = 2


class Hole:
    pass


def _center(tcx, tcy, pcx, pcy, cy):
    if cy <= tcy:
        return tcx
    if cy >= pcy:
        return pcx
    return tcx + tdiv((pcx - tcx) * (cy - tcy), pcy - tcy)


def _stamp(h, cx0, cy0, r, mode):
    y0 = max(cy0 - r, 0)
    y1 = min(cy0 + r, h.h - 1)
    x0 = max(cx0 - r, 0)
    x1 = min(cx0 + r, GRID_W - 1)
    for cy in range(y0, y1 + 1):
        for cx in range(x0, x1 + 1):
            dx = cx - cx0
            dy = cy - cy0
            if dx * dx + dy * dy > r * r:
                continue
            i = cy * GRID_W + cx
            cur = h.lies[i]
            if mode == MODE_WATER:
                if cur != LIE_OB:
                    h.lies[i] = LIE_WATER
            elif mode == MODE_BUNKER:
                if cur == LIE_FAIRWAY or cur == LIE_ROUGH:
                    h.lies[i] = LIE_BUNKER
            else:
                h.lies[i] = LIE_GREEN


def make_hole(course_seed, idx):
    rng = Pcg32(course_seed, 1000 + idx)
    h = Hole()
    h.par = PARS[idx % 9]
    if h.par == 3:
        length = 110 + rng.range_incl(0, 60)
    elif h.par == 4:
        length = 260 + rng.range_incl(0, 100)
    else:
        length = 400 + rng.range_incl(0, 120)
    dcx = rng.range_incl(-10, 10)
    tcx = 64
    tcy = 3
    len_cells = length // 4
    pcx = tcx + dcx
    pcy = tcy + len_cells
    h.w = GRID_W
    h.h = pcy + 12
    h.lies = bytearray(h.w * h.h)
    for cy in range(h.h):
        c = _center(tcx, tcy, pcx, pcy, cy)
        for cx in range(h.w):
            d = abs(cx - c)
            if cy > pcy + 8:
                v = LIE_OB
            elif d <= 5:
                v = LIE_FAIRWAY
            elif d <= 9:
                v = LIE_ROUGH
            elif d <= 22:
                v = LIE_TREES
            else:
                v = LIE_OB
            h.lies[cy * h.w + cx] = v
    nb = rng.range_incl(2, 5)
    bunkers = []
    for _ in range(nb):
        by = tcy + rng.range_incl(len_cells // 3, len_cells)
        bx = _center(tcx, tcy, pcx, pcy, by) + rng.range_incl(-7, 7)
        br = rng.range_incl(1, 3)
        bunkers.append((bx, by, br))
    wf = rng.range_incl(0, 1)
    water = None
    if wf == 1:
        wy = tcy + rng.range_incl(len_cells // 2, len_cells - 4)
        wx = _center(tcx, tcy, pcx, pcy, wy) + rng.range_incl(-6, 6)
        wr = rng.range_incl(2, 4)
        water = (wx, wy, wr)
    if water is not None:
        _stamp(h, water[0], water[1], water[2], MODE_WATER)
    for (bx, by, br) in bunkers:
        _stamp(h, bx, by, br, MODE_BUNKER)
    _stamp(h, pcx, pcy, 3, MODE_GREEN)
    h.tee_x = from_int(tcx * 4 + 2)
    h.tee_y = from_int(tcy * 4 + 2)
    h.pin_x = from_int(pcx * 4 + 2)
    h.pin_y = from_int(pcy * 4 + 2)
    return h


def hole_lie_hash(h):
    f = Fnv64()
    for b in h.lies:
        f.add_byte(b)
    return f.hex()


def lie_at(h, x, y):
    if x < 0 or y < 0:
        return LIE_OB
    cx = x >> CELL_SHIFT
    cy = y >> CELL_SHIFT
    if cx >= h.w or cy >= h.h:
        return LIE_OB
    return h.lies[cy * h.w + cx]


def _lie_pct(lie):
    if lie == LIE_ROUGH:
        return 85
    if lie == LIE_BUNKER:
        return 70
    if lie == LIE_TREES:
        return 50
    return 100


def _push(trace, kind, x, y, lie, strokes):
    trace.append(kind)
    trace.append(x)
    trace.append(y)
    trace.append(lie)
    trace.append(strokes)


def simulate_hole(h, skill, wind_x, wind_y, rng, want_trace):
    px = h.tee_x
    py = h.tee_y
    lie = LIE_TEE
    strokes = 0
    holed = 0
    time_s = HOLE_TRANSIT_SECONDS
    trace = []
    while True:
        if strokes >= MAX_STROKES:
            if want_trace:
                _push(trace, KIND_PICKUP, px, py, lie, strokes)
            break
        dx = h.pin_x - px
        dy = h.pin_y - py
        d = hypot(dx, dy)
        if lie == LIE_GREEN:
            strokes += 1
            time_s += PUTT_SECONDS
            dm = trunc_int(d)
            if dm == 0:
                pct = 99
            else:
                pct = min(max(90 + skill // 10 - dm * 9, 3), 99)
            roll = rng.bounded(100)
            if roll < pct:
                holed = 1
                px = h.pin_x
                py = h.pin_y
                if want_trace:
                    _push(trace, KIND_PUTT_HOLE, px, py, lie, strokes)
                break
            f = rng.range_incl(6000, 24000)
            nd = max(mul(d, f), 19661)
            ang = rng.next_u32() & 0xFFFF
            px = h.pin_x + mul(nd, cos_brad(ang))
            py = h.pin_y + mul(nd, sin_brad(ang))
            if want_trace:
                _push(trace, KIND_PUTT_MISS, px, py, lie, strokes)
            continue
        strokes += 1
        time_s += SHOT_SECONDS
        max_d = 150 * 65536 + skill * 85196
        max_eff = max_d * _lie_pct(lie) // 100
        t = min(d, max_eff)
        base = atan2_brad(dy, dx)
        cb = cos_brad(base)
        sb = sin_brad(base)
        tries = 0
        while tries < 3:
            al = lie_at(h, px + mul(t, cb), py + mul(t, sb))
            if al != LIE_WATER and al != LIE_OB:
                break
            t = max(t - 25 * 65536, 20 * 65536)
            tries += 1
        g1 = rng.gauss_q16()
        sd = 900 - 7 * skill
        ang_err = trunc_int(mul(g1, sd * 65536))
        angle = (base + ang_err) & 0xFFFF
        g2 = rng.gauss_q16()
        derr = 8192 - 50 * skill
        dist = t + mul(mul(t, derr), g2)
        dist = max(dist, 65536)
        wf = mul(dist, WIND_K)
        nx = px + mul(dist, cos_brad(angle)) + mul(wind_x, wf)
        ny = py + mul(dist, sin_brad(angle)) + mul(wind_y, wf)
        nl = lie_at(h, nx, ny)
        if nl == LIE_WATER or nl == LIE_OB:
            strokes += 1
            time_s += PENALTY_SECONDS
            if want_trace:
                _push(trace, KIND_PENALTY, nx, ny, nl, strokes)
        else:
            px = nx
            py = ny
            lie = nl
            if want_trace:
                _push(trace, KIND_FULL, px, py, lie, strokes)
    return {"strokes": strokes, "holed": holed, "time": time_s, "trace": trace}


def golfer_skill(g):
    return 10 + (g * 37) % 90


def wind_x_for_hole(h):
    return ((h * 5 + 3) % 11 - 5) * 65536


def wind_y_for_hole(h):
    return ((h * 7 + 1) % 9 - 4) * 65536


def trace_hash(trace):
    f = Fnv64()
    for v in trace:
        f.add_i64(v)
    return f.hex()


def run_sim_hash(course_seed, base_seed, n_golfers, n_holes, want_hash):
    holes = [make_hole(course_seed, i) for i in range(n_holes)]
    f = Fnv64()
    total_strokes = 0
    max_time = 0
    for g in range(n_golfers):
        skill = golfer_skill(g)
        gtime = 0
        for hi in range(n_holes):
            rng = Pcg32(base_seed + g, g * 256 + hi)
            r = simulate_hole(holes[hi], skill, wind_x_for_hole(hi), wind_y_for_hole(hi), rng, want_hash)
            total_strokes += r["strokes"]
            gtime += r["time"]
            if want_hash:
                f.add_i64(g)
                f.add_i64(hi)
                f.add_i64(r["strokes"])
                f.add_i64(r["holed"])
                f.add_i64(r["time"])
                f.add_i64(len(r["trace"]))
                for v in r["trace"]:
                    f.add_i64(v)
        if gtime > max_time:
            max_time = gtime
    return {"hash": f.hex() if want_hash else "", "total_strokes": total_strokes, "max_time": max_time}
