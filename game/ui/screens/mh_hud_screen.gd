class_name MHHudScreen
extends MHScreen
## Home / Course HUD: cash, day and time, speed control (token-locked speeds), course rating, tokens,
## and the bottom navigation. Transparent overlay over the 3D course. Updates labels in place on refresh().
## Intents: set_speed {speed}, toggle_pause, nav {screen}.

var _cash_label: Label
var _net_label: Label
var _time_label: Label
var _day_bar: ProgressBar
var _score_label: Label
var _score_band: Label
var _token_button: MHTapButton
var _demo_chip: PanelContainer
var _speed_buttons: Dictionary = {}
var _speed_note: Label
var _pause_button: MHTapButton
var _nav_buttons: Dictionary = {}


func _init() -> void:
	is_overlay = true


func screen_id() -> String:
	return MHScreenIds.HUD


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MHTheme.GUTTER)
	add_child(margin)
	var root: VBoxContainer = MHUIKit.vbox(8)
	margin.add_child(root)

	var top: HFlowContainer = MHUIKit.flow(8)
	root.add_child(top)
	top.add_child(_make_cash_chip())
	top.add_child(_make_time_chip())
	top.add_child(_make_score_chip())
	_token_button = MHUIKit.button(ctx, "", &"ChipButton", 120.0)
	_token_button.pressed.connect(send.bind(&"nav", {"screen": MHScreenIds.TOKENS}))
	top.add_child(_token_button)
	_demo_chip = MHUIKit.panel(&"HudChip")
	_demo_chip.add_child(MHUIKit.label(MHStrings.t("hud.demo"), &"HudLabel", false))
	top.add_child(_demo_chip)

	var speed_row: HFlowContainer = MHUIKit.flow(8)
	root.add_child(speed_row)
	for s: Variant in MHSpeedControl.SPEEDS:
		var sp: int = int(s)
		var b: MHTapButton = MHUIKit.button(ctx, MHFormat.speed_label(sp), &"ChipButton", 112.0)
		b.tag = sp
		b.pressed.connect(_on_speed_pressed.bind(sp))
		speed_row.add_child(b)
		_speed_buttons[sp] = b
	_pause_button = MHUIKit.button(ctx, "", &"ChipButton", 120.0)
	_pause_button.pressed.connect(send.bind(&"toggle_pause", {}))
	speed_row.add_child(_pause_button)
	var note_chip: PanelContainer = MHUIKit.panel(&"HudChip")
	_speed_note = MHUIKit.label("", &"SmallLabel", false)
	note_chip.add_child(_speed_note)
	speed_row.add_child(note_chip)

	root.add_child(MHUIKit.spacer())

	var nav: HBoxContainer = MHUIKit.hbox(8)
	root.add_child(nav)
	var ids: Array = [MHScreenIds.BUILD, MHScreenIds.LAND, MHScreenIds.EDITOR, MHScreenIds.RATING, MHScreenIds.SETTINGS]
	var keys: Array = ["hud.nav.build", "hud.nav.land", "hud.nav.editor", "hud.nav.rating", "hud.nav.menu"]
	for i: int in range(ids.size()):
		var variant: StringName = &"PrimaryButton" if str(ids[i]) == MHScreenIds.EDITOR else &"GreenButton"
		var nb: MHTapButton = MHUIKit.button(ctx, MHStrings.t(str(keys[i])), variant, 120.0)
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nb.pressed.connect(send.bind(&"nav", {"screen": str(ids[i])}))
		_nav_buttons[str(ids[i])] = nb
	if ctx.left_handed():
		for i: int in range(ids.size() - 1, -1, -1):
			nav.add_child(_nav_buttons[str(ids[i])])
	else:
		for i: int in range(ids.size()):
			nav.add_child(_nav_buttons[str(ids[i])])


func _make_cash_chip() -> Control:
	var p: PanelContainer = MHUIKit.panel(&"HudChip")
	var v: VBoxContainer = MHUIKit.vbox(0)
	p.add_child(v)
	_cash_label = MHUIKit.label("", &"HudLabel", false)
	_net_label = MHUIKit.label("", &"SmallLabel", false)
	v.add_child(_cash_label)
	v.add_child(_net_label)
	return p


