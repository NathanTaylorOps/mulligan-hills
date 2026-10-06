"""Integer-only Python reference for game/core/staff/ (MHStaffDefs, MHStaffRoster, MHStaffGrounds, MHStaffEffects, MHStaff).

Money is integer CENTS. No floats. Every `//` below has non-negative operands, or goes through fdiv() (floor), which is what
the GDScript mirror does (GDScript int `/` truncates toward zero). The GDScript is a 1:1 mirror; golden vectors from
gen_golden.py pin both. Spec: docs/spec/staff.md. Data: docs/spec/data/staff.json.

The "view" is a dict: {"tiers": {building_id: tier 0..5}, "owned": [parcel ids], "kinds": [16 strings: golf|facility|homes]}.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DATA_PATH = os.path.join(ROOT, "docs", "spec", "data", "staff.json")
sys.path.insert(0, os.path.join(ROOT, "tools", "reference", "rating"))
from rating_core import H32  # noqa: E402  (the same H32 as MHRMath.h32d)

HOURS_PER_DAY = 11
NPARCELS = 16
SAVE_V = 1
INCIDENT_SALT = 0x57

K_GROUNDS = "grounds"
K_PEST = "pest"
K_STATION = "station"
STAT_KEYS = ("hires", "fires", "wages_cents", "incidents_hit", "incidents_handled", "sightings")


def clamp(v, lo, hi):
    return lo if v < lo else hi if v > hi else v


def fdiv(a, b):
    return a // b


def split_hour(daily, hour_index):
    """Same rule as MHEconomyModel.split_hour: the 11 parts sum to daily."""
    if daily <= 0:
        return 0
    h = clamp(hour_index, 0, HOURS_PER_DAY - 1)
    return (daily * (h + 1)) // HOURS_PER_DAY - (daily * h) // HOURS_PER_DAY


def load_data(path=None):
    with open(path or DATA_PATH, encoding="utf-8") as f:
        return json.load(f)


class Defs:
    def __init__(self, D=None):
        self.D = D or load_data()
        self.p = self.D["params"]
        self.roles = {r["id"]: r for r in self.D["roles"]}
        self.role_ids = [r["id"] for r in self.D["roles"]]
        self.grades = self.D["grades"]

    def cap(self, role_id, building_tier):
        if building_tier <= 0:
            return 0
        return self.roles[role_id]["caps_by_tier"][clamp(building_tier, 1, 5) - 1]

    def grade_of(self, tenure):
        g = 0
        for i, gr in enumerate(self.grades):
            if tenure >= gr["min_tenure_days"]:
                g = i
        return g

    def wage(self, role_id, tenure):
        r = self.roles[role_id]
        return (r["daily_wage_cents"] * self.grades[self.grade_of(tenure)]["wage_permille"]) // 1000

    def work_permille(self, tenure):
        return self.grades[self.grade_of(tenure)]["work_permille"]

    def hire_cost(self, role_id):
        return self.roles[role_id]["daily_wage_cents"] * self.p["hire_cost_days"]


def parcel_of_cell(cx, cy, cells_x, cells_y, cols, rows):
    """Parcel id (row-major) of a terrain cell. -1 outside the patch."""
    if cx < 0 or cy < 0 or cx >= cells_x or cy >= cells_y:
        return -1
    return ((cy * rows) // cells_y) * cols + (cx * cols) // cells_x


def is_owned(view, parcel):
    return parcel in view["owned"]


def tier_of(view, building):
    return view["tiers"].get(building, 0)


class Staff:
    def __init__(self, defs=None):
        self.d = defs or Defs()
        p = self.d.p
        self.employees = []          # dicts: serial, role, hired_day, tenure, areas
        self.next_serial = 1
        self.cond = [p["cond_start"]] * NPARCELS
        self.pest = [p["pest_start"]] * NPARCELS
        self.pw = [0] * NPARCELS      # personal mowing points used today
        self.pp = [0] * NPARCELS      # personal patrol points used today
        self.last_day = -1
        self.stats = {k: 0 for k in STAT_KEYS}

    # ---------------------------------------------------------- roster
    def count_role(self, role_id):
        return sum(1 for e in self.employees if e["role"] == role_id)

    def payroll(self):
        return sum(self.d.wage(e["role"], e["tenure"]) for e in self.employees)

    def hour_wage(self, hour_index):
        return split_hour(self.payroll(), hour_index)

    def pay_hour(self, hour_index):
        """Wage due this game hour, also added to stats.wages_cents. The caller takes it from the economy."""
        w = self.hour_wage(hour_index)
        self.stats["wages_cents"] += w
        return w

    def check_hire(self, role_id, view, cash_cents):
        d = self.d
        if role_id not in d.roles:
            return "bad_role"
        if len(self.employees) >= d.p["max_employees"]:
            return "roster_full"
        r = d.roles[role_id]
        t = tier_of(view, r["building"])
        if t <= 0:
            return "no_building"
        if self.count_role(role_id) >= d.cap(role_id, t):
            return "role_cap"
        need = d.hire_cost(role_id) + d.p["hire_reserve_days"] * (self.payroll() + d.wage(role_id, 0))
        if cash_cents < need:
            return "cash"
        return ""

    def hire(self, role_id, day, view, cash_cents):
        why = self.check_hire(role_id, view, cash_cents)
        if why:
            return {"ok": False, "reason": why, "serial": 0, "cost": 0}
        s = self.next_serial
        self.next_serial += 1
        self.employees.append({"serial": s, "role": role_id, "hired_day": day, "tenure": 0, "areas": []})
        self.stats["hires"] += 1
        return {"ok": True, "reason": "", "serial": s, "cost": self.d.hire_cost(role_id)}

    def find(self, serial):
        for e in self.employees:
            if e["serial"] == serial:
                return e
        return None

    def fire(self, serial):
        for i, e in enumerate(self.employees):
            if e["serial"] == serial:
                del self.employees[i]
                self.stats["fires"] += 1
                return True
        return False

    def assign(self, serial, areas, view):
        e = self.find(serial)
        if e is None:
            return "no_employee"
        if self.d.roles[e["role"]]["kind"] == K_STATION:
            return "not_area_role"
        if len(areas) > self.d.p["max_areas_per_employee"]:
            return "too_many_areas"
        seen = []
        for a in areas:
            if a < 0 or a >= NPARCELS:
                return "bad_area"
            if a in seen:
                return "duplicate_area"
            if not is_owned(view, a):
                return "not_owned"
            seen.append(a)
        e["areas"] = sorted(seen)
        return ""

    def coverage_count(self, kind, parcel):
        n = 0
        for e in self.employees:
            if self.d.roles[e["role"]]["kind"] == kind and parcel in e["areas"]:
                n += 1
        return n

    def auto_assign(self, view):
        """Gives every area-role employee with no area up to auto_assign_span parcels, least covered first (golf, then
        facility, then homes; ties by lowest id). Employees are taken in serial order. Returns how many were assigned."""
        span = self.d.p["auto_assign_span"]
        order = []
        for k in ("golf", "facility", "homes"):
            for p in range(NPARCELS):
                if view["kinds"][p] == k and is_owned(view, p):
                    order.append(p)
        assigned = 0
        for e in sorted(self.employees, key=lambda x: x["serial"]):
            kind = self.d.roles[e["role"]]["kind"]
            if kind == K_STATION or len(e["areas"]) > 0:
                continue
            if len(order) == 0:
                break
            chosen = []
            for _ in range(min(span, len(order))):
                best = -1
                best_c = 1 << 30
                for p in order:
                    if p in chosen:
                        continue
                    c = self.coverage_count(kind, p)
                    if c < best_c:
                        best = p
                        best_c = c
                chosen.append(best)
            e["areas"] = sorted(chosen)
            assigned += 1
        return assigned

    def gate_count(self, view):
        n = 0
        for e in self.employees:
            if e["tenure"] >= self.d.p["tenure_gate_days"] and tier_of(view, self.d.roles[e["role"]]["building"]) >= 1:
                n += 1
        return n

    def legacy_counts(self):
        out = {"greenkeepers": 0, "marshals": 0, "pro_shop_staff": 0, "caterers": 0}
        for e in self.employees:
            out[self.d.roles[e["role"]]["legacy"]] += 1
        return out

    # ---------------------------------------------------------- grounds
    def _split_over_areas(self, e, total, view, acc):
        """Adds total points over the employee's owned areas (ascending id) into acc; remainder to the lowest ids."""
        areas = [a for a in e["areas"] if is_owned(view, a)]
        if len(areas) == 0 or total <= 0:
            return
        n = len(areas)
        share = total // n
        rem = total % n
        for i, a in enumerate(areas):
            acc[a] += share + (1 if i < rem else 0)

    def work_by_parcel(self, view):
        p = self.d.p
        work = [0] * NPARCELS
        ctrl = [0] * NPARCELS
        for e in self.employees:
            r = self.d.roles[e["role"]]
            wp = self.d.work_permille(e["tenure"])
            if r["kind"] == K_GROUNDS:
                self._split_over_areas(e, (p["keeper_work"] * wp) // 1000, view, work)
            elif r["kind"] == K_PEST:
                self._split_over_areas(e, (p["ranger_control"] * wp) // 1000, view, ctrl)
        return work, ctrl

    def personal_mow(self, parcel, cells, cells_per_parcel, view):
        p = self.d.p
        if parcel < 0 or parcel >= NPARCELS or not is_owned(view, parcel) or cells <= 0 or cells_per_parcel <= 0:
            return 0
        gain = (cells * p["personal_pass_gain"]) // cells_per_parcel
        gain = min(gain, p["personal_daily_cap"] - self.pw[parcel], 1000 - self.cond[parcel])
        if gain <= 0:
            return 0
        self.pw[parcel] += gain
        self.cond[parcel] += gain
        return gain

    def personal_patrol(self, parcel, cells, cells_per_parcel, view):
        p = self.d.p
        if parcel < 0 or parcel >= NPARCELS or not is_owned(view, parcel) or cells <= 0 or cells_per_parcel <= 0:
            return 0
        gain = (cells * p["personal_patrol_gain"]) // cells_per_parcel
        gain = min(gain, p["personal_patrol_cap"] - self.pp[parcel], self.pest[parcel])
        if gain <= 0:
            return 0
        self.pp[parcel] += gain
        self.pest[parcel] -= gain
        return gain

    def on_day(self, day, view, secret):
        """One game day of grounds simulation. Idempotent per day (returns ran False if day <= last_day)."""
        if day <= self.last_day:
            return {"ran": False, "incidents": []}
        p = self.d.p
        work, ctrl = self.work_by_parcel(view)
        incidents = []
        hit = 0
        for parcel in range(NPARCELS):
            if not is_owned(view, parcel):
                continue
            kind = view["kinds"][parcel]
            cond = self.cond[parcel]
            pest = self.pest[parcel]
            growth = p["pest_growth_base"] + (1000 - cond) // p["pest_growth_cond_div"]
            if pest < p["pest_natural_cap"]:
                pest = min(p["pest_natural_cap"], pest + growth)
            elif pest > p["pest_natural_cap"]:
                pest = max(p["pest_natural_cap"], pest - p["pest_decline_above_cap"])
            pest = max(0, pest - ctrl[parcel])
            decay = self.d.D["decay_by_parcel_kind"][kind]
            w = work[parcel]
            if w >= decay:
                cond = min(1000, cond + w - decay)
            else:
                cond = max(min(cond, p["cond_untended_floor"]), cond - (decay - w))
            dmg = pest // p["pest_damage_div"]
            cond = max(min(cond, p["cond_hard_floor"]), cond - dmg)
            h = H32(secret, day, parcel, INCIDENT_SALT)
            roll = h % 1000
            kidx = h >> 10
            chance_neg = (pest * pest) // p["incident_chance_div"]
            if roll < chance_neg and hit < p["incident_max_per_day"]:
                ik = self.d.D["incident_kinds"][kidx % len(self.d.D["incident_kinds"])]
                handled = ctrl[parcel] >= p["handled_min_control"]
                dm = ik["cond_damage"]
                pa = ik["pest_add"]
                if handled:
                    dm = (dm * p["handled_damage_pct"]) // 100
                    pa = (pa * p["handled_damage_pct"]) // 100
                cond = max(min(cond, p["cond_hard_floor"]), cond - dm)
                pest = min(1000, pest + pa)
                hit += 1
                self.stats["incidents_hit"] += 1
                if handled:
                    self.stats["incidents_handled"] += 1
                incidents.append({"parcel": parcel, "kind": ik["id"], "positive": False, "handled": handled})
            elif pest <= p["sighting_max_pest"] and cond >= p["sighting_min_cond"]:
                chance = p["sighting_chance_permille"] + (p["sighting_ranger_bonus_permille"] if ctrl[parcel] > 0 else 0)
                if roll >= 1000 - chance:
                    sk = self.d.D["sighting_kinds"][kidx % len(self.d.D["sighting_kinds"])]
                    self.stats["sightings"] += 1
                    incidents.append({"parcel": parcel, "kind": sk["id"], "positive": True, "handled": False})
            self.cond[parcel] = cond
            self.pest[parcel] = pest
        for e in self.employees:
            e["tenure"] += 1
        self.pw = [0] * NPARCELS
        self.pp = [0] * NPARCELS
        self.last_day = day
        return {"ran": True, "incidents": incidents}

    # ---------------------------------------------------------- effects
    def avg_cond(self, view):
        ids = [p for p in range(NPARCELS) if view["kinds"][p] == "golf" and is_owned(view, p)]
        if len(ids) == 0:
            return self.d.p["cond_start"]
        return sum(self.cond[p] for p in ids) // len(ids)

    def avg_pest(self, view):
        ids = [p for p in range(NPARCELS) if view["kinds"][p] != "homes" and is_owned(view, p)]
        if len(ids) == 0:
            return 0
        return sum(self.pest[p] for p in ids) // len(ids)

    def role_work_sum(self, role_id):
        return sum(self.d.work_permille(e["tenure"]) for e in self.employees if e["role"] == role_id)

    def has_station(self, view):
        for rid in self.d.role_ids:
            r = self.d.roles[rid]
            if r["kind"] == K_STATION and tier_of(view, r["building"]) > 0:
                return True
        return False

    def service_avg(self, view):
        """Average coverage 0..1000 over the station roles whose building stands. 0 when none stands."""
        rec = self.d.p["service_rec_by_tier"]
        tot = 0
        n = 0
        for rid in self.d.role_ids:
            r = self.d.roles[rid]
            if r["kind"] != K_STATION:
                continue
            t = tier_of(view, r["building"])
            if t <= 0:
                continue
            need = rec[clamp(t, 1, 5) - 1]
            tot += min(1000, self.role_work_sum(rid) // need)
            n += 1
        return tot // n if n > 0 else 0

    def demand_permille(self, view):
        p = self.d.p
        cond_t = fdiv((self.avg_cond(view) - p["cond_neutral"]) * p["cond_k_permille"], 1000)
        pest_t = -((self.avg_pest(view) * p["pest_k_permille"]) // 1000)
        serv_t = 0
        if self.has_station(view):
            serv_t = fdiv((self.service_avg(view) - p["service_neutral"]) * p["service_k_permille"], 1000)
        return clamp(1000 + cond_t + pest_t + serv_t, p["demand_min"], p["demand_max"])

    def pace_points(self):
        tot = 0
        for rid in self.d.role_ids:
            r = self.d.roles[rid]
            if r["pace_max"] > 0:
                tot += min(r["pace_max"], (self.role_work_sum(rid) * r["pace_each"]) // 1000)
        return tot

    def condition_penalty_permille(self, view):
        p = self.d.p
        a = self.avg_cond(view)
        if a >= p["sat_cond_floor"]:
            return 0
        return min(p["sat_pen_max"], ((p["sat_cond_floor"] - a) * p["sat_pen_max"]) // p["sat_pen_span"])

    def overlay(self, view):
        p = self.d.p
        return {
            "beauty_delta_pm": fdiv((self.avg_cond(view) - p["cond_neutral"]) * p["overlay_beauty_k"], 1000),
            "fairness_delta_pm": -((self.avg_pest(view) * p["overlay_fairness_k"]) // 1000),
        }

    # ---------------------------------------------------------- save
    def to_block(self):
        return {
            "v": SAVE_V,
            "next_serial": self.next_serial,
            "last_day": self.last_day,
            "employees": [{"serial": e["serial"], "role": e["role"], "hired_day": e["hired_day"], "tenure": e["tenure"], "areas": list(e["areas"])} for e in self.employees],
            "condition": list(self.cond),
            "pest": list(self.pest),
            "personal_work": list(self.pw),
            "personal_pest": list(self.pp),
            "stats": dict(self.stats),
        }

    def state_list(self):
        """Flat ints for golden comparison."""
        out = [self.next_serial, self.last_day, len(self.employees)]
        for e in self.employees:
            out += [e["serial"], self.d.role_ids.index(e["role"]), e["hired_day"], e["tenure"], len(e["areas"])] + list(e["areas"])
        out += self.cond + self.pest + self.pw + self.pp
        out += [self.stats[k] for k in STAT_KEYS]
        return out


def land_kinds():
    L = json.load(open(os.path.join(ROOT, "docs", "spec", "data", "buildings.json")))["land"]["parcels"]
    return [x["kind"] for x in L]


def make_view(tiers=None, owned=None, kinds=None):
    return {"tiers": dict(tiers or {}), "owned": list(owned if owned is not None else [5, 6, 8, 9, 10]), "kinds": kinds or land_kinds()}
