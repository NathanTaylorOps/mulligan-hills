class_name MHStaffGrounds
extends RefCounted
## Grounds condition and pest pressure per parcel (16 parcels, 4x4 grid), the daily update shared by delegated staff and the
## player's own work, and the deterministic animal incidents. One state, two sources of work: staff points arrive in on_day,
## the player's points arrive at once through personal_mow / personal_patrol. Pure integers, no engine RNG: incident rolls are
## MHRMath.h32d(secret, day, parcel, 0x57), so replaying a day gives the same result. Mirror of the grounds part of
## tools/reference/staff/mh_staff.py. Spec: docs/spec/staff.md. NOT YET RUN.
##
## condition 0..1000 per parcel (1000 = immaculate). pest 0..1000 per parcel (0 = none). Unowned parcels are never updated.

const INCIDENT_SALT: int = 0x57

var condition: Array = []
var pest: Array = []
## Personal points already used today (reset by on_day), so one parcel cannot be farmed without limit.
var personal_work: Array = []
var personal_pest: Array = []
var last_day: int = -1
var incidents_hit: int = 0
var incidents_handled: int = 0
var sightings: int = 0


func _init() -> void:
	reset(null)


## Fresh state with the start values from params. A null defs (only the constructor passes it) leaves zeros; MHStaff
## always calls reset(defs) right after construction.
func reset(defs: MHStaffDefs) -> void:
	condition = []
	pest = []
	personal_work = []
	personal_pest = []
	var c0: int = 0
	var p0: int = 0
	if defs != null:
		c0 = defs.param("cond_start")
		p0 = defs.param("pest_start")
	for _i: int in range(MHStaffDefs.NPARCELS):
		condition.append(c0)
		pest.append(p0)
		personal_work.append(0)
		personal_pest.append(0)
	last_day = -1
	incidents_hit = 0
	incidents_handled = 0
	sightings = 0


## Parcel id (row-major on cols x rows) of terrain cell (cx, cy) on a cells_x x cells_y patch, -1 outside the patch.
static func parcel_of_cell(cx: int, cy: int, cells_x: int, cells_y: int, cols: int, rows: int) -> int:
	if cells_x <= 0 or cells_y <= 0 or cx < 0 or cy < 0 or cx >= cells_x or cy >= cells_y:
		return -1
	return MHStaffMath.idiv(cy * rows, cells_y) * cols + MHStaffMath.idiv(cx * cols, cells_x)


## The player mows `cells` cells of a parcel (cells_per_parcel = cells in one parcel of the real patch; a full pass is
## cells == cells_per_parcel). Condition rises at once by personal_pass_gain per full pass, at most personal_daily_cap per
## parcel per day and never above 1000. Returns the points applied (0 when unowned or capped).
func personal_mow(defs: MHStaffDefs, parcel: int, cells: int, cells_per_parcel: int, view: Dictionary) -> int:
	if parcel < 0 or parcel >= MHStaffDefs.NPARCELS or not MHStaffView.is_owned(view, parcel):
		return 0
	if cells <= 0 or cells_per_parcel <= 0:
		return 0
	var gain: int = MHStaffMath.idiv(cells * defs.param("personal_pass_gain"), cells_per_parcel)
	gain = mini(gain, defs.param("personal_daily_cap") - int(personal_work[parcel]))
	gain = mini(gain, 1000 - int(condition[parcel]))
	if gain <= 0:
		return 0
	personal_work[parcel] = int(personal_work[parcel]) + gain
	condition[parcel] = int(condition[parcel]) + gain
	return gain


## The player patrols (pest control) the same way: pest falls at once by personal_patrol_gain per full pass, at most
## personal_patrol_cap per parcel per day, never below 0. Returns the points applied.
func personal_patrol(defs: MHStaffDefs, parcel: int, cells: int, cells_per_parcel: int, view: Dictionary) -> int:
	if parcel < 0 or parcel >= MHStaffDefs.NPARCELS or not MHStaffView.is_owned(view, parcel):
		return 0
	if cells <= 0 or cells_per_parcel <= 0:
		return 0
	var gain: int = MHStaffMath.idiv(cells * defs.param("personal_patrol_gain"), cells_per_parcel)
	gain = mini(gain, defs.param("personal_patrol_cap") - int(personal_pest[parcel]))
	gain = mini(gain, int(pest[parcel]))
	if gain <= 0:
		return 0
	personal_pest[parcel] = int(personal_pest[parcel]) + gain
	pest[parcel] = int(pest[parcel]) - gain
	return gain


