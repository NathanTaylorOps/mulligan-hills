class_name MHUIShell
extends Control
## Root of the UI (docs/spec/interfaces/ui_shell.md). Owns the screen stack, the open modal, toasts, the theme,
## layout and safe-area handling, the touch bridge, and the first-launch flow. Screens hold no game rules: they
## read a MHGameStateView and report intents, which the shell forwards through its own `intent` signal
## (the game connects to it). The shell handles only navigation itself.
##
## Wiring order matters for touch: add the shell AFTER (below in the tree) the game's MHInputRouter so the shell's
## _input runs first, or register region_rects() with the router and forward ui_tapped to trigger_region().
## Usage:
##   var shell: MHUIShell = MHUIShell.new()
##   add_child(shell)
##   shell.setup(view, settings)       # view: MHGameStateView, settings: MHUISettings (loaded by the caller)
##   shell.start_first_launch(Time.get_ticks_msec())   # or shell.show_root(MHScreenIds.HUD)

signal screen_changed(screen_id: String)
signal intent(id: StringName, args: Dictionary)
signal mode_changed(mode: int)
signal first_launch_finished()

enum Mode { EDIT = 0, WATCH = 1, HEATMAP = 2, MENU = 3 }

const TOAST_SECONDS: float = 2.6

var view: MHGameStateView
var ctx: MHUIContext = MHUIContext.new()
var settings: MHUISettings = MHUISettings.new()
## Write settings to user:// on every change. The gallery turns this off.
var persist_settings: bool = true
var flow: MHFirstLaunchFlow = MHFirstLaunchFlow.new()

var _stack: MHScreenStack = MHScreenStack.new()
var _nodes: Array = []
var _args: Array = []
var _modal: MHScreen = null
var _modal_id: String = ""
var _mode: int = Mode.EDIT
var _backdrop: ColorRect
var _host: MarginContainer
var _overlay_layer: Control
var _modal_layer: Control
var _toast_layer: VBoxContainer
var _bridge: MHTouchBridge
var _coach: MHOnboardingScreen = null
var _ready_done: bool = false


func setup(p_view: MHGameStateView, p_settings: MHUISettings = null) -> void:
	view = p_view
	if p_settings != null:
		settings = p_settings
	ctx.settings = settings
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# MHUIShell sits directly under a CanvasLayer. Keep an explicit viewport-sized
	# rect as well as full anchors so every nested Container receives a real area
	# immediately, including on desktop windows and before the first resize signal.
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = MHUIKit.color_rect(MHTheme.BG)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.visible = false
	add_child(_backdrop)
	_host = MarginContainer.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	_overlay_layer = _make_layer()
	_modal_layer = _make_layer()
	_toast_layer = VBoxContainer.new()
	_toast_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_layer.alignment = BoxContainer.ALIGNMENT_END
	_toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_layer)
	_bridge = MHTouchBridge.new()
	add_child(_bridge)
	_ready_done = true
	_apply_theme()
	_recompute()
	view.changed.connect(_on_view_changed)
	settings.changed.connect(_on_settings_changed)
	get_viewport().size_changed.connect(_on_resized)


func _make_layer() -> Control:
	var c: Control = Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


# ------------------------------------------------------------------ queries (interface)

func layout_class() -> int:
	return ctx.layout_kind


func text_scale_pct() -> int:
	return ctx.text_scale()


func left_handed() -> bool:
	return settings.left_handed


func colorblind_palette() -> int:
	return settings.colorblind


func current_screen_id() -> String:
	return _stack.top()


func stack_depth() -> int:
	return _stack.depth()


func modal_id() -> String:
	return _modal_id


func mode() -> int:
	return _mode


## Separate camera and brush modes (spec): the shell only forwards the change, nothing else reacts here.
func set_mode(new_mode: int) -> void:
	var m: int = clampi(new_mode, Mode.EDIT, Mode.MENU)
	if m == _mode:
		return
	_mode = m
	mode_changed.emit(m)


## True while the top screen is a transparent overlay (HUD, editor toolbar) and no modal is open: the 3D view is
## visible and a game scene may show its own controls on top.
func overlay_active() -> bool:
	if _modal != null:
		return false
	var top: MHScreen = _top_node()
	return top != null and top.is_overlay and top.is_visible_in_tree()


## Rectangle left free by the top overlay screen (between its top controls and bottom bar), global UI units.
## Empty Rect2 when no overlay is active or it has not been laid out yet.
func overlay_free_rect() -> Rect2:
	if not overlay_active():
		return Rect2()
	return _top_node().free_rect()


# ------------------------------------------------------------------ navigation

## Clears the stack and shows one screen as the root.
func show_root(id: String, args: Dictionary = {}) -> void:
	_close_modal_internal()
	for n: Variant in _nodes:
		_free_node(n)
	_nodes = []
	_args = []
	_stack.reset("")
	var node: MHScreen = _make_screen(id, args)
	if node == null:
		return
	_stack.reset(id)
	_nodes.append(node)
	_args.append(args)
	_after_change()


