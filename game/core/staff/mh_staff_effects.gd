class_name MHStaffEffects
extends RefCounted
## What staff and course condition do to the rest of the game, as pure functions. Nothing here changes the official
## rating (MHSIM-1.0.0 stays calm-only geometry), the building gates or the economy; the caller reads these numbers:
##   demand_permille   -> multiply into the economy's demand modifier (see docs/spec/staff.md section 11)
##   pace_points       -> additive part of the tournament pace score (the base pace source is not defined yet)
##   condition_penalty_permille -> field satisfaction penalty for tournaments
##   overlay           -> UI-only "condition adjusted" beauty and fairness preview, never an official score or a gate
## Mirror of the effects part of tools/reference/staff/mh_staff.py. NOT YET RUN.


## Average service coverage 0..1000 over the station roles whose building stands (0 when none stands). A role is fully
## covered (1000) when its staff's work_permille adds up to service_rec_by_tier of its building tier.
static func service_avg(defs: MHStaffDefs, roster: MHStaffRoster, view: Dictionary) -> int:
	var total: int = 0
	var n: int = 0
	for rid: Variant in defs.role_ids():
		var role_id: String = str(rid)
		if defs.role_kind(role_id) != MHStaffDefs.KIND_STATION or defs.role_building(role_id) == "maintenance":
			continue
		var t: int = MHStaffView.tier_of(view, defs.role_building(role_id))
		if t <= 0:
			continue
		var need: int = defs.service_rec(t)
		total += mini(1000, MHStaffMath.idiv(roster.role_work_sum(defs, role_id), need))
		n += 1
	if n == 0:
		return 0
	return MHStaffMath.idiv(total, n)


static func has_station(defs: MHStaffDefs, view: Dictionary) -> bool:
	for rid: Variant in defs.role_ids():
		var role_id: String = str(rid)
		if defs.role_kind(role_id) == MHStaffDefs.KIND_STATION and defs.role_building(role_id) != "maintenance" and MHStaffView.tier_of(view, defs.role_building(role_id)) > 0:
			return true
	return false


## Arrival modifier in permille of normal (1000 = no effect), clamped to demand_min..demand_max. Sum of a condition term
## (golf parcels), a pest term and a service term (only when at least one station building stands).
static func demand_permille(defs: MHStaffDefs, roster: MHStaffRoster, grounds: MHStaffGrounds, view: Dictionary) -> int:
	var cond_t: int = MHStaffMath.fdiv((grounds.avg_cond(defs, view) - defs.param("cond_neutral")) * defs.param("cond_k_permille"), 1000)
	var pest_t: int = -MHStaffMath.idiv(grounds.avg_pest(view) * defs.param("pest_k_permille"), 1000)
	var serv_t: int = 0
	if has_station(defs, view):
		serv_t = MHStaffMath.fdiv((service_avg(defs, roster, view) - defs.param("service_neutral")) * defs.param("service_k_permille"), 1000)
	return clampi(1000 + cond_t + pest_t + serv_t, defs.param("demand_min"), defs.param("demand_max"))


## Pace score points (0..100 scale of tournaments.json min_pace_score) that marshals and caddies add.
static func pace_points(defs: MHStaffDefs, roster: MHStaffRoster) -> int:
	var total: int = 0
	for rid: Variant in defs.role_ids():
		var role_id: String = str(rid)
		var pmax: int = defs.role_int(role_id, "pace_max")
		if pmax > 0:
			total += mini(pmax, MHStaffMath.idiv(roster.role_work_sum(defs, role_id) * defs.role_int(role_id, "pace_each"), 1000))
	return total


## Field satisfaction penalty (permille, 0..sat_pen_max) when the average golf condition is under sat_cond_floor.
static func condition_penalty_permille(defs: MHStaffDefs, grounds: MHStaffGrounds, view: Dictionary) -> int:
	var a: int = grounds.avg_cond(defs, view)
	var floor_c: int = defs.param("sat_cond_floor")
	if a >= floor_c:
		return 0
	return mini(defs.param("sat_pen_max"), MHStaffMath.idiv((floor_c - a) * defs.param("sat_pen_max"), defs.param("sat_pen_span")))


## UI-only preview of how condition and pests would move the Beauty and Fairness axes (permille of the 0..1000 axis scale).
## It is NOT fed to MHRatingEngine and never to a gate.
static func overlay(defs: MHStaffDefs, grounds: MHStaffGrounds, view: Dictionary) -> Dictionary:
	return {
		"beauty_delta_pm": MHStaffMath.fdiv((grounds.avg_cond(defs, view) - defs.param("cond_neutral")) * defs.param("overlay_beauty_k"), 1000),
		"fairness_delta_pm": -MHStaffMath.idiv(grounds.avg_pest(view) * defs.param("overlay_fairness_k"), 1000),
	}