## One game day (call once per MHGameClock.EV_DAY, after the day's hourly accounting). Order per owned parcel, ascending id:
## pest growth/decline, ranger control, decay vs grounds work, pest damage, incident roll. Returns {"ran": bool,
## "incidents": Array of {parcel, kind, positive, handled}}. Idempotent per day: day <= last_day does nothing.
## The caller ages the roster (MHStaffRoster.age_one_day) when ran is true; MHStaff.on_day does both.
func on_day(defs: MHStaffDefs, roster: MHStaffRoster, day: int, view: Dictionary, secret: int) -> Dictionary:
	if day <= last_day:
		return {"ran": false, "incidents": []}
	var wc: Dictionary = roster.work_by_parcel(defs, view)
	var work: Array = wc["work"]
	var ctrl: Array = wc["ctrl"]
	var out: Array = []
	var hit: int = 0
	var cap: int = defs.param("pest_natural_cap")
	for parcel: int in range(MHStaffDefs.NPARCELS):
		if not MHStaffView.is_owned(view, parcel):
			continue
		var cond: int = int(condition[parcel])
		var pst: int = int(pest[parcel])
		var growth: int = defs.param("pest_growth_base") + MHStaffMath.idiv(1000 - cond, defs.param("pest_growth_cond_div"))
		if pst < cap:
			pst = mini(cap, pst + growth)
		elif pst > cap:
			pst = maxi(cap, pst - defs.param("pest_decline_above_cap"))
		pst = maxi(0, pst - int(ctrl[parcel]))
		var decay: int = defs.decay(MHStaffView.kind_of(view, parcel))
		var w: int = int(work[parcel])
		if w >= decay:
			cond = mini(1000, cond + w - decay)
		else:
			cond = maxi(mini(cond, defs.param("cond_untended_floor")), cond - (decay - w))
		var dmg: int = MHStaffMath.idiv(pst, defs.param("pest_damage_div"))
		cond = maxi(mini(cond, defs.param("cond_hard_floor")), cond - dmg)
		var h: int = MHRMath.h32d(secret, day, parcel, INCIDENT_SALT)
		var roll: int = h % 1000
		var kidx: int = h >> 10
		var chance_neg: int = MHStaffMath.idiv(pst * pst, defs.param("incident_chance_div"))
		if roll < chance_neg and hit < defs.param("incident_max_per_day"):
			var ik: Dictionary = defs.incident_kind_at(kidx % defs.incident_kind_count())
			var handled: bool = int(ctrl[parcel]) >= defs.param("handled_min_control")
			var dm: int = int(ik["cond_damage"])
			var pa: int = int(ik["pest_add"])
			if handled:
				dm = MHStaffMath.idiv(dm * defs.param("handled_damage_pct"), 100)
				pa = MHStaffMath.idiv(pa * defs.param("handled_damage_pct"), 100)
			cond = maxi(mini(cond, defs.param("cond_hard_floor")), cond - dm)
			pst = mini(1000, pst + pa)
			hit += 1
			incidents_hit += 1
			if handled:
				incidents_handled += 1
			out.append({"parcel": parcel, "kind": str(ik["id"]), "positive": false, "handled": handled})
		elif pst <= defs.param("sighting_max_pest") and cond >= defs.param("sighting_min_cond"):
			var chance: int = defs.param("sighting_chance_permille")
			if int(ctrl[parcel]) > 0:
				chance += defs.param("sighting_ranger_bonus_permille")
			if roll >= 1000 - chance:
				sightings += 1
				out.append({"parcel": parcel, "kind": defs.sighting_id_at(kidx % defs.sighting_kind_count()), "positive": true, "handled": false})
		condition[parcel] = cond
		pest[parcel] = pst
	for i: int in range(MHStaffDefs.NPARCELS):
		personal_work[i] = 0
		personal_pest[i] = 0
	last_day = day
	return {"ran": true, "incidents": out}


## Mean condition over the owned golf parcels (cond_start when none is owned).
func avg_cond(defs: MHStaffDefs, view: Dictionary) -> int:
	var total: int = 0
	var n: int = 0
	for parcel: int in range(MHStaffDefs.NPARCELS):
		if MHStaffView.kind_of(view, parcel) == "golf" and MHStaffView.is_owned(view, parcel):
			total += int(condition[parcel])
			n += 1
	if n == 0:
		return defs.param("cond_start")
	return MHStaffMath.idiv(total, n)


## Mean pest pressure over the owned golf and facility parcels (0 when none is owned).
func avg_pest(view: Dictionary) -> int:
	var total: int = 0
	var n: int = 0
	for parcel: int in range(MHStaffDefs.NPARCELS):
		if MHStaffView.kind_of(view, parcel) != "homes" and MHStaffView.is_owned(view, parcel):
			total += int(pest[parcel])
			n += 1
	if n == 0:
		return 0
	return MHStaffMath.idiv(total, n)
