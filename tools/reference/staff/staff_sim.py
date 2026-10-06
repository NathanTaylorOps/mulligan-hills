"""Staff economy check. Drives the DEC-069 economy bot (tools/reference/economy/sim.py) with a staffing layer on top.

The economy core is unchanged. This file adds, per game day: the staff grounds update, a staffing POLICY (the bot's
behaviour, a model, float and random are not used), the demand modifier into Economy.ext_permille, and the hourly wage
through Economy.incur_loss, exactly the narrow interface the session uses (see docs/spec/staff.md section 11).

Policies:
  none         no staff and no gate (the economy sim as shipped: the staff gate is assumed met). Baseline.
  minimal      hires only what the next tournament level needs, cheapest roles first, then keeps them.
  grounds      gate staff plus grounds keepers for the owned parcels and rangers (cash >= 10 days of payroll after a hire).
  full         grounds plus one station worker per building at tier 2 and up (two at tiers 4 and 5), cash >= 15 days.
  personal     no grounds or pest staff: the player mows and patrols every owned parcel every day (free); hires only the
               tournament minimum.

Usage:  python3 staff_sim.py [runs_per_cell]      (about 2 minutes per 20 runs on one core)
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "reference", "economy"))
sys.path.insert(0, HERE)

import mh_economy as E  # noqa: E402
import sim  # noqa: E402
import mh_staff as S  # noqa: E402

GOLF_ORDER = [5, 6, 9, 10, 1, 2, 4, 7, 11, 13, 14, 0]
FAC_ORDER = [8, 12]
HOME_ORDER = [3, 15]
BIDS = sim.BIDS
SECRET = 0x5EED1234
CELLS_PER_PARCEL = 1024

_orig_eligible = sim.tournament_eligible
_DEFS = S.Defs()
_KINDS = S.land_kinds()


def view_of(e, gp, fp, hp):
    owned = GOLF_ORDER[:gp] + FAC_ORDER[:fp] + HOME_ORDER[:hp]
    tiers = {BIDS[i]: e.tiers[i] for i in range(len(BIDS))}
    return {"tiers": tiers, "owned": owned, "kinds": _KINDS}


class StaffEco(E.Economy):
    """Economy with the staff layer. `run` is the sim.Run that owns the parcel counts."""

    def attach(self, run, policy):
        self.run_ref = run
        self.policy = policy
        self.staff = S.Staff(_DEFS)
        self.wages_total = 0
        self.dem_sum = 0
        self.dem_n = 0
        self.cond_sum = 0

    def view(self):
        r = self.run_ref
        return view_of(self, r.gp, r.fp, r.hp)

    # -- policy -------------------------------------------------------------------------------------------------
    def next_tournament_need(self):
        """min_staff of the lowest level not yet hosted whose non-staff gates hold, else 0."""
        r = self.run_ref
        for lvl in ("local", "regional", "national", "major"):
            if sim.LEVEL_RANK[lvl] <= r.tourn_rank:
                continue
            if _orig_eligible(lvl, self):
                return sim.TLEVELS[lvl]["entry"]["min_staff"]
            break
        return 0

    def hire_until(self, count, view, roles):
        st = self.staff
        guard = 0
        while len(st.employees) < count and guard < 60:
            guard += 1
            done = False
            for rid in roles:
                res = st.hire(rid, self.day, view, self.cash)
                if res["ok"]:
                    self.spend(res["cost"])
                    done = True
                    break
            if not done:
                break

    def grounds_target(self, view):
        golf = [p for p in view["owned"] if _KINDS[p] == "golf"]
        fac = [p for p in view["owned"] if _KINDS[p] == "facility"]
        need = len(golf) * 60 + len(fac) * 30 + 20 * len([p for p in view["owned"] if _KINDS[p] == "homes"])
        return -(-need // 240)

    def run_policy(self, view):
        st = self.staff
        pol = self.policy
        cheap_roles = ["marshal", "caddie", "server", "pro_shop_assistant", "range_attendant", "housekeeper", "groundskeeper", "wildlife_ranger"]
        if pol in ("minimal", "personal", "grounds", "full"):
            need = self.next_tournament_need()
            if need > len(st.employees):
                self.hire_until(need, view, cheap_roles)
        if pol in ("grounds", "full"):
            # grounds first, then rangers, then (full only) station workers at tier 2 and up, one per building (two at 4+)
            for _ in range(60):
                payroll = st.payroll()
                if self.cash < (15 if pol == "full" else 10) * payroll + 60000:
                    break
                want = None
                if view["tiers"]["maintenance"] > 0 and st.count_role("groundskeeper") < min(self.grounds_target(view), _DEFS.cap("groundskeeper", view["tiers"]["maintenance"])):
                    want = "groundskeeper"
                elif view["tiers"]["maintenance"] >= 2 and st.count_role("wildlife_ranger") < min(1 + len(view["owned"]) // 6, _DEFS.cap("wildlife_ranger", view["tiers"]["maintenance"])):
                    want = "wildlife_ranger"
                elif pol == "full":
                    for rid in _DEFS.role_ids:
                        r = _DEFS.roles[rid]
                        if r["kind"] != "station":
                            continue
                        t = view["tiers"][r["building"]]
                        if t >= 2 and st.count_role(rid) < _DEFS.cap(rid, t):
                            want = rid
                            break
                if want is None:
                    break
                res = st.hire(want, self.day, view, self.cash)
                if not res["ok"]:
                    break
                self.spend(res["cost"])
        if pol in ("minimal", "grounds", "full", "personal"):
            st.auto_assign(view)
        if pol == "personal":
            for p in view["owned"]:
                st.personal_mow(p, CELLS_PER_PARCEL, CELLS_PER_PARCEL, view)
                st.personal_patrol(p, CELLS_PER_PARCEL, CELLS_PER_PARCEL, view)

    def day_start(self):
        if self.policy == "none":
            return
        view = self.view()
        if self.day >= 1:
            self.staff.on_day(self.day, view, SECRET)
        self.run_policy(view)
        d = self.staff.demand_permille(view)
        self.ext_permille = d
        self.dem_sum += d
        self.dem_n += 1
        self.cond_sum += self.staff.avg_cond(view)

    def tick_hour(self):
        h = self.hour
        if h == 0:
            self.day_start()
        r = E.Economy.tick_hour(self)
        if self.policy != "none":
            w = self.staff.pay_hour(h)
            self.wages_total += w
            self.incur_loss(w)
        return r


class StaffRun(sim.Run):
    def __init__(self, P, seed, arch, skill_name, days, policy, **kw):
        super().__init__(P, seed, arch, skill_name, days, **kw)
        eco = StaffEco(P, sim.UPK, -1)
        eco.attach(self, policy)
        self.eco = eco
        self.policy = policy


def patched_eligible(level, e):
    if not _orig_eligible(level, e):
        return False
    if getattr(e, "policy", "none") == "none":
        return True
    return e.staff.gate_count(e.view()) >= sim.TLEVELS[level]["entry"]["min_staff"]


sim.tournament_eligible = patched_eligible


def run_cell(P, skill, policy, n, days=260, seed0=1000, arch="casual"):
    out = []
    for i in range(n):
        r = StaffRun(P, seed0 + i, arch, skill, days, policy)
        res = r.run()
        e = r.eco
        res["wages"] = getattr(e, "wages_total", 0)
        res["dem_avg"] = e.dem_sum // e.dem_n if getattr(e, "dem_n", 0) else 1000
        res["cond_avg"] = e.cond_sum // e.dem_n if getattr(e, "dem_n", 0) else 0
        res["staff_n"] = len(e.staff.employees) if hasattr(e, "staff") else 0
        res["payroll"] = e.staff.payroll() if hasattr(e, "staff") else 0
        res["bankrupt"] = res["bankrupt_events"]
        out.append(res)
    return out


def window_report(P, n):
    """Share of the non-novice, habit-weighted population that finishes (all T5 + 18 holes) in days 100 to 150."""
    print("\n-- pacing window (DEC-069/071): non-novice population, skill weights casual 45 / competent 30 / expert 10, habit weights as sim.py, %d runs per cell" % n)
    for policy in ("none", "minimal", "personal", "grounds", "full"):
        inw = 0.0
        by150 = 0.0
        tot = 0.0
        days_all = []
        for skill in ("casual", "competent", "expert"):
            for arch in ("casual", "careful", "sticky", "greedy", "cheap"):
                wgt = sim.SKILL_W[skill] * sim.HABIT_W[arch]
                rs = run_cell(P, skill, policy, n, days=260, seed0=5000, arch=arch)
                for x in rs:
                    d = x["t5_full"]
                    tot += wgt / n
                    if d is not None and 100 <= d <= 150:
                        inw += wgt / n
                    if d is not None and d <= 150:
                        by150 += wgt / n
                    if d is not None:
                        days_all.append(d)
        print("%-9s in days 100-150: %5.1f%%  by day 150: %5.1f%%  pooled finish day p10/p50/p90 %s" % (policy, 100 * inw / tot, 100 * by150 / tot, sim.q3(days_all)))
        sys.stdout.flush()


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 12
    P = sim.load()
    print("staff economy check: %d runs per cell, casual fee habit, 260 days, casual and competent skill" % n)
    print("T5 = day all ten buildings reach tier 5 (with 18 holes). Baseline policy 'none' assumes the staff gate is met.")
    for skill in ("casual", "competent"):
        for policy in ("none", "minimal", "personal", "grounds", "full"):
            rs = run_cell(P, skill, policy, n)
            t5 = [x["t5_full"] for x in rs if x["t5_full"] is not None]
            snap = [x["snap"].get(100) for x in rs if x["snap"].get(100)]
            w = sorted(x["wages"] for x in rs)
            print("%-9s %-11s T5 day p10/p50/p90 %s (%d/%d) | staff at end med %s payroll/day med $%s | demand avg med %s | cond avg med %s | wages total med $%s | net/day d100 med %s | bankrupt %d" % (
                skill, policy, sim.q3(t5), len(t5), n,
                sorted(x["staff_n"] for x in rs)[n // 2], sorted(x["payroll"] for x in rs)[n // 2] // 100,
                sorted(x["dem_avg"] for x in rs)[n // 2], sorted(x["cond_avg"] for x in rs)[n // 2],
                w[n // 2] // 100,
                ("$%d" % (sorted(s["net"] for s in snap)[len(snap) // 2] // 100)) if snap else "-",
                sum(x["bankrupt"] for x in rs)))
            sys.stdout.flush()
    window_report(P, max(4, n // 2))


if __name__ == "__main__":
    main()
