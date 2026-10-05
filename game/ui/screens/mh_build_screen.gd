class_name MHBuildScreen
extends MHScreen
## Build menu: 10 buildings x 5 tiers. Cost = target payback days x added daily income (DEC-050), locked reasons
## listed per card, a details card for the selected building (all 5 tiers with their gates).
## Intents: buy_tier {building, tier}, show_unlock.

var _selected: String = ""


func screen_id() -> String:
	return MHScreenIds.BUILD


func title_key() -> String:
	return "build.title"


func _fill() -> void:
	var defs: MHBuildingDefs = view.building_defs()
	if defs == null or not defs.is_loaded():
		_body.add_child(MHUIKit.label(MHStrings.t("build.no_catalogue"), &"WarnLabel"))
		return
	var head: HBoxContainer = MHUIKit.hbox(12)
	head.add_child(MHUIKit.label(MHStrings.t("build.cash", {"amount": MHFormat.money(view.cash())}), &"H2Label"))
	if view.is_demo():
		head.add_child(MHUIKit.label(MHStrings.t("build.demo_note"), &"MutedLabel"))
	_body.add_child(head)
	var g: GridContainer = MHUIKit.grid(ctx.columns(3), 12)
	_body.add_child(g)
	var rows: Array = MHBuildMenuModel.rows(view)
	for r: Variant in rows:
		g.add_child(_building_card(r))
	if _selected != "":
		_body.add_child(_details_card(defs, _selected))


func _pips(r: Dictionary) -> Control:
	var h: HBoxContainer = MHUIKit.hbox(6)
	var tiers: Array = r["tiers"]
	for st: Variant in tiers:
		var c: Color = MHTheme.LINE
		match int(st):
			MHBuildMenuModel.TierState.OWNED:
				c = MHTheme.GREEN
			MHBuildMenuModel.TierState.NEXT:
				c = MHTheme.ACCENT
			MHBuildMenuModel.TierState.DEMO_LOCKED:
				c = MHTheme.DISABLED_TEXT
		var pip: ColorRect = MHUIKit.color_rect(c)
		pip.custom_minimum_size = Vector2(30.0, 12.0)
		h.add_child(pip)
	return h


func _building_card(r: Dictionary) -> Control:
	var card: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(card)
	var id: String = str(r["id"])
	box.add_child(MHUIKit.label(MHStrings.t(str(r["name_key"])), &"H2Label"))
	box.add_child(_pips(r))
	box.add_child(MHUIKit.label(MHStrings.t("build.tier_of", {"tier": int(r["owned_tier"]), "max": MHBuildingDefs.TIER_COUNT}), &"MutedLabel"))
	var status: String = MHBuildMenuModel.status(r)
	if status == "maxed":
		box.add_child(MHUIKit.label(MHStrings.t("build.maxed"), &"GoodLabel"))
	else:
		var nxt: int = int(r["next_tier"])
		if bool(r["cost_known"]):
			box.add_child(MHUIKit.label(MHStrings.t("build.next_cost", {"tier": nxt, "cost": MHFormat.money(int(r["cost"]))}), &"Label"))
			box.add_child(MHUIKit.label(MHStrings.t("build.payback", {"days": int(r["payback_days"]), "income": MHFormat.money(int(r["income"])), "upkeep": MHFormat.money(int(r["upkeep"]))}), &"MutedLabel"))
		else:
			box.add_child(MHUIKit.label(MHStrings.t("build.next_cost_unknown", {"tier": nxt}), &"Label"))
		var reasons: Array = r["reasons"]
		var shown: int = mini(reasons.size(), MHBuildMenuModel.MAX_REASONS_SHOWN)
		for i: int in range(shown):
			box.add_child(_reason_label(reasons[i]))
		if reasons.size() > shown:
			box.add_child(MHUIKit.label(MHStrings.t("build.more_reasons", {"count": reasons.size() - shown}), &"MutedLabel"))
		box.add_child(_buy_button(r, status))
	var det: MHTapButton = MHUIKit.button(ctx, MHStrings.t("build.hide_details" if _selected == id else "build.details"), &"GhostButton")
	det.pressed.connect(_on_details.bind(id))
	box.add_child(det)
	return card


func _reason_label(reason: Dictionary) -> Label:
	var text_value: String = MHStrings.t(str(reason["key"]), reason["params"])
	return MHUIKit.label(text_value, &"WarnLabel")


func _buy_button(r: Dictionary, status: String) -> Control:
	var id: String = str(r["id"])
	var nxt: int = int(r["next_tier"])
	if status == "demo":
		var u: MHTapButton = MHUIKit.button(ctx, MHStrings.t("build.unlock_full"), &"GreenButton")
		u.pressed.connect(send.bind(&"show_unlock", {}))
		return u
	var b: MHTapButton = MHUIKit.button(ctx, "", &"PrimaryButton")
	if status == "ready":
		b.text = MHStrings.t("build.buy", {"tier": nxt})
		b.pressed.connect(send.bind(&"buy_tier", {"building": id, "tier": nxt}))
	elif status == "poor":
		var missing: int = maxi(0, int(r["cost"]) - view.cash())
		b.text = MHStrings.t("build.need_cash", {"amount": MHFormat.money(missing)})
		b.disabled = true
	else:
		b.text = MHStrings.t("build.locked")
		b.disabled = true
	return b


func _on_details(id: String) -> void:
	_selected = "" if _selected == id else id
	refresh()


func _details_card(defs: MHBuildingDefs, id: String) -> Control:
	var card: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(card)
	box.add_child(MHUIKit.label(MHStrings.t("build.details_title", {"building_key": "building." + id + ".name"}), &"H2Label"))
	box.add_child(MHUIKit.label(MHStrings.t("building." + id + ".desc"), &"MutedLabel"))
	var gate: MHGateView = view.gate_view()
	for t: int in range(1, MHBuildingDefs.TIER_COUNT + 1):
		box.add_child(MHUIKit.rule())
		var income: int = view.added_daily_income(id, t)
		var cost: int = defs.price_for(id, t, income)
		var cost_text: String = MHFormat.money(cost) if cost > 0 else MHStrings.t("build.cost_unknown")
		var state: int = MHBuildMenuModel.tier_state(view, id, t)
		var state_key: String = "build.state.locked"
		if state == MHBuildMenuModel.TierState.OWNED:
			state_key = "build.state.owned"
		elif state == MHBuildMenuModel.TierState.NEXT:
			state_key = "build.state.next"
		elif state == MHBuildMenuModel.TierState.DEMO_LOCKED:
			state_key = "build.state.demo"
		box.add_child(MHUIKit.label(MHStrings.t("build.tier_line", {"tier": t, "cost": cost_text, "days": defs.target_payback_days(id, t), "state_key": state_key}), &"Label"))
		if state != MHBuildMenuModel.TierState.OWNED:
			var rep: MHGateReport = MHUnlockRules.check_gate(defs, id, t, gate)
			for rr: Variant in rep.rows:
				var row: Array = rr
				if str(row[0]) == "previous_tier" or str(row[0]) == "demo_limit":
					continue
				var reason: Dictionary = MHBuildMenuModel.reason_for_row(row)
				var variant: StringName = &"GoodLabel" if bool(row[1]) else &"WarnLabel"
				box.add_child(MHUIKit.label(MHStrings.t(str(reason["key"]), reason["params"]), variant))
	return card
