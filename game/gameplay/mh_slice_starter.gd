class_name MHSliceStarter
extends RefCounted
## Starter club of the vertical slice, built through the session's own player paths (submit_course, handle_intent), so
## nothing here bypasses a gate, a price or the rating engine. No scene tree. Tests run the same code on a bare session.
##
## Why this shape (numbers in docs/phase1/vertical_slice.md, from tools/reference/economy):
##  - Three distinct holes. The rating roll-up cuts a hole that copies an earlier one to 40 percent, so identical
##    holes dragged the course to 20 to 23 (each alone scored 42). See MHSliceLayout.HOLE_DESIGNS.
##  - Four tier 1 buildings. With the locked economy no building-free course earns its upkeep at this size
##    (3 holes: about -$130 a day). The four cheapest demand and ancillary buildings cost $1,920 together and turn the
##    day positive. Late tiers still cost what the economy says; nothing is discounted.
## NOT YET RUN in Godot.
@warning_ignore_start("integer_division")

const STARTER_HOLES: int = 3
## Bought in this order at start (tier 1 each). All four are allowed by the tier 1 gates (no holes needed).
const STARTER_BUILDINGS: Array = ["clubhouse", "pro_shop", "restaurant", "driving_range"]


## Builds the lowest free hole slot whose parcels are owned. Returns "" or a plain-words reason.
static func build_next_hole(session: MHGameSession) -> String:
	var defs: Array = session.hole_definitions()
	var taken: Array = []
	for d: Variant in defs:
		taken.append(int((d as Dictionary)["slot_id"]))
	var slot: int = MHSliceLayout.next_hole_slot(taken, session.land.owned_ids())
	if slot < 0:
		return "no free hole site, buy more land first"
	var cost: int = session.economy.hole_cost_cents()
	if not session.economy.can_afford(cost):
		return "not enough cash, the next hole costs %s" % MHFormat.money(cost / 100)
	defs.append(MHSliceLayout.hole_template(slot))
	var result: Dictionary = session.submit_course(defs)
	if bool(result.get("ok", false)):
		return ""
	return MHSliceText.intent_words(str(result.get("reason", "")))


## Buys the next tier of `building_id` through the session. Returns "" or a plain-words reason.
static func buy_next_tier(session: MHGameSession, view: MHGameStateView, building_id: String) -> String:
	var row: Dictionary = MHBuildMenuModel.row(view, building_id)
	if row.is_empty() or bool(row["maxed"]):
		return "nothing left to buy"
	var result: Dictionary = session.handle_intent(&"buy_tier", {"building": building_id, "tier": int(row["next_tier"])})
	if bool(result.get("ok", false)):
		return ""
	return MHSliceText.intent_words(str(result.get("reason", "")))


## Starter holes, starter buildings and the economy's own fee suggestion. Returns "" or the first refusal.
static func setup(session: MHGameSession, view: MHGameStateView) -> String:
	for i: int in range(STARTER_HOLES):
		var err: String = build_next_hole(session)
		if err != "":
			return "starter hole: " + err
	for id: Variant in STARTER_BUILDINGS:
		var err2: String = buy_next_tier(session, view, str(id))
		if err2 != "":
			return "starter %s: %s" % [str(id), err2]
	session.handle_intent(&"set_green_fee", {"cents": session.economy.suggest_fee()})
	return ""
