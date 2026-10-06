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


## Label of the buy button of a row: "Buy T2 $1,200", or "-" when nothing can be bought.
## `cost_dollars` is the real charge (MHEconomy.price_cents / 100), which the scene computes itself.
static func buy_label(row: Dictionary, cost_dollars: int) -> String:
	if row.is_empty() or bool(row["maxed"]) or bool(row["demo_locked"]):
		return "-"
	return "Buy T%d %s" % [int(row["next_tier"]), MHFormat.money(cost_dollars)]


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
