"""MHRATE-1.0.0 reference, part 2: axes, hole score, course roll-up, advisor codes, tournament, ranking."""
from rating_core import *  # noqa: F401,F403
from rating_core import P, CY, clamp, rdiv, interp, isqrt, H32, hash64, i32le

CALM = {"wx": 0, "wy": 0, "rain": 0}
HOLE_GATES = {2: 6, 3: 10, 4: 14, 5: 18}
SCORE_GATES = {int(k): v for k, v in P["gates_avg_score_x10"].items()}

# code -> severity (3 BLOCK, 2 SEVERE, 1 WARN, 0 INFO)
B, S, W, I_ = 3, 2, 1, 0
CODES = {
    "RC001": B, "RC002": B, "RC003": B, "RC004": B, "RC005": B, "RC006": B, "RC007": B, "RC008": B,
    "RC009": W, "RC010": I_, "RC011": W, "RC012": I_, "RC013": W, "RC014": S, "RC015": S, "RC016": I_, "RC017": I_,
    "RC021": S, "RC022": W, "RC023": S, "RC024": W, "RC025": W, "RC026": W, "RC027": S, "RC028": S, "RC029": I_,
    "RC031": S, "RC032": W, "RC033": I_, "RC034": W, "RC035": S, "RC036": W, "RC037": W, "RC038": I_, "RC039": I_,
    "RC040": W, "RC041": W, "RC042": I_, "RC043": I_, "RC044": I_, "RC045": W, "RC046": S, "RC047": I_, "RC048": I_,
    "RC051": W, "RC052": I_, "RC053": I_, "RC054": W, "RC055": I_, "RC056": I_, "RC057": I_,
    "RC061": W, "RC062": I_, "RC063": W, "RC064": W, "RC065": S, "RC066": I_, "RC067": I_, "RC068": W,
    "RC071": I_, "RC072": I_, "RC073": B, "RC074": I_, "RC075": W, "RC076": W, "RC081": I_,
}
assert len(CODES) == 66


def top_codes(codes, limit=3):
    """Advisor ordering: highest severity first, then lowest code number; at most `limit`."""
    return sorted(set(codes), key=lambda c: (-CODES[c], c))[:limit]


def band_means(recs, nb=6):
    out = []
    for b in range(nb):
        xs = [r["strokes"] for r in recs if r["band"] == b]
        out.append(rdiv(sum(xs) * 100, len(xs)))
    return out


