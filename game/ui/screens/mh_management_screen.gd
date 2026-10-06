class_name MHManagementScreen
extends MHScreen
## Lightweight staff/equipment overview for the mobile management loop.

func screen_id() -> String:
	return MHScreenIds.MANAGEMENT

func title_key() -> String:
	return "Management"

func _build() -> void:
	_build_page()

func _fill() -> void:
	var r: Dictionary = view.management_report()
	if r.is_empty():
		_body.add_child(MHUIKit.label("Management data unavailable.", &"SmallLabel"))
		return
	var summary: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(summary)
	_body.add_child(summary)
	box.add_child(MHUIKit.label("Course Operations", &"H2Label"))
	box.add_child(MHUIKit.label("Staff %d   Payroll %s/day" % [int(r.get("head_count", 0)), MHFormat.money_compact(int(r.get("payroll_cents", 0)) / 100)], &"Label"))
	box.add_child(MHUIKit.label("Course condition %d/1000   Service %d/1000" % [int(r.get("avg_condition", 0)), int(r.get("service", 0))], &"Label"))
	box.add_child(MHUIKit.label("Equipment %d/%d   Operating %s   Repairs %s" % [int(r.get("equipment_units", 0)), int(r.get("equipment_capacity", 0)), MHFormat.money_compact(int(r.get("equipment_operating_cost_cents", 0)) / 100), MHFormat.money_compact(int(r.get("equipment_repair_cost_cents", 0)) / 100)], &"MutedLabel"))
	var difficulty: HFlowContainer = MHUIKit.flow(8)
	_body.add_child(difficulty)
	for mode: String in ["relaxed", "standard", "tycoon"]:
		var b: MHTapButton = MHUIKit.button(ctx, mode.capitalize(), &"SelectedButton" if str(r.get("difficulty", "standard")) == mode else &"ChipButton", 120.0)
		b.pressed.connect(send.bind(&"set_management_difficulty", {"difficulty": mode}))
		difficulty.add_child(b)
	var warnings: Array = r.get("warnings", [])
	if not warnings.is_empty():
		var warning_card: PanelContainer = MHUIKit.card(6)
		var wb: VBoxContainer = MHUIKit.card_box(warning_card)
		_body.add_child(warning_card)
		wb.add_child(MHUIKit.label("Needs attention", &"H2Label"))
		for warning: Variant in warnings:
			wb.add_child(MHUIKit.label("• " + str(warning).replace("_", " ").capitalize(), &"AccentLabel"))
	var employees: Array = r.get("employees", [])
	var staff_card: PanelContainer = MHUIKit.card(6)
	var sb: VBoxContainer = MHUIKit.card_box(staff_card)
	_body.add_child(staff_card)
	sb.add_child(MHUIKit.label("Team", &"H2Label"))
	if employees.is_empty(): sb.add_child(MHUIKit.label("No staff hired yet.", &"MutedLabel"))
	for value: Variant in employees:
		var e: Dictionary = value
		sb.add_child(MHUIKit.label("#%d  %s  •  experience %d days" % [int(e.get("serial", 0)), str(e.get("role", "staff")).replace("_", " ").capitalize(), int(e.get("tenure", 0))], &"Label"))
	var fleet: Array = r.get("equipment", [])
	var fleet_card: PanelContainer = MHUIKit.card(6)
	var fb: VBoxContainer = MHUIKit.card_box(fleet_card)
	_body.add_child(fleet_card)
	fb.add_child(MHUIKit.label("Equipment", &"H2Label"))
	if fleet.is_empty(): fb.add_child(MHUIKit.label("No equipment owned yet.", &"MutedLabel"))
	for value: Variant in fleet:
		var unit: Dictionary = value
		var status: String = "broken" if bool(unit.get("broken", false)) else "%d/1000" % int(unit.get("condition", 0))
		var operator: int = int(unit.get("assigned_employee", 0))
		fb.add_child(MHUIKit.label("#%d  %s  •  %s%s" % [int(unit.get("serial", 0)), str(unit.get("type", "equipment")).replace("_", " ").capitalize(), status, "" if operator == 0 else "  •  staff #%d" % operator], &"Label"))
