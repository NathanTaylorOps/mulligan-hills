class_name MHManagementScreen
extends MHScreen
## Lightweight staff/equipment overview for the mobile management loop.

func screen_id() -> String:
	return MHScreenIds.MANAGEMENT

func title_key() -> String:
	return "management.title"

func _build() -> void:
	_build_page()

func _fill() -> void:
	var r: Dictionary = view.management_report()
	if r.is_empty():
		_body.add_child(MHUIKit.label(MHStrings.t("management.unavailable"), &"SmallLabel"))
		return
	var summary: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(summary)
	_body.add_child(summary)
	box.add_child(MHUIKit.label(MHStrings.t("management.operations"), &"H2Label"))
	box.add_child(MHUIKit.label(MHStrings.t("management.staff_payroll", {"staff": int(r.get("head_count", 0)), "payroll": MHFormat.money_compact(int(r.get("payroll_cents", 0)) / 100)}), &"Label"))
	box.add_child(MHUIKit.label(MHStrings.t("management.condition_service", {"condition": int(r.get("avg_condition", 0)), "service": int(r.get("service", 0))}), &"Label"))
	box.add_child(MHUIKit.label(MHStrings.t("management.equipment_costs", {"units": int(r.get("equipment_units", 0)), "capacity": int(r.get("equipment_capacity", 0)), "operating": MHFormat.money_compact(int(r.get("equipment_operating_cost_cents", 0)) / 100), "repairs": MHFormat.money_compact(int(r.get("equipment_repair_cost_cents", 0)) / 100)}), &"SmallLabel"))
	var difficulty: HFlowContainer = MHUIKit.flow(8)
	_body.add_child(difficulty)
	for mode: String in ["relaxed", "standard", "tycoon"]:
		var b: MHTapButton = MHUIKit.button(ctx, MHStrings.t("management.difficulty." + mode), &"SelectedButton" if str(r.get("difficulty", "standard")) == mode else &"ChipButton", 120.0)
		b.pressed.connect(send.bind(&"set_management_difficulty", {"difficulty": mode}))
		difficulty.add_child(b)
	var warnings: Array = r.get("warnings", [])
	if not warnings.is_empty():
		var warning_card: PanelContainer = MHUIKit.card(6)
		var wb: VBoxContainer = MHUIKit.card_box(warning_card)
		_body.add_child(warning_card)
		wb.add_child(MHUIKit.label(MHStrings.t("management.attention"), &"H2Label"))
		for warning: Variant in warnings:
			wb.add_child(MHUIKit.label("• " + str(warning).replace("_", " ").capitalize(), &"AccentLabel"))
	var hire_options: Array = r.get("hire_options", [])
	var hire_card: PanelContainer = MHUIKit.card(6)
	var hb: VBoxContainer = MHUIKit.card_box(hire_card)
	_body.add_child(hire_card)
	hb.add_child(MHUIKit.label(MHStrings.t("management.hire"), &"H2Label"))
	for value: Variant in hire_options:
		var option: Dictionary = value
		if int(option.get("cap", 0)) <= 0:
			continue
		var row: HBoxContainer = MHUIKit.hbox(8)
		hb.add_child(row)
		row.add_child(MHUIKit.label(MHStrings.t("management.hire_row", {"role": MHStrings.t(str(option.get("name_key", ""))),
			"current": int(option.get("current", 0)), "cap": int(option.get("cap", 0)),
			"wage": MHFormat.money_compact(int(option.get("daily_wage_cents", 0)) / 100)}), &"Label"))
		var hire_button: MHTapButton = MHUIKit.button(ctx, MHStrings.t("management.hire_button",
			{"cost": MHFormat.money_compact(int(option.get("hire_cost_cents", 0)) / 100)}), &"ChipButton", 110.0)
		hire_button.disabled = not bool(option.get("available", false))
		hire_button.pressed.connect(send.bind(&"hire_staff", {"role": str(option.get("role", ""))}))
		row.add_child(hire_button)

	var catalog: Array = r.get("equipment_catalog", [])
	var shop_card: PanelContainer = MHUIKit.card(6)
	var shop: VBoxContainer = MHUIKit.card_box(shop_card)
	_body.add_child(shop_card)
	shop.add_child(MHUIKit.label(MHStrings.t("management.fleet_shop"), &"H2Label"))
	var fleet_full: bool = int(r.get("equipment_units", 0)) >= int(r.get("equipment_capacity", 0))
	for value: Variant in catalog:
		var item: Dictionary = value
		var row: HBoxContainer = MHUIKit.hbox(8)
		shop.add_child(row)
		row.add_child(MHUIKit.label(MHStrings.t("management.buy_row", {"type": str(item.get("type", "")).replace("_", " ").capitalize(),
			"price": MHFormat.money_compact(int(item.get("price_cents", 0)) / 100)}), &"Label"))
		var buy_button: MHTapButton = MHUIKit.button(ctx, MHStrings.t("management.buy_button"), &"ChipButton", 90.0)
		buy_button.disabled = fleet_full or not bool(item.get("available", false))
		buy_button.pressed.connect(send.bind(&"buy_staff_equipment", {"type": str(item.get("type", ""))}))
		row.add_child(buy_button)

	var employees: Array = r.get("employees", [])
	var staff_card: PanelContainer = MHUIKit.card(6)
	var sb: VBoxContainer = MHUIKit.card_box(staff_card)
	_body.add_child(staff_card)
	sb.add_child(MHUIKit.label(MHStrings.t("management.team"), &"H2Label"))
	if employees.is_empty(): sb.add_child(MHUIKit.label(MHStrings.t("management.no_staff"), &"SmallLabel"))
	for value: Variant in employees:
		var e: Dictionary = value
		sb.add_child(MHUIKit.label(MHStrings.t("management.employee", {"serial": int(e.get("serial", 0)), "role": str(e.get("role", "staff")).replace("_", " ").capitalize(), "days": int(e.get("tenure", 0))}), &"Label"))
	var fleet: Array = r.get("equipment", [])
	var fleet_card: PanelContainer = MHUIKit.card(6)
	var fb: VBoxContainer = MHUIKit.card_box(fleet_card)
	_body.add_child(fleet_card)
	fb.add_child(MHUIKit.label(MHStrings.t("management.equipment"), &"H2Label"))
	if fleet.is_empty(): fb.add_child(MHUIKit.label(MHStrings.t("management.no_equipment"), &"SmallLabel"))
	for value: Variant in fleet:
		var unit: Dictionary = value
		var status: String = MHStrings.t("management.broken") if bool(unit.get("broken", false)) else "%d/1000" % int(unit.get("condition", 0))
		var operator: int = int(unit.get("assigned_employee", 0))
		fb.add_child(MHUIKit.label(MHStrings.t("management.unit", {"serial": int(unit.get("serial", 0)), "type": str(unit.get("type", "equipment")).replace("_", " ").capitalize(), "status": status, "operator": "" if operator == 0 else MHStrings.t("management.operator", {"serial": operator})}), &"Label"))
