class_name MHBuildMenuModel
extends RefCounted
## Pure model of the Build menu: 10 buildings x 5 tiers. Reads the game through MHGameStateView, uses
## MHUnlockRules for gates and MHBuildingDefs.price_for for the cost (price = target payback days x added
## daily income, DEC-050). Cash is NOT part of a gate; it only decides whether the buy button is enabled.

enum TierState { OWNED = 0, NEXT = 1, LOCKED = 2, DEMO_LOCKED = 3 }

const MAX_REASONS_SHOWN: int = 3


## Dictionary {key: strings key, params: Dictionary, have: int, need: int} for one unmet gate row
## [requirement_key, met, have, need]. Params use the `_key` convention understood by MHStrings
## (a value under "x_key" is translated and offered as "x").
static func reason_for_row(row: Array) -> Dictionary:
	var rk: String = str(row[0])
	var have: int = int(row[2])
	var need: int = int(row[3])
	var params: Dictionary = {"have": have, "need": need}
	var key: String = "build.req.unknown"
	if rk == "holes":
		key = "build.req.holes"
	elif rk == "avg_hole_score":
		key = "build.req.avg_score"
	elif rk == "parcels_owned":
		key = "build.req.parcels"
	elif rk == "members":
		key = "build.req.members"
	elif rk == "any_others":
		key = "build.req.any_others"
	elif rk == "demo_limit":
		key = "build.req.demo"
	elif rk == "previous_tier":
		key = "build.req.previous"
	elif rk == "hosted_tournament":
		key = "build.req.hosted"
		var idx: int = clampi(need - 1, 0, MHBuildingDefs.LEVELS.size() - 1)
		params["level_key"] = "tournament." + str(MHBuildingDefs.LEVELS[idx]) + ".name"
	elif rk.begins_with("building:"):
		key = "build.req.building"
		params["building_key"] = "building." + rk.substr(9) + ".name"
	elif rk.begins_with("parcel_kind:"):
		key = "build.req.parcel_kind"
		params["kind_key"] = "land.kind." + rk.substr(12)
	return {"key": key, "params": params, "have": have, "need": need}


## Reasons for every unmet row of a report, demo limit first, otherwise gate order.
static func reasons_for_report(rep: MHGateReport) -> Array:
	var out: Array = []
	for r: Variant in rep.rows:
		var row: Array = r
		if bool(row[1]):
			continue
		var reason: Dictionary = reason_for_row(row)
		if str(row[0]) == "demo_limit":
			out.push_front(reason)
		else:
			out.append(reason)
	return out


static func tier_state(view: MHGameStateView, building_id: String, tier: int) -> int:
	var defs: MHBuildingDefs = view.building_defs()
	var gate: MHGateView = view.gate_view()
	var owned: int = gate.tier_of(building_id)
	if tier <= owned:
		return TierState.OWNED
	if gate.demo and defs != null and tier > defs.demo_max_tier(building_id):
		return TierState.DEMO_LOCKED
	if tier == owned + 1:
		return TierState.NEXT
	return TierState.LOCKED


## Everything one building card needs. Empty dictionary when the catalogue is not loaded.
static func row(view: MHGameStateView, building_id: String) -> Dictionary:
	var defs: MHBuildingDefs = view.building_defs()
	if defs == null or not defs.is_loaded() or not defs.has_building(building_id):
		return {}
	var gate: MHGateView = view.gate_view()
	var owned: int = gate.tier_of(building_id)
	var nxt: int = MHUnlockRules.next_tier(gate, building_id)
	var tiers: Array = []
	for t: int in range(1, MHBuildingDefs.TIER_COUNT + 1):
		tiers.append(tier_state(view, building_id, t))
	var out: Dictionary = {
		"id": building_id,
		"name_key": "building." + building_id + ".name",
		"owned_tier": owned,
		"next_tier": nxt,
		"maxed": nxt == 0,
		"tiers": tiers,
		"heavy": defs.is_heavy(building_id),
		"cost": 0,
		"cost_known": false,
		"payback_days": 0,
		"income": 0,
		"upkeep": 0,
		"met": false,
		"demo_locked": false,
		"reasons": [],
		"can_buy": false,
	}
	if nxt == 0:
		return out
	var rep: MHGateReport = MHUnlockRules.check_gate(defs, building_id, nxt, gate)
	var income: int = view.added_daily_income(building_id, nxt)
	var cost: int = defs.price_for(building_id, nxt, income)
	out["income"] = income
	out["cost"] = cost
	out["cost_known"] = cost > 0
	out["payback_days"] = defs.target_payback_days(building_id, nxt)
	out["upkeep"] = defs.upkeep_per_day(building_id, nxt)
	out["met"] = rep.met
	out["demo_locked"] = rep.demo_locked
	out["reasons"] = reasons_for_report(rep)
	out["can_buy"] = rep.met and cost > 0 and view.cash() >= cost
	return out


static func rows(view: MHGameStateView) -> Array:
	var out: Array = []
	var defs: MHBuildingDefs = view.building_defs()
	if defs == null or not defs.is_loaded():
		return out
	for id: Variant in defs.ids():
		out.append(row(view, str(id)))
	return out


## Short status code for sorting and tests: "maxed", "demo", "locked", "poor" (gates met, cash short), "ready".
static func status(r: Dictionary) -> String:
	if r.is_empty():
		return "locked"
	if bool(r["maxed"]):
		return "maxed"
	if bool(r["demo_locked"]):
		return "demo"
	if not bool(r["met"]):
		return "locked"
	if not bool(r["can_buy"]):
		return "poor"
	return "ready"
