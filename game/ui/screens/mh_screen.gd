class_name MHScreen
extends Control
## Base class of every screen. A screen is built once in code by _build(), reads game data only through
## `view` (MHGameStateView), and reports what the player wants with the `intent` signal; the shell or the game
## decides what to do. refresh() re-reads the view. Default refresh() rebuilds the whole page, which is fine for
## everything except the HUD (it updates labels in place so a tap in progress is never on a freed button).

signal intent(id: StringName, args: Dictionary)
signal back_requested()

var view: MHGameStateView
var ctx: MHUIContext
var args: Dictionary = {}
## Overlay screens (HUD, editor toolbar) are transparent and let touches through to the game view.
var is_overlay: bool = false

var _page: VBoxContainer = null
var _body: VBoxContainer = null


## Id used by the shell registry (see MHScreenIds).
func screen_id() -> String:
	return ""


func title_key() -> String:
	return ""


func setup(p_view: MHGameStateView, p_ctx: MHUIContext, p_args: Dictionary = {}) -> void:
	view = p_view
	ctx = p_ctx
	args = p_args
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Screens are children of the shell's MarginContainer. Anchors alone are not
	# sufficient when a Control is managed by a Container; explicitly opt into
	# filling the allocated rect so overlay spacers receive the real viewport area.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE if is_overlay else Control.MOUSE_FILTER_STOP
	_build()
	refresh()


## Override: create the node tree once.
func _build() -> void:
	_build_page()


## Override: re-read the view. Default rebuilds the body.
func refresh() -> void:
	if _body != null:
		MHUIKit.clear(_body)
		_fill()


## Override for page screens: add content to _body.
func _fill() -> void:
	pass


func request_back() -> void:
	back_requested.emit()


func send(id: StringName, payload: Dictionary = {}) -> void:
	intent.emit(id, payload)


## Page scaffold: opaque background, header row (Back + title), scrolling body. Returns nothing; sets _body.
func _build_page(show_back: bool = true) -> void:
	var bg: ColorRect = MHUIKit.color_rect(MHTheme.BG)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MHTheme.GUTTER + 4)
	add_child(margin)
	_page = MHUIKit.vbox(12)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_page)
	var head: HBoxContainer = MHUIKit.hbox(12)
	_page.add_child(head)
	var back: MHTapButton = null
	if show_back:
		back = MHUIKit.button(ctx, MHStrings.t("ui.common.back"), &"ChipButton", 120.0)
		back.pressed.connect(request_back)
	var title: Label = MHUIKit.label(MHStrings.t(title_key()), &"H1Label", false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if ctx.left_handed() and back != null:
		head.add_child(title)
		head.add_child(back)
	else:
		if back != null:
			head.add_child(back)
		head.add_child(title)
	var scroll: MHScrollBox = MHScrollBox.new()
	_page.add_child(scroll)
	_body = MHUIKit.vbox(12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)


## Overlay screens: the rectangle (global UI units) left free between their top and bottom controls, where a game
## scene may place its own controls without overlapping them. Empty Rect2 when not laid out or not an overlay.
func free_rect() -> Rect2:
	return Rect2()


## Region id (StringName) -> Button for overlay screens. The shell turns these into MHInputRouter regions
## (so a tap on a button never paints) and calls pressed on the button when the router reports the tap.
func region_buttons() -> Dictionary:
	return {}


## Region id -> Callable() -> Rect2, for MHInputRouter.register_ui_region.
func button_rect_getters() -> Dictionary:
	var out: Dictionary = {}
	var rb: Dictionary = region_buttons()
	for k: Variant in rb.keys():
		out[k] = rect_of(rb[k])
	return out


## Rect getter that survives the button being freed (MHInputRouter keeps getters forever).
static func rect_of(c: Control) -> Callable:
	return func() -> Rect2:
		if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
			return Rect2()
		return c.get_global_rect()
