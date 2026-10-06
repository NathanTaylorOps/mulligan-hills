class_name MHSliceText
extends RefCounted
## Plain-text helpers for the vertical slice HUD. Pure, no scene tree. Development wording, not the final
## localized strings (MHStrings keys are not used here on purpose, so the slice needs no string table).
## NOT YET RUN in Godot.
@warning_ignore_start("integer_division")


static func building_title(id: String) -> String:
	return id.replace("_", " ").capitalize()


## "holes 0/6" from a MHBuildMenuModel reason dictionary ({key, params, have, need}).
static func reason_text(reason: Dictionary) -> String:
	var key: String = str(reason.get("key", ""))
	var short: String = key.trim_prefix("build.req.").replace("_", " ")
	if short == "":
		short = "requirement"
	return "%s %d/%d" % [short, int(reason.get("have", 0)), int(reason.get("need", 0))]


## One-line summary of a MHBuildMenuModel.row() dictionary, shown next to the buy button.
static func row_summary(row: Dictionary) -> String:
	if row.is_empty():
		return ""
	var title: String = building_title(str(row["id"]))
	var owned: int = int(row["owned_tier"])
	if bool(row["maxed"]):
		return "%s  T%d (max)" % [title, owned]
	var head: String = "%s  T%d" % [title, owned] if owned > 0 else "%s  not built" % title
	if bool(row["demo_locked"]):
		return head + "  demo limit"
	if not bool(row["met"]):
		var parts: PackedStringArray = PackedStringArray()
		var reasons: Array = row["reasons"] as Array
		for i: int in range(mini(reasons.size(), 2)):
			parts.append(reason_text(reasons[i] as Dictionary))
		return head + "  needs " + ", ".join(parts)
	return "%s  next T%d  +%s/day" % [head, int(row["next_tier"]), MHFormat.money(int(row["income"]))]


## Label of the buy button of a row: "Buy T2 $1,200", "T2 $1,200 locked" when a requirement is unmet, or "-" when
## nothing can be bought. `cost_dollars` is the real charge (MHEconomy.price_cents / 100), which the scene computes
## itself, and it is shown whether or not the row can be bought right now.
static func buy_label(row: Dictionary, cost_dollars: int) -> String:
	if row.is_empty() or bool(row["maxed"]) or bool(row["demo_locked"]):
		return "-"
	if not bool(row["met"]):
		return "T%d %s locked" % [int(row["next_tier"]), MHFormat.money(cost_dollars)]
	return "Buy T%d %s" % [int(row["next_tier"]), MHFormat.money(cost_dollars)]


## A blocking reason ({key, params, have, need} from MHBuildMenuModel) in plain words, for example
## "needs 6 playable holes (you have 2)".
static func reason_words(reason: Dictionary) -> String:
	var key: String = str(reason.get("key", ""))
	var have: int = int(reason.get("have", 0))
	var need: int = int(reason.get("need", 0))
	var params: Dictionary = {}
	if typeof(reason.get("params", null)) == TYPE_DICTIONARY:
		params = reason["params"] as Dictionary
	match key:
		"build.req.holes":
			return "needs %d playable holes (you have %d)" % [need, have]
		"build.req.avg_score":
			return "needs an average hole score of %d (yours is %d)" % [need, have]
		"build.req.parcels":
			return "needs %d parcels of land (you own %d)" % [need, have]
		"build.req.members":
			return "needs %d members (you have %d)" % [need, have]
		"build.req.previous":
			return "needs the tier below it first"
		"build.req.demo":
			return "is not in the demo"
		"build.req.any_others":
			return "needs %d other buildings at a higher tier (you have %d)" % [need, have]
		"build.req.building":
			var other: String = str(params.get("building_key", "")).trim_prefix("building.").trim_suffix(".name")
			return "needs %s at tier %d (you have tier %d)" % [building_title(other), need, have]
		"build.req.parcel_kind":
			var kind: String = str(params.get("kind_key", "")).trim_prefix("land.kind.")
			return "needs a %s parcel" % kind
		"build.req.hosted":
			var level: String = str(params.get("level_key", "")).trim_prefix("tournament.").trim_suffix(".name")
			return "needs a hosted %s tournament" % level
		"build.req.pace":
			return "needs a pace score of %d (you have %d)" % [need, have]
		"build.req.staff":
			return "needs %d staff (you have %d)" % [need, have]
		"build.req.spectators":
			return "needs %d spectators (you have %d)" % [need, have]
	return "needs " + reason_text(reason)


## The text next to a buy button. `cost_dollars` is the real charge (MHEconomy.price_cents / 100) and `cash_dollars`
## the club's cash. A blocked row says why in plain words, a row that only lacks cash says how much.
static func row_text(row: Dictionary, cost_dollars: int, cash_dollars: int) -> String:
	if row.is_empty():
		return ""
	var title: String = building_title(str(row["id"]))
	var owned: int = int(row["owned_tier"])
	if bool(row["maxed"]):
		return "%s  T%d (max)" % [title, owned]
	var head: String = "%s  T%d" % [title, owned] if owned > 0 else "%s  not built" % title
	if bool(row["demo_locked"]):
		return head + "  demo limit"
	if not bool(row["met"]):
		var parts: PackedStringArray = PackedStringArray()
		var reasons: Array = row["reasons"] as Array
		for i: int in range(mini(reasons.size(), 2)):
			parts.append(reason_words(reasons[i] as Dictionary))
		return head + "  Locked, " + "; ".join(parts)
	var line: String = "%s  next T%d  +%s/day" % [head, int(row["next_tier"]), MHFormat.money(int(row["income"]))]
	if cost_dollars > cash_dollars:
		line += "  Need %s more" % MHFormat.money(cost_dollars - cash_dollars)
	return line


## A refused session intent in plain words. `reason` is the session's reason code or a submit_course code.
static func intent_words(reason: String) -> String:
	match reason:
		"gate":
			return "its requirements are not met yet"
		"cash":
			return "not enough cash"
		"parcel":
			return "that parcel cannot be bought"
		"hole_cap":
			return "your land holds no more holes"
		"tournament_locked":
			return "the course is locked for a tournament"
		"":
			return "refused"
	return reason


## Gross income per game hour in whole dollars from a day revenue in cents (11 game hours per day).
static func income_per_hour_dollars(day_revenue_cents: int) -> int:
	return day_revenue_cents / 100 / MHEconomyParams.HOURS_PER_DAY


## Second HUD line: fee and net are whole dollars.
static func detail_line(fee_dollars: int, net_day: int, holes: int, members: int) -> String:
	return "Green fee %s   Net %s/day   Holes %d   Members %d" % [MHFormat.money(fee_dollars), MHFormat.money(net_day), holes, members]


## The top HUD line. cash and income values are whole dollars; rating is the course score in tenths (0..1000).
static func hud_line(cash: int, day: int, minute_of_day: int, rating_x10: int, income_hour: int, golfers_on_course: int) -> String:
	return "Cash %s   Day %d %s   Rating %s   Income %s/hr   Golfers %d" % [MHFormat.money(cash),
		MHFormat.day_number(day), MHFormat.game_clock(minute_of_day), MHFormat.score_x10(rating_x10),
		MHFormat.money(income_hour), golfers_on_course]
