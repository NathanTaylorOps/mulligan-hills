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
	box.add_child(MHUIKit.label(MHStrings.t("management.course_traffic", {"active": int(r.get("active_parties", 0)),
		"blocked": int(r.get("blocked_parties", 0)), "pace": int(r.get("pace_score", 0))}), &"Label"))
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
			if str(warning) == "pace_bottleneck":
				wb.add_child(MHUIKit.label(MHStrings.t("management.pace_bottleneck", {"hole": int(r.get("pace_bottleneck_hole", 0))}), &"AccentLabel"))
			else:
				wb.add_child(MHUIKit.label(MHStrings.t("management.warning", {"warning": str(warning).replace("_", " ").capitalize()}), &"AccentLabel"))
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
		var employee_row: HBoxContainer = MHUIKit.hbox(6)
		sb.add_child(employee_row)
		employee_row.add_child(MHUIKit.label(MHStrings.t("management.employee", {"serial": int(e.get("serial", 0)),
			"role": MHStrings.t(str(e.get("name_key", ""))), "days": int(e.get("tenure", 0))}), &"Label"))
		if str(e.get("kind", "")) != "station":
			var area_actions: HFlowContainer = MHUIKit.flow(4)
			sb.add_child(area_actions)
			for area_v: Variant in r.get("owned_areas", []):
				var area: int = int(area_v)
				var current_areas: Array = e.get("areas", [])
				var next_areas: Array = current_areas.duplicate()
				if next_areas.has(area):
					next_areas.erase(area)
				else:
					next_areas.append(area)
					next_areas.sort()
				var area_button: MHTapButton = MHUIKit.button(ctx, MHStrings.t("management.parcel", {"parcel": area + 1}),
					&"SelectedButton" if current_areas.has(area) else &"ChipButton", 86.0)
				area_button.disabled = not current_areas.has(area) and current_areas.size() >= int(r.get("max_areas_per_employee", 0))
				area_button.pressed.connect(send.bind(&"assign_staff", {"employee_serial": int(e.get("serial", 0)), "areas": next_areas}))
				area_actions.add_child(area_button)
			var clear_button: MHTapButton = MHUIKit.button(ctx, MHStrings.t("management.unassign"), &"ChipButton", 80.0)
			clear_button.disabled = (e.get("areas", []) as Array).is_empty()
			clear_button.pressed.connect(send.bind(&"assign_staff", {"employee_serial": int(e.get("serial", 0)), "areas": []}))
			area_actions.add_child(clear_button)
		var fire_button: MHTapButton = MHUIKit.button(ctx, MHStrings.t("management.fire"), &"ChipButton", 80.0)
		fire_button.pressed.connect(send.bind(&"fire_staff", {"employee_serial": int(e.get("serial", 0))}))
		employee_row.add_child(fire_button)
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
		fb.add_child(MHUIKit.label(MHStrings.t("management.unit", {"serial": int(unit.get("serial", 0)),
			"type": str(unit.get("type", "equipment")).replace("_", " ").capitalize(), "status": status,
			"operator": "" if operator == 0 else MHStrings.t("management.operator", {"serial": operator})}), &"Label"))
		var actions: HFlowContainer = MHUIKit.flow(6)
		fb.add_child(actions)
		for employee_v: Variant in employees:
			var employee: Dictionary = employee_v
			if str(employee.get("kind", "")) != str(unit.get("kind", "")):
				continue
			var assign_button: MHTapButton = MHUIKit.button(ctx, MHStrings.t("management.staff_number", {"serial": int(employee.get("serial", 0))}), &"ChipButton", 72.0)
			assign_button.disabled = bool(unit.get("broken", false)) or operator == int(employee.get("serial", 0))
			assign_button.pressed.connect(send.bind(&"assign_staff_equipment", {"equipment_serial": int(unit.get("serial", 0)),
				"employee_serial": int(employee.get("serial", 0))}))
			actions.add_child(assign_button)
		var sell_button: MHTapButton = MHUIKit.button(ctx, MHStrings.t("management.sell",
			{"value": MHFormat.money_compact(int(unit.get("sale_value_cents", 0)) / 100)}), &"ChipButton", 110.0)
		sell_button.pressed.connect(send.bind(&"sell_staff_equipment", {"equipment_serial": int(unit.get("serial", 0))}))
		actions.add_child(sell_button)
