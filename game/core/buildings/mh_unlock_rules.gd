class_name MHUnlockRules
extends RefCounted
## Pure tier-gate checks over MHBuildingDefs and an MHGateView. No state, integers only. NOT YET RUN.
## Buying tier T of a building needs: tier T-1 standing, demo cap (demo builds), holes (non-dead),
## average hole score, parcels owned (heavy buildings carry +1 at tiers 2..5 in the data), a parcel
## of a required kind (Homes), members, specific other-building tiers, any-N-others at tier X,
## and a hosted tournament level (tier 5). Cash is NOT checked here; the economy prices via
## MHBuildingDefs.price_for.


static func check_gate(defs: MHBuildingDefs, id: String, tier: int, view: MHGateView) -> MHGateReport:
	var rep: MHGateReport = MHGateReport.new()
	if not defs.is_loaded() or not defs.has_building(id) or tier < 1 or tier > MHBuildingDefs.TIER_COUNT:
		rep.add("unknown_tier", false, 0, 1)
		rep.finish()
		return rep
	var have_tier: int = view.tier_of(id)
	rep.add("previous_tier", have_tier == tier - 1, have_tier, tier - 1)
	if view.demo:
		var cap: int = defs.demo_max_tier(id)
		rep.demo_locked = tier > cap
		rep.add("demo_limit", tier <= cap, tier, cap)
	var r: Dictionary = defs.tier_requires(id, tier)
	var need_holes: int = int(r["min_holes"])
	rep.add("holes", view.holes >= need_holes, view.holes, need_holes)
	var need_score: int = int(r["min_avg_hole_score"])
	rep.add("avg_hole_score", view.avg_hole_score >= need_score, view.avg_hole_score, need_score)
	var need_parcels: int = int(r["min_parcels_owned"])
	rep.add("parcels_owned", view.parcels_owned >= need_parcels, view.parcels_owned, need_parcels)
	var kind: String = defs.needs_parcel_kind(id)
	if kind != "":
		rep.add("parcel_kind:" + kind, view.kind_count(kind) >= 1, view.kind_count(kind), 1)
	var need_members: int = int(r["min_members"])
	rep.add("members", view.members >= need_members, view.members, need_members)
	var spec: Array = r["specific"]
	for s: Variant in spec:
		var sd: Dictionary = s
		var bid: String = str(sd["building"])
		var mt: int = int(sd["min_tier"])
		rep.add("building:" + bid, view.tier_of(bid) >= mt, view.tier_of(bid), mt)
	var ao: Variant = r["any_others"]
	if ao != null:
		var aod: Dictionary = ao
		var need_count: int = int(aod["count"])
		var min_t: int = int(aod["min_tier"])
		var n: int = 0
		for other: Variant in defs.ids():
			var oid: String = str(other)
			if oid != id and view.tier_of(oid) >= min_t:
				n += 1
		rep.add("any_others", n >= need_count, n, need_count)
	var ht: Variant = r["hosted_tournament"]
	if ht != null:
		var htd: Dictionary = ht
		var need_rank: int = MHBuildingDefs.level_rank(str(htd["min_level"]))
		var have_rank: int = MHBuildingDefs.level_rank(view.hosted_level)
		rep.add("hosted_tournament", have_rank >= need_rank, have_rank, need_rank)
	rep.finish()
	return rep


## The next tier to buy for a building, or 0 if it is at tier 5.
static func next_tier(view: MHGateView, id: String) -> int:
	var t: int = view.tier_of(id) + 1
	return t if t <= MHBuildingDefs.TIER_COUNT else 0


## Building ids (data order) whose next tier passes every gate right now.
static func purchasable(defs: MHBuildingDefs, view: MHGateView) -> Array:
	var out: Array = []
	for b: Variant in defs.ids():
		var id: String = str(b)
		var nt: int = next_tier(view, id)
		if nt > 0 and check_gate(defs, id, nt, view).met:
			out.append(id)
	return out


static func demo_locked(defs: MHBuildingDefs, id: String, tier: int) -> bool:
	return tier > defs.demo_max_tier(id)


static func parcels_required(defs: MHBuildingDefs, id: String, tier: int) -> int:
	var r: Dictionary = defs.tier_requires(id, tier)
	return int(r.get("min_parcels_owned", 0))


## Tiers that a demo player is allowed to buy (tier <= demo cap) but can never reach because the
## tier's hole gate is above the demo hole cap. Format "building:tier", data order.
## Known conflict at time of writing: clubhouse:3 (needs 10 holes, demo caps at 9).
static func demo_unreachable(defs: MHBuildingDefs) -> Array:
	var out: Array = []
	var cap_holes: int = defs.demo_max_holes()
	for b: Variant in defs.ids():
		var id: String = str(b)
		for t: int in range(1, defs.demo_max_tier(id) + 1):
			var r: Dictionary = defs.tier_requires(id, t)
			if int(r["min_holes"]) > cap_holes:
				out.append(id + ":" + str(t))
	return out