func push_screen(id: String, args: Dictionary = {}) -> void:
	if MHScreenIds.is_modal(id):
		show_modal(id, args)
		return
	if not MHScreenIds.is_known(id):
		push_warning("MHUIShell: unknown screen id " + id)
		return
	if not _stack.push(id):
		return
	var node: MHScreen = _make_screen(id, args)
	if node == null:
		_stack.pop()
		return
	_nodes.append(node)
	_args.append(args)
	_after_change()
	if id == MHScreenIds.RATING:
		_on_rating_opened()


func pop_screen() -> void:
	if _modal != null:
		close_modal()
		return
	if not _stack.can_pop():
		return
	_stack.pop()
	var node: Variant = _nodes.pop_back()
	_args.pop_back()
	_free_node(node)
	_after_change()


func show_modal(id: String, args: Dictionary = {}) -> void:
	if not MHScreenIds.is_modal(id):
		push_warning("MHUIShell: not a modal id " + id)
		return
	if _modal_id == id:
		return
	_close_modal_internal()
	var node: MHScreen = MHScreenFactory.create(id)
	if node == null:
		return
	node.setup(view, ctx, args)
	node.intent.connect(_on_screen_intent)
	node.back_requested.connect(close_modal)
	_modal_layer.add_child(node)
	_modal = node
	_modal_id = id
	_bridge.scope = node


func close_modal() -> void:
	_close_modal_internal()


func _close_modal_internal() -> void:
	if _modal != null:
		_modal.queue_free()
	_modal = null
	_modal_id = ""
	if _bridge != null:
		_bridge.scope = null


func _make_screen(id: String, args: Dictionary) -> MHScreen:
	var node: MHScreen = MHScreenFactory.create(id)
	if node == null:
		push_warning("MHUIShell: cannot create screen " + id)
		return null
	node.setup(view, ctx, args)
	node.intent.connect(_on_screen_intent)
	node.back_requested.connect(pop_screen)
	_host.add_child(node)
	return node


func _free_node(n: Variant) -> void:
	if n != null and is_instance_valid(n):
		var node: Node = n
		var c: Control = node as Control
		if c != null:
			c.hide()
		node.queue_free()


func _after_change() -> void:
	for i: int in range(_nodes.size()):
		var node: MHScreen = _nodes[i]
		node.visible = i == _nodes.size() - 1
	var top: MHScreen = _top_node()
	if top != null:
		top.refresh()
	_backdrop.visible = top != null and not top.is_overlay
	screen_changed.emit(_stack.top())


func _top_node() -> MHScreen:
	if _nodes.is_empty():
		return null
	return _nodes[_nodes.size() - 1] as MHScreen


# ------------------------------------------------------------------ toasts

func toast(key: String, params: Dictionary = {}) -> void:
	var p: PanelContainer = MHUIKit.panel(&"ToastPanel")
	var l: Label = MHUIKit.label(MHStrings.t(key, params), &"Label")
	l.add_theme_color_override("font_color", MHTheme.BG)
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_layer.add_child(p)
	var timer: SceneTreeTimer = get_tree().create_timer(TOAST_SECONDS)
	timer.timeout.connect(_drop_toast.bind(p))


func _drop_toast(p: Node) -> void:
	if is_instance_valid(p):
		p.queue_free()


func toast_count() -> int:
	return _toast_layer.get_child_count()


# ------------------------------------------------------------------ intents, first launch

func _on_screen_intent(id: StringName, a: Dictionary) -> void:
	if id == &"nav":
		push_screen(str(a.get("screen", "")), a.get("args", {}))
	elif id == &"show_modal":
		show_modal(str(a.get("modal", "")), a)
	elif id == &"consent_done":
		_on_consent_done()
	elif id == &"skip_tutorial":
		_finish_flow()
	elif id == &"replay_tutorial":
		replay_tutorial()
	elif id == &"recovery_loan" or id == &"recovery_tokens" or id == &"recovery_later" or id == &"delete_account":
		close_modal()
	intent.emit(id, a)


func start_first_launch(now_ms: int) -> void:
	flow.begin(now_ms, settings.consent_shown)
	if flow.step == MHFirstLaunchFlow.Step.CONSENT:
		show_root(MHScreenIds.CONSENT)
	else:
		_enter_editor()


func _on_consent_done() -> void:
	flow.on_consent_continue()
	_persist()
	_enter_editor()


func _enter_editor() -> void:
	show_root(MHScreenIds.HUD)
	push_screen(MHScreenIds.EDITOR)
	if not settings.tutorial_done and not flow.is_done():
		_show_coach()


func _show_coach() -> void:
	if _coach != null and is_instance_valid(_coach):
		return
	var c: MHOnboardingScreen = MHOnboardingScreen.new()
	c.setup(view, ctx, {})
	c.intent.connect(_on_screen_intent)
	_overlay_layer.add_child(c)
	c.set_step(flow.step)
	_coach = c


