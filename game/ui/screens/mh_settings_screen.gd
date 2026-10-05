class_name MHSettingsScreen
extends MHScreen
## Settings: frame cap (30 / 60 / auto), units (metric / imperial), analytics opt-in, text size,
## left-handed layout, colour palette, restore purchases, account deletion, build info.
## Changes go straight into ctx.settings (an MHUISettings); the shell saves it. Every change also emits
## settings_changed {key}. Other intents: restore_purchases, show_modal {modal}, replay_tutorial.


func screen_id() -> String:
	return MHScreenIds.SETTINGS


func title_key() -> String:
	return "settings.title"


func _fill() -> void:
	var s: MHUISettings = ctx.settings
	var cols: int = ctx.columns(2)
	var g: GridContainer = MHUIKit.grid(cols, 12)
	_body.add_child(g)

	var perf: VBoxContainer = _section(g, "settings.fps.title", "settings.fps.note")
	var fps_row: HFlowContainer = MHUIKit.flow(8)
	perf.add_child(fps_row)
	for id: String in ["30", "60", "auto"]:
		fps_row.add_child(_choice(MHStrings.t("settings.fps." + id), s.frame_cap == id, _on_frame_cap.bind(id)))

	var units: VBoxContainer = _section(g, "settings.units.title", "")
	var u_row: HFlowContainer = MHUIKit.flow(8)
	units.add_child(u_row)
	u_row.add_child(_choice(MHStrings.t("settings.units.metric"), s.is_metric(), _on_units.bind(MHUISettings.UNITS_METRIC)))
	u_row.add_child(_choice(MHStrings.t("settings.units.imperial"), not s.is_metric(), _on_units.bind(MHUISettings.UNITS_IMPERIAL)))
	units.add_child(MHUIKit.label(MHStrings.t("settings.units.sample", {"length": MHFormat.distance(372, s.is_metric()), "height": MHFormat.height_mm(1200, s.is_metric())}), &"MutedLabel"))

	var priv: VBoxContainer = _section(g, "settings.privacy.title", "settings.privacy.note")
	var a: MHTapButton = _choice(MHStrings.t("settings.privacy.on" if s.analytics_opt_in else "settings.privacy.off"), s.analytics_opt_in, _on_analytics)
	priv.add_child(a)

	var acc: VBoxContainer = _section(g, "settings.access.title", "")
	var t_row: HBoxContainer = MHUIKit.hbox(8)
	acc.add_child(t_row)
	var minus: MHTapButton = MHUIKit.button(ctx, MHStrings.t("ui.common.minus"), &"ChipButton")
	minus.disabled = s.text_scale_pct <= MHTheme.TEXT_SCALE_MIN
	minus.pressed.connect(_on_text_step.bind(-1))
	var plus: MHTapButton = MHUIKit.button(ctx, MHStrings.t("ui.common.plus"), &"ChipButton")
	plus.disabled = s.text_scale_pct >= MHTheme.TEXT_SCALE_MAX
	plus.pressed.connect(_on_text_step.bind(1))
	t_row.add_child(minus)
	t_row.add_child(MHUIKit.label(MHStrings.t("settings.access.text_size", {"percent": s.text_scale_pct}), &"Label", false))
	t_row.add_child(plus)
	acc.add_child(_choice(MHStrings.t("settings.access.left_on" if s.left_handed else "settings.access.left_off"), s.left_handed, _on_left_handed))
	var cb: MHTapButton = MHUIKit.button(ctx, MHStrings.t("settings.access.palette", {"name_key": "settings.palette." + str(s.colorblind)}), &"ChipButton")
	cb.pressed.connect(_on_palette)
	acc.add_child(cb)

	var acct: VBoxContainer = _section(g, "settings.account.title", "settings.account.note")
	var restore: MHTapButton = MHUIKit.button(ctx, MHStrings.t("settings.account.restore"), &"GreenButton")
	restore.pressed.connect(send.bind(&"restore_purchases", {}))
	acct.add_child(restore)
	var tut: MHTapButton = MHUIKit.button(ctx, MHStrings.t("settings.account.replay"), &"ChipButton")
	tut.pressed.connect(send.bind(&"replay_tutorial", {}))
	acct.add_child(tut)
	var del: MHTapButton = MHUIKit.button(ctx, MHStrings.t("settings.account.delete"), &"PrimaryButton")
	del.pressed.connect(send.bind(&"show_modal", {"modal": MHScreenIds.CONFIRM_DELETE}))
	acct.add_child(del)

	_body.add_child(MHUIKit.label(MHBuildInfo.label_text(), &"MutedLabel"))


func _section(parent: Control, title_k: String, note_k: String) -> VBoxContainer:
	var card: PanelContainer = MHUIKit.card(8)
	var box: VBoxContainer = MHUIKit.card_box(card)
	box.add_child(MHUIKit.label(MHStrings.t(title_k), &"H2Label"))
	if note_k != "":
		box.add_child(MHUIKit.label(MHStrings.t(note_k), &"MutedLabel"))
	parent.add_child(card)
	return box


func _choice(text_value: String, selected: bool, handler: Callable) -> MHTapButton:
	var b: MHTapButton = MHUIKit.button(ctx, text_value, &"SelectedButton" if selected else &"ChipButton", 120.0)
	b.pressed.connect(handler)
	return b


func _changed(key: String) -> void:
	send(&"settings_changed", {"key": key})
	refresh()


func _on_frame_cap(id: String) -> void:
	ctx.settings.set_frame_cap(id)
	_changed("frame_cap")


func _on_units(id: String) -> void:
	ctx.settings.set_units(id)
	_changed("units")


func _on_analytics() -> void:
	ctx.settings.set_analytics_opt_in(not ctx.settings.analytics_opt_in)
	_changed("analytics_opt_in")


func _on_text_step(direction: int) -> void:
	ctx.settings.set_text_scale(MHTheme.step_text_scale(ctx.settings.text_scale_pct, direction))
	_changed("text_scale_pct")


func _on_left_handed() -> void:
	ctx.settings.set_left_handed(not ctx.settings.left_handed)
	_changed("left_handed")


func _on_palette() -> void:
	ctx.settings.set_colorblind((ctx.settings.colorblind + 1) % 4)
	_changed("colorblind")
