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