def corridor_runs(hole):
    best = 0
    gx = hole.gc[0] - hole.tee[0]
    gy = hole.gc[1] - hole.tee[1]
    L = max(1, hole.L)
    for pct in (25, 40, 55, 70):
        s = L * pct // 100
        runs = 0
        run = 0
        for lat in range(-60, 62, 2):
            pt = (hole.tee[0] + (gx * s - gy * lat) // L, hole.tee[1] + (gy * s + gx * lat) // L)
            lie = hole.lie_at(pt)
            blocked = lie in (LIE_WATER, LIE_OB, LIE_BUNKER, LIE_DEEP)
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


def beauty_parts(hole):
    gx = hole.gc[0] - hole.tee[0]
    gy = hole.gc[1] - hole.tee[1]
    Lc = isqrt(gx * gx + gy * gy)
    pol = 100
    n = 0
    ok = 0
    for yy in range(0, hole.L, 10):
        xx = hole.tee[0] + gx * yy * CY // max(1, hole.L * CY)
        n += 1
        if hole.lie_at((xx, hole.tee[1] + yy * CY)) in (LIE_FAIRWAY, LIE_GREEN, LIE_FRINGE):
            ok += 1
    if n and ok * 100 >= 60 * n:
        pol += 50
    cells = {}
    for (tx, ty) in hole.trees:
        rel = ((tx - hole.tee[0]) * gy - (ty - hole.tee[1]) * gx) // max(1, Lc)
        if abs(rel) <= 60 * CY and -1000 <= ty <= hole.L * CY + 3000:
            k = (tx // 300, ty // 300)
            cells[k] = cells.get(k, 0) + 1
    n_tree = min(60, len(cells))
    stacked = any(v > 1 for v in cells.values())
    tr = 120 * n_tree // (n_tree + 25)
    wa = 0
    for xi in range(-60, 61, 4):
        for yi in range(0, hole.L + 1, 4):
            if hole.in_type("water", (xi * CY + hole.tee[0], yi * CY + hole.tee[1])):
                wa += 16
    wat = 120 * wa // (wa + 800)
    has_bunker = len(hole.rects["bunker"]) + len(hole.circles["bunker"]) > 0
    cats = (1 if n_tree >= 3 else 0) + (1 if hole.counts["rock"] >= 1 else 0) + (1 if hole.counts["flower"] >= 3 else 0) \
        + (1 if wa >= 200 else 0) + (1 if has_bunker else 0)
    rel_ = min(100, hole.elev_mm() * 100 // 5486)
    braw = min(700, pol + tr + wat + 25 * cats + rel_)
    return dict(pol=pol, tr=tr, wat=wat, var=25 * cats, rel=rel_, n_tree=n_tree, wa=wa, cats=cats,
                stacked=stacked, braw=braw)


def invalid_result(hole, reasons, par=0, means=None):
    return dict(valid=False, score_pm=0, score=0, A=0, I=0, Len=0, B=0, F=0, par=par, L=hole.L if hole else 0,
                reasons=list(reasons), all_reasons=list(reasons), means=means or [0] * 6, forced_pm=0, pickup_pm=0,
                tree_pm=0, risk_pm=0, comps=1, raw_corr=0, pace_pm=0, dead=False, hash="", content_hash="",
                engine_version=ENGINE, sim_version=SIM, params_hash=PARAMS_HASH)


def rate_hole(hole, seed, cond=CALM, counts=None, epoch=0, want_recs=False):
    if not hole.valid:
        return invalid_result(hole, hole.reasons)
    recs = simulate(hole, seed, cond, counts)
    n = len(recs)
    par = hole.par
    nb = 6
    bm = band_means(recs, nb)
    n_a = sum(1 for r in recs if r["band"] == 0)
    if sum(1 for r in recs if r["band"] == 0 and r["flags"] & 4) == n_a:
        r = invalid_result(hole, ["RC007"], par, bm)
        r["hash"] = sim_hash(seed, recs)
        return r
    # Accuracy
    sk_sum = sum(r["skill"] for r in recs)
    st_sum = sum(r["strokes"] for r in recs)
    sxy = sum((r["skill"] * n - sk_sum) * (r["strokes"] * n - st_sum) for r in recs)
    sxx = sum((r["skill"] * n - sk_sum) ** 2 for r in recs)
    spread = max(0, rdiv(-sxy * 100 * 530, sxx)) if sxx else 0
    T = P["acc_target"][str(par)]
    A = 1000 * spread // T if spread <= T else max(400, 1000 - (spread - T) * 600 // T)
    inv = sum(1 for i in range(5) if bm[i + 1] < bm[i] - 15)
    A = clamp(A - min(300, 100 * inv), 0, 1000)
    # Fairness
    forced_pm = sum(1 for r in recs if r["flags"] & 1) * 1000 // n
    pickup_pm = sum(1 for r in recs if r["flags"] & 4) * 1000 // n
    tree_pm = sum(1 for r in recs if r["flags"] & 8) * 1000 // n
    risk_pm = sum(1 for r in recs if r["flags"] & 16) * 1000 // n
    over = max(0, bm[2] - (par * 100 + 180))
    F = clamp(1000 - min(700, 2 * forced_pm) - min(200, 2 * pickup_pm) - min(100, tree_pm) - min(250, 2 * over), 0, 1000)
    # Imagination
    raw_corr = corridor_runs(hole)
    comps = max(1, raw_corr)
    Oc = 0 if comps <= 1 else 800 if comps == 2 else 1000
    R = 0
    if Oc > 0:
        if risk_pm < 150:
            R = 300 + 700 * risk_pm // 150
        elif risk_pm <= 500:
            R = 1000
        elif risk_pm <= 750:
            R = 1000 - (risk_pm - 500) * 700 // 250
        else:
            R = max(0, 300 - (risk_pm - 750) * 300 // 250)
    bend = 0
    if par > 3:
        c_recs = [r for r in recs if r["band"] == 2]
        xs = sorted(r["first"][0] for r in c_recs)
        ys = sorted(r["first"][1] for r in c_recs)
        mx, my = xs[(len(xs) - 1) // 2], ys[(len(ys) - 1) // 2]
        ax_, ay_ = mx - hole.tee[0], my - hole.tee[1]
        bx_, by_ = hole.gc[0] - mx, hole.gc[1] - my
        la, lb = isqrt(ax_ * ax_ + ay_ * ay_), isqrt(bx_ * bx_ + by_ * by_)
        if la > 0 and lb > 0:
            bend = abs(ax_ * by_ - ay_ * bx_) * 1000 // (la * lb)
    bend_s = min(1000, max(0, bend - 60) * 1000 // 240)
    elev = min(1000, hole.elev_mm() * 1000 // 5486)
    shape = (600 * bend_s + 400 * elev) // 1000
    Ival = (450 * Oc + 350 * R + 200 * shape) // 1000
    Ival = Ival * min(1000, 2 * F) // 1000
    Ln = interp(P["length_table"], hole.L)
    PQ = (A + Ival + Ln + F) // 4
    bp = beauty_parts(hole)
    Bv = min(bp["braw"], PQ + 300)
    w = P["hole_weights"]
    base = (w["A"] * A + w["I"] * Ival + w["L"] * Ln + w["B"] * Bv) // 1000
    m = 400 + 600 * F // 1000
    c_times = [r["time_s"] for r in recs if r["band"] == 2]
    pace = sum(c_times) * 1000 // (len(c_times) * P["pace_std_s"][str(par)])
    pace_pen = clamp((pace - 1150) // 4, 0, 80)
    score = clamp(base * m // 1000 - pace_pen, 0, 1000)
    res = dict(valid=True, score_pm=score, score=rdiv(score, 10), A=A, I=Ival, Len=Ln, B=Bv, F=F, par=par, L=hole.L,
               means=bm, forced_pm=forced_pm, pickup_pm=pickup_pm, tree_pm=tree_pm, risk_pm=risk_pm,
               raw_corr=raw_corr, comps=comps, pace_pm=pace, pace_pen=pace_pen, spread=spread, T_par=T,
               inversions=inv, over=over, bend_s=bend_s, elev=elev, Oc=Oc, R=R, shape=shape, PQ=PQ,
               B_raw=bp["braw"], n_tree=bp["n_tree"], raw_trees=len(hole.trees), wat=bp["wat"], cats=bp["cats"],
               stacked=bp["stacked"], dead=score < 250, hash=sim_hash(seed, recs), content_hash=hole.content_hash(),
               hole_seed=seed, rating_epoch=epoch, engine_version=ENGINE, sim_version=SIM, params_hash=PARAMS_HASH,
               preview=counts is not None, golfers=n,
               # fixture aliases
               unch=forced_pm, pick=pickup_pm)
    res["all_reasons"] = hole_codes(res)
    res["reasons"] = top_codes(res["all_reasons"])
    if want_recs:
        res["recs"] = recs
    return res


def hole_codes(r):
    """Advisor codes that fire for a rated valid hole (spec 15)."""
    c = []
    L, par, bm2 = r["L"], r["par"], r["means"][2]
    if L < 120: c.append("RC011")
    if 120 <= L < 150: c.append("RC012")
    if 650 <= L <= 700: c.append("RC013")
    if 700 < L < 850: c.append("RC014")
    if L >= 850: c.append("RC015")
    if abs(L - 260) <= 8 or abs(L - 470) <= 8: c.append("RC016")
    if r["Len"] >= 950: c.append("RC017")
    f, p, t = r["forced_pm"], r["pickup_pm"], r["tree_pm"]
    if f >= 300: c.append("RC021")
    elif f >= 100: c.append("RC022")
    if p >= 100: c.append("RC023")
    elif p >= 30: c.append("RC024")
    if t >= 100: c.append("RC025")
    if r["over"] > 0: c.append("RC026")
    if bm2 > par * 100 + 250: c.append("RC027")
    if r["raw_corr"] == 0: c.append("RC028")
    if r["F"] >= 950 and r["I"] >= 400: c.append("RC029")
    s = r["score_pm"]
    if s < 250: c.append("RC031")
    elif s < 400: c.append("RC032")
    if s >= 650: c.append("RC033")
    pc = r["pace_pm"]
    if pc > 1150: c.append("RC034")
    if pc >= 1400: c.append("RC035")
    if r["spread"] * 100 < 40 * r["T_par"]: c.append("RC036")
    if r["spread"] > 2 * r["T_par"]: c.append("RC037")
    if r["inversions"] >= 1: c.append("RC038")
    if r["A"] >= 800: c.append("RC039")
    if r["A"] < 300: c.append("RC040")
    cm = r["comps"]
    if r["I"] < 100 and cm == 1: c.append("RC041")
    if cm == 2: c.append("RC042")
    if cm >= 3: c.append("RC043")
    if cm >= 2 and r["risk_pm"] < 150: c.append("RC044")
    if r["risk_pm"] > 500: c.append("RC045")
    if r["risk_pm"] > 750: c.append("RC046")
    if par >= 4 and r["bend_s"] == 0: c.append("RC047")
    if r["elev"] == 0: c.append("RC048")
    if r["B"] < 200: c.append("RC051")
    if r["n_tree"] >= 60: c.append("RC052")
    if r["raw_trees"] > 0 and r["raw_trees"] * 2 >= r["n_tree"] * 3: c.append("RC053")
    if r["B_raw"] > r["PQ"] + 300: c.append("RC054")
    if r["cats"] < 2: c.append("RC055")
    if r["wat"] >= 60 and r["raw_corr"] >= 1: c.append("RC056")
    if r["stacked"]: c.append("RC057")
    return c


# ------------------------------------------------------------------ course roll-up
def descriptor(hole):
    if not hole.valid:
        return None
    gx = hole.gc[0] - hole.tee[0]
    gy = hole.gc[1] - hole.tee[1]
    L = max(1, hole.L)
    cells = [0] * 72
    counts = [0] * 18
    for s in range(0, L, 4):
        for lat in range(-50, 51, 4):
            pt = (hole.tee[0] + (gx * s - gy * lat) // L, hole.tee[1] + (gy * s + gx * lat) // L)
            a = min(5, s * 6 // L)
            ab = abs(lat)
            c = a * 3 + (0 if ab <= 10 else 1 if ab <= 25 else 2)
            counts[c] += 1
            if hole.in_type("water", pt): cells[c * 4 + 0] += 1
            if hole.in_type("bunker", pt): cells[c * 4 + 1] += 1
            if hole.in_type("ob", pt): cells[c * 4 + 3] += 1
    for (tx, ty) in hole.trees:
        rx, ry = tx - hole.tee[0], ty - hole.tee[1]
        s_yd = (rx * gx + ry * gy) // (L * CY) // CY
        lat_yd = (rx * (-gy) + ry * gx) // (L * CY) // CY
        if 0 <= s_yd < L and abs(lat_yd) <= 50:
            a = min(5, s_yd * 6 // L)
            ab = abs(lat_yd)
            cells[(a * 3 + (0 if ab <= 10 else 1 if ab <= 25 else 2)) * 4 + 2] += 1
    out = []
    for c in range(18):
        tot = max(1, counts[c])
        for t in range(4):
            v = cells[c * 4 + t]
            out.append(min(1000, v * 1000 // 20 if t == 2 else v * 1000 // tot))
    return out


def similarity(h1, d1, h2, d2):
    if d1 is None or d2 is None:
        return 0
    Dc = sum(abs(a - b) for a, b in zip(d1, d2)) // 3
    dz = abs((h1.green_z - h1.tee_z) // 914 - (h2.green_z - h2.tee_z) // 914)
    return 1000 - min(1000, Dc + 3 * abs(h1.L - h2.L) + 5 * dz + 20 * abs(h1.par - h2.par))


def dup_factor(S_):
    return 1000 if S_ <= 700 else 1000 - 2 * (S_ - 700)


def rollup(holes, results):
    """holes: list of Hole; results: list of rate_hole dicts (only valid, score_pm, par, F, pace_pm used)."""
    n = len(holes)
    ds = [descriptor(h) for h in holes]
    adj, facs, sims = [], [], []
    for i in range(n):
        f = 1000
        best_s, best_j = 0, -1
        if results[i]["valid"]:
            for j in range(i):
                if results[j]["valid"]:
                    sv = similarity(holes[i], ds[i], holes[j], ds[j])
                    f = min(f, dup_factor(sv))
                    if sv > best_s:
                        best_s, best_j = sv, j
        facs.append(f)
        sims.append((best_s, best_j))
        adj.append(results[i]["score_pm"] * f // 1000)
    order = sorted(range(n), key=lambda i: (adj[i], i))
    k = -(-n // 3)
    Wv = sum(adj[i] for i in order[:k]) // k
    M = sum(adj) // n
    base = (70 * M + 30 * Wv) // 100
    pars = sorted(set(r["par"] for r in results if r["valid"]))
    few_pars = n >= 6 and len(pars) < 2
    if few_pars:
        base = base * 920 // 1000
    x10 = clamp(base, 0, 1000)
    good = sum(1 for r in results if r["valid"] and r["score_pm"] >= 250)
    out = dict(course_x10=x10, mean=M, low_third=Wv, factors=facs, adj=adj, similar=sims,
               n_dup=sum(1 for f in facs if f <= 500), valid_non_dead=good, n=n,
               invalid=sum(1 for r in results if not r["valid"]))
    out["tier"] = tier_reached(good, x10)
    out["codes"] = course_codes(out, results, few_pars)
    return out


def tier_reached(good, x10):
    t = 1
    for tier in (2, 3, 4, 5):
        if good >= HOLE_GATES[tier] and x10 >= SCORE_GATES[tier]:
            t = tier
        else:
            break
    return t


def course_codes(ro, results, few_pars):
    c = []
    n = ro["n"]
    for i in range(n):
        sv = ro["similar"][i][0]
        if sv >= 850: c.append(("RC061", i))
        elif sv > 700: c.append(("RC062", i))
    glob = []
    if few_pars: glob.append("RC063")
    if ro["mean"] - ro["low_third"] >= 150: glob.append("RC064")
    if ro["invalid"] > 0: glob.append("RC065")
    nxt = ro["tier"] + 1
    if nxt <= 5:
        if ro["valid_non_dead"] < HOLE_GATES[nxt]: glob.append("RC066")
        if ro["course_x10"] < SCORE_GATES[nxt]: glob.append("RC067")
    vr = [r for r in results if r["valid"]]
    if vr and sum(r["pace_pm"] for r in vr) // len(vr) > 1150: glob.append("RC068")
    return dict(per_hole=c, course=glob)


def near_holes(origins, tees_greens):
    """RC009: hole indices whose tee or green is within 10 yd of another hole's tee or green.
    origins[i] = (ox, oy) yards; tees_greens[i] = ((tx,ty),(gx,gy)) hole-local yards."""
    pts = []
    for i, (o, tg) in enumerate(zip(origins, tees_greens)):
        pts.append([(o[0] + p[0], o[1] + p[1]) for p in tg])
    hit = []
    for i in range(len(pts)):
        close = False
        for j in range(len(pts)):
            if i == j: continue
            for a in pts[i]:
                for b in pts[j]:
                    if (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 <= 100:
                        close = True
        if close: hit.append(i)
    return hit


# ------------------------------------------------------------------ tournament and misc advisor
def sustained(checkpoints):
    last = ([0] * 8 + list(checkpoints))[-8:]
    s = sorted(last)
    return min((s[3] + s[4]) // 2, checkpoints[-1] if checkpoints else 0)


def facility_points(tiers):
    """tiers: Clubhouse, Restaurant, ProShop, CartBarn, Maintenance tiers."""
    return min(200, 10 * sum(min(4, t) for t in tiers))


def prestige(sustained_x10, pace_pm, fac_pts, unfair_holes, recent_events):
    course = 600 * sustained_x10 // 1000
    pace = 200 * clamp(2000 - pace_pm, 0, 1000) // 1000
    raw = course + pace + min(200, fac_pts) - 40 * unfair_holes
    return clamp(raw * (1000 - 100 * min(5, recent_events)) // 1000, 0, 1000)


def tournament_codes(ss, n_checkpoints, snapshot_changed, cooldown_active, unfair_holes, mean_pace_pm):
    c = []
    if ss < 520: c.append("RC071")
    if n_checkpoints < 8: c.append("RC072")
    if snapshot_changed: c.append("RC073")
    if cooldown_active: c.append("RC074")
    if unfair_holes >= 1: c.append("RC075")
    if mean_pace_pm > 1300: c.append("RC076")
    return c


def wind_codes(calm_mean_x100, wind_mean_x100):
    return ["RC081"] if wind_mean_x100 - calm_mean_x100 >= 40 else []


def stale_codes(stored_engine_version):
    return ["RC010"] if stored_engine_version != ENGINE else []


def rank(entries):
    return [e["sub_id"] for e in sorted(entries, key=lambda e: (-e["score_pm"], -e["F"], e["recv_ms"], e["sub_id"]))]
