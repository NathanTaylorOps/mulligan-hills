class_name MHTournamentScreen
extends MHScreen
## Tournaments: local, regional, national, major. Each card shows status, entry checklist (met and missing),
## host cost and reward. In the demo only a preview shows (DEC-028). Intent: tournament_host {level}.


func screen_id() -> String:
	return MHScreenIds.TOURNAMENT


func title_key() -> String:
	return "tournament.title"


func _fill() -> void:
	if view.is_demo():
		_body.add_child(MHUIKit.label(MHStrings.t("tournament.demo_preview"), &"WarnLabel"))
	var g: GridContainer = MHUIKit.grid(ctx.columns(2), 12)
	_body.add_child(g)
	for t: Variant in view.tournaments():
		g.add_child(_card(t))


func _card(t: Variant) -> Control:
	var d: Dictionary = t
	var level: String = str(d["level"])
	var card: PanelContainer = MHUIKit.card(6)
	var box: VBoxContainer = MHUIKit.card_box(card)
	box.add_child(MHUIKit.label(MHStrings.t("tournament." + level + ".name"), &"H2Label"))
	box.add_child(MHUIKit.label(MHStrings.t("tournament.status." + str(d["status"])), &"MutedLabel"))
	box.add_child(MHUIKit.label(MHStrings.t("tournament.cost_reward", {"cost": MHFormat.money(int(d["host_cost"])), "reward": MHFormat.money(int(d["reward_cash"])), "rep": int(d["reward_reputation"])}), &"Label"))
	var all_met: bool = true
	for r: Variant in d["rows"]:
		var row: Array = r
		var reason: Dictionary = MHBuildMenuModel.reason_for_row(row)
		var met: bool = bool(row[1])
		if not met:
			all_met = false
		box.add_child(MHUIKit.label(MHStrings.t(str(reason["key"]), reason["params"]), &"GoodLabel" if met else &"WarnLabel"))
	var b: MHTapButton = MHUIKit.button(ctx, MHStrings.t("tournament.host"), &"PrimaryButton")
	var open_now: bool = str(d["status"]) == "available" and all_met and not view.is_demo()
	b.disabled = not open_now
	if open_now:
		b.pressed.connect(send.bind(&"tournament_host", {"level": level}))
	box.add_child(b)
	return card
