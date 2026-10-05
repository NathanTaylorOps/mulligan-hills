class_name MHUIGallery
extends Control
## Gallery: every UI screen, one tap each, running on MHFakeGameStateView sample data. A dev tool only (listed
## in MHLauncher.SCENES). Top bar: one button per screen id; second row: sample controls (demo, tokens, cash,
## recovery, text size, left-handed). Settings made here are NOT saved.

var _view: MHFakeGameStateView
var _shell: MHUIShell
var _settings: MHUISettings
var _title: Label
var _current: String = ""


func _ready() -> void:
	_view = MHFakeGameStateView.new()
	_settings = MHUISettings.new()
	_settings.units = MHUISettings.UNITS_IMPERIAL
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	_shell = MHUIShell.new()
	_shell.persist_settings = false
	var stage: Control = Control.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.clip_contents = true

	var bar: PanelContainer = MHUIKit.panel(&"CardPanel")
	root.add_child(bar)
	var bar_box: VBoxContainer = MHUIKit.vbox(6)
	bar.add_child(bar_box)
	root.add_child(stage)
	stage.add_child(_shell)
	_shell.setup(_view, _settings)
	_shell.intent.connect(_on_intent)
	theme = MHTheme.build(_settings.text_scale_pct)
	_settings.changed.connect(_on_settings_changed)

	_title = MHUIKit.label(MHStrings.t("gallery.title"), &"H2Label", false)
	bar_box.add_child(_title)
	var screens: HFlowContainer = MHUIKit.flow(6)
	bar_box.add_child(screens)
	for id: Variant in MHScreenIds.ALL:
		var sid: String = str(id)
		var b: MHTapButton = MHUIKit.button(_shell.ctx, MHStrings.t("gallery.screen." + sid), &"ChipButton", 96.0)
		b.pressed.connect(show_screen.bind(sid))
		screens.add_child(b)
	var tools: HFlowContainer = MHUIKit.flow(6)
	bar_box.add_child(tools)
	_tool(tools, "gallery.demo", _toggle_demo)
	_tool(tools, "gallery.tokens_none", _view.sample_set_tokens.bind(0, 0))
	_tool(tools, "gallery.tokens_some", _view.sample_set_tokens.bind(7, 3))
	_tool(tools, "gallery.cash_low", _view.sample_set_cash.bind(900))
	_tool(tools, "gallery.cash_rich", _view.sample_set_cash.bind(250000))
	_tool(tools, "gallery.recovery_on", _view.sample_set_recovery.bind(true))
	_tool(tools, "gallery.recovery_off", _view.sample_set_recovery.bind(false))
	_tool(tools, "gallery.tournament_ready", _view.sample_set_tournament_ready.bind(true))
	_tool(tools, "gallery.text_down", _on_text.bind(-1))
	_tool(tools, "gallery.text_up", _on_text.bind(1))
	_tool(tools, "gallery.left_hand", _toggle_left)
	_tool(tools, "gallery.back", _on_back)
	show_screen(MHScreenIds.HUD)


func _tool(parent: Control, key: String, handler: Callable) -> void:
	var b: MHTapButton = MHUIKit.button(_shell.ctx, MHStrings.t(key), &"GhostButton", 96.0)
	b.pressed.connect(handler)
	parent.add_child(b)


## The gallery is the "game" for the two progression intents: they run against the real modules on sample data.
func _on_intent(id: StringName, args: Dictionary) -> void:
	var r: Dictionary = _view.sample_handle_intent(id, args)
	if bool(r.get("handled", false)) and str(r.get("message_key", "")) != "":
		_shell.toast(str(r["message_key"]), r.get("message_params", {}) as Dictionary)


func show_screen(id: String) -> void:
	_current = id
	_shell.close_modal()
	if MHScreenIds.is_modal(id):
		_shell.show_root(MHScreenIds.HUD)
		_shell.show_modal(id)
	elif id == MHScreenIds.ONBOARDING:
		_shell.show_root(MHScreenIds.HUD)
		_shell.push_screen(MHScreenIds.EDITOR)
		_shell.show_coach()
	else:
		_shell.show_root(id)
	_title.text = MHStrings.t("gallery.showing", {"screen_key": "gallery.screen." + id})


func _toggle_demo() -> void:
	_view.sample_set_demo(not _view.is_demo())


func _toggle_left() -> void:
	_settings.set_left_handed(not _settings.left_handed)


func _on_text(direction: int) -> void:
	_settings.set_text_scale(MHTheme.step_text_scale(_settings.text_scale_pct, direction))


func _on_settings_changed(_key: String) -> void:
	theme = MHTheme.build(_settings.text_scale_pct)


func _on_back() -> void:
	if ResourceLoader.exists(MHLauncher.LAUNCHER_PATH):
		get_tree().change_scene_to_file(MHLauncher.LAUNCHER_PATH)