func _make_time_chip() -> Control:
	var p: PanelContainer = MHUIKit.panel(&"HudChip")
	var v: VBoxContainer = MHUIKit.vbox(2)
	p.add_child(v)
	_time_label = MHUIKit.label("", &"HudLabel", false)
	_day_bar = MHUIKit.progress(0, 100)
	v.add_child(_time_label)
	v.add_child(_day_bar)
	return p


func _make_score_chip() -> Control:
	var p: PanelContainer = MHUIKit.panel(&"HudChip")
	var v: VBoxContainer = MHUIKit.vbox(0)
	p.add_child(v)
	_score_label = MHUIKit.label("", &"HudLabel", false)
	_score_band = MHUIKit.label("", &"SmallLabel", false)
	v.add_child(_score_label)
	v.add_child(_score_band)
	return p


func _on_speed_pressed(speed: int) -> void:
	if MHSpeedControl.is_locked(speed, view.tokens_total()):
		send(&"nav", {"screen": MHScreenIds.TOKENS})
		return
	send(&"set_speed", {"speed": speed})


func refresh() -> void:
	if _cash_label == null:
		return
	_cash_label.text = MHStrings.t("hud.cash", {"amount": MHFormat.money_compact(view.cash())})
	var net: int = view.income_per_day() - view.upkeep_per_day()
	var net_text: String = MHFormat.money_compact(absi(net))
	_net_label.text = MHStrings.t("hud.net_per_day" if net >= 0 else "hud.net_loss_per_day", {"amount": net_text})
	_net_label.theme_type_variation = &"GoodLabel" if net >= 0 else &"AccentLabel"
	_time_label.text = MHStrings.t("hud.day_time", {"day": MHFormat.day_number(view.day()), "time": MHFormat.game_clock(view.minute_of_day(), false)})
	_day_bar.value = float(MHFormat.day_progress_percent(view.minute_of_day()))
	_score_label.text = MHStrings.t("hud.score", {"score": MHFormat.score_x10(view.course_score_x10())})
	_score_band.text = MHStrings.t(MHScoreModel.band_key(view.course_score_x10()))
	var tokens: int = view.tokens_total()
	_token_button.text = MHStrings.t("hud.tokens", {"count": tokens})
	_demo_chip.visible = view.is_demo()
	var opts: Array = MHSpeedControl.options(tokens, view.speed())
	for o: Variant in opts:
		var row: Dictionary = o
		var b: MHTapButton = _speed_buttons[int(row["speed"])]
		if bool(row["selected"]):
			b.theme_type_variation = &"SelectedButton"
		elif bool(row["locked"]):
			b.theme_type_variation = &"GhostButton"
		else:
			b.theme_type_variation = &"ChipButton"
		b.text = MHFormat.speed_label(int(row["speed"])) + ((" " + MHStrings.t("hud.speed.lock_suffix")) if bool(row["locked"]) else "")
	var eff: int = MHSpeedControl.effective_speed(view.speed(), tokens)
	if eff > 1:
		_speed_note.text = MHStrings.t("hud.speed.cost", {"rate": MHSpeedControl.tokens_per_minute(eff), "minutes": MHSpeedControl.minutes_left(tokens, eff)})
	elif tokens < 1:
		_speed_note.text = MHStrings.t("hud.speed.need_tokens")
	else:
		_speed_note.text = MHStrings.t("hud.speed.free")
	_pause_button.text = MHStrings.t("hud.resume" if view.is_paused() else "hud.pause")


func region_buttons() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in _nav_buttons.keys():
		out[StringName("hud_nav_" + str(k))] = _nav_buttons[k]
	for k2: Variant in _speed_buttons.keys():
		out[StringName("hud_speed_" + str(k2))] = _speed_buttons[k2]
	out[&"hud_pause"] = _pause_button
	out[&"hud_tokens"] = _token_button
	return out
