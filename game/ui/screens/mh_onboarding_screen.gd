class_name MHOnboardingScreen
extends MHScreen
## Coach overlay for the first minute (DEC-032, DEC-057). Sits on top of the editor, never blocks painting
## (everything except the Skip button ignores touches), and follows MHFirstLaunchFlow: COACH_STROKE asks for a
## drag on the ground, COACH_RATING points at the rating button. The shell calls set_step(). Intent: skip_tutorial.

var _step: int = MHFirstLaunchFlow.Step.COACH_STROKE
var _text: Label
var _skip: MHTapButton


func _init() -> void:
	is_overlay = true


func screen_id() -> String:
	return MHScreenIds.ONBOARDING


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MHTheme.GUTTER)
	add_child(margin)
	var root: VBoxContainer = MHUIKit.vbox(8)
	margin.add_child(root)
	root.add_child(MHUIKit.spacer())
	var row: HBoxContainer = MHUIKit.hbox(10)
	root.add_child(row)
	var chip: PanelContainer = MHUIKit.panel(&"CoachPanel")
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text = MHUIKit.label("", &"Label")
	chip.add_child(_text)
	_skip = MHUIKit.button(ctx, MHStrings.t("onboarding.skip"), &"ChipButton", 120.0)
	_skip.pressed.connect(send.bind(&"skip_tutorial", {}))
	if ctx.left_handed():
		row.add_child(_skip)
		row.add_child(chip)
	else:
		row.add_child(chip)
		row.add_child(_skip)
	# keep clear of the editor toolbar at the bottom
	root.add_child(_pad(ctx.touch_min() * 2.0 + 24.0))


func _pad(h: float) -> Control:
	var c: Control = Control.new()
	c.custom_minimum_size = Vector2(0.0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func set_step(p_step: int) -> void:
	_step = p_step
	refresh()


func refresh() -> void:
	if _text == null:
		return
	if _step == MHFirstLaunchFlow.Step.COACH_RATING:
		_text.text = MHStrings.t("onboarding.rating")
	else:
		_text.text = MHStrings.t("onboarding.stroke")


func region_buttons() -> Dictionary:
	return {&"onboarding_skip": _skip}
