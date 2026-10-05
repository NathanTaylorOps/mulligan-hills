class_name MHConsentScreen
extends MHScreen
## First-launch consent (DEC-057): ONE screen, ONE tap (Continue), analytics default OFF. The toggle is optional
## and never needs touching. Intent: consent_done {opt_in}. Shown before the editor on first launch only.

var _toggle: MHTapButton


func screen_id() -> String:
	return MHScreenIds.CONSENT


func title_key() -> String:
	return "consent.title"


func _build() -> void:
	var bg: ColorRect = MHUIKit.color_rect(MHTheme.BG)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card: PanelContainer = MHUIKit.panel(&"ModalPanel")
	card.custom_minimum_size = Vector2(minf(720.0, maxf(320.0, ctx.viewport_units.x - 64.0)), 0.0)
	center.add_child(card)
	var box: VBoxContainer = MHUIKit.vbox(14)
	card.add_child(box)
	box.add_child(MHUIKit.label(MHStrings.t("consent.title"), &"H1Label"))
	box.add_child(MHUIKit.label(MHStrings.t("consent.body"), &"Label"))
	_toggle = MHUIKit.button(ctx, "", &"ChipButton")
	_toggle.pressed.connect(_on_toggle)
	box.add_child(_toggle)
	box.add_child(MHUIKit.label(MHStrings.t("consent.note"), &"MutedLabel"))
	var go: MHTapButton = MHUIKit.button(ctx, MHStrings.t("consent.continue"), &"PrimaryButton")
	go.pressed.connect(_on_continue)
	box.add_child(go)


func refresh() -> void:
	if _toggle == null:
		return
	var on: bool = ctx.settings.analytics_opt_in
	_toggle.text = MHStrings.t("consent.toggle_on" if on else "consent.toggle_off")
	_toggle.theme_type_variation = &"SelectedButton" if on else &"ChipButton"


func _on_toggle() -> void:
	ctx.settings.set_analytics_opt_in(not ctx.settings.analytics_opt_in)
	refresh()


func _on_continue() -> void:
	ctx.settings.set_consent_shown(true)
	send(&"consent_done", {"opt_in": ctx.settings.analytics_opt_in})