## Shows the coach overlay at a given MHFirstLaunchFlow step (the gallery uses this).
func show_coach(p_step: int = MHFirstLaunchFlow.Step.COACH_STROKE) -> void:
	flow.step = p_step
	_show_coach()


## Call when the first paint stroke starts (MHGestureStateMachine.stroke_started).
func notify_first_stroke(now_ms: int) -> void:
	flow.on_first_stroke(now_ms)
	if _coach != null and is_instance_valid(_coach):
		_coach.set_step(flow.step)


func _on_rating_opened() -> void:
	flow.on_rating_opened()
	if flow.is_done():
		_finish_flow()


func _finish_flow() -> void:
	flow.skip()
	if _coach != null and is_instance_valid(_coach):
		_coach.queue_free()
	_coach = null
	settings.set_tutorial_done(true)
	first_launch_finished.emit()


## Restarts the tutorial coach on top of the current screens (Settings, "Replay tutorial").
func replay_tutorial() -> void:
	settings.set_tutorial_done(false)
	flow.begin(Time.get_ticks_msec(), true)
	_show_coach()


# ------------------------------------------------------------------ router glue

## All overlay button rects: region id -> Callable() -> Rect2 (for MHInputRouter.register_ui_region).
func region_rects() -> Dictionary:
	var out: Dictionary = {}
	for n: Variant in _nodes:
		var s: MHScreen = n
		if s.is_overlay and s.is_visible_in_tree():
			out.merge(s.button_rect_getters(), true)
	if _coach != null and is_instance_valid(_coach):
		out.merge(_coach.button_rect_getters(), true)
	return out


## Forward MHInputRouter.ui_tapped here: presses the button behind that region if it is visible and enabled.
func trigger_region(region: StringName) -> void:
	var screens: Array = []
	for n: Variant in _nodes:
		screens.append(n)
	if _coach != null and is_instance_valid(_coach):
		screens.append(_coach)
	for sn: Variant in screens:
		var s: MHScreen = sn
		var rb: Dictionary = s.region_buttons()
		if rb.has(region):
			var b: Button = rb[region]
			if is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled:
				b.pressed.emit()
			return


# ------------------------------------------------------------------ reacting to changes

func _on_view_changed() -> void:
	var top: MHScreen = _top_node()
	if top != null:
		top.call_deferred("refresh")
	if _modal != null:
		_modal.call_deferred("refresh")
	var offer: Dictionary = view.recovery_offer()
	if MHRecoveryModel.is_active(offer) and _modal_id == "":
		show_modal(MHScreenIds.BANKRUPTCY)
	elif not MHRecoveryModel.is_active(offer) and _modal_id == MHScreenIds.BANKRUPTCY:
		close_modal()


func _on_settings_changed(key: String) -> void:
	_persist()
	if key == "text_scale_pct" or key == "left_handed" or key == "colorblind":
		_apply_theme()
		_rebuild_all()
	elif key == "units":
		_rebuild_all()


func _persist() -> void:
	if persist_settings:
		settings.save_to()


func _apply_theme() -> void:
	var fonts: Dictionary = MHTheme.load_fonts()
	var body: Font = fonts["body"] as Font
	var heading: Font = fonts["heading"] as Font
	theme = MHTheme.build(settings.text_scale_pct, body, heading)


func _rebuild_all() -> void:
	var ids: PackedStringArray = _stack.ids()
	var saved_args: Array = _args.duplicate()
	var modal: String = _modal_id
	var coach_on: bool = _coach != null and is_instance_valid(_coach)
	for n: Variant in _nodes:
		_free_node(n)
	_nodes = []
	_args = []
	for i: int in range(ids.size()):
		var a: Dictionary = saved_args[i]
		var node: MHScreen = _make_screen(ids[i], a)
		if node != null:
			_nodes.append(node)
			_args.append(a)
	if coach_on:
		_coach.queue_free()
		_coach = null
		_show_coach()
	if modal != "":
		var m: String = modal
		_close_modal_internal()
		show_modal(m)
	_after_change()


func _on_resized() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_recompute()


func _recompute() -> void:
	if not _ready_done:
		return
	var window_px: Vector2 = Vector2(DisplayServer.window_get_size())
	var units: Vector2 = get_viewport_rect().size
	var dpi: float = float(DisplayServer.screen_get_dpi())
	var safe: Rect2 = Rect2(DisplayServer.get_display_safe_area())
	var old_kind: int = ctx.layout_kind
	ctx.recompute(window_px, units, dpi, safe)
	var ins: Vector4 = ctx.safe_insets
	_host.add_theme_constant_override("margin_left", int(ins.x))
	_host.add_theme_constant_override("margin_top", int(ins.y))
	_host.add_theme_constant_override("margin_right", int(ins.z))
	_host.add_theme_constant_override("margin_bottom", int(ins.w))
	if old_kind != ctx.layout_kind and not _nodes.is_empty():
		_rebuild_all()

