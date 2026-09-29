class_name MHGate0Panel
extends Control
## Shared on-screen panel for the Gate 0 scenes: title, one live line, a big selectable result box,
## a wrapping row of large buttons, and built-in Copy / Up / Down / Back buttons.
##
## Touch: emulate_mouse_from_touch is OFF in project.godot, so Buttons do not receive taps from a finger.
## With own_touch = true this panel hit-tests its buttons on raw InputEventScreenTouch (press and release on
## the same button = tap) and also honours the normal Button.pressed signal for mouse use.
## With own_touch = false (terrain scene) the owner registers get_button_rect_getters() with MHInputRouter
## and forwards its ui_tapped signal to trigger(), so a tap on a button never paints.
##
## Result text is shown in a read-only TextEdit (long-press selects on Android, unverified) and the
## Copy button puts the whole text on the clipboard (DisplayServer.clipboard_set). Every set_result
## also writes user://gate0_<save_name>.txt.

signal action(id: StringName)

const LAUNCHER_PATH: String = "res://ui/mh_launcher.tscn"

var own_touch: bool = true
var save_name: String = "result"
var result_box: TextEdit
var live_label: Label
var title_label: Label
var font_size: int = 26

var _buttons: Dictionary = {}
var _touch_down: Dictionary = {}
var _flow: HFlowContainer
var _spacer: Control
var _root: VBoxContainer


## background_alpha 1.0 = opaque (text scenes). Lower values let a 3D view show through (terrain scene).
## result_min_height 0 = the result box expands to fill; otherwise it is that tall and a spacer fills the rest.
func setup(title: String, p_save_name: String, background_alpha: float = 1.0, result_min_height: float = 0.0) -> void:
	save_name = p_save_name
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.10, background_alpha)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	_root = VBoxContainer.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override("separation", 10)
	margin.add_child(_root)

	title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", font_size + 8)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(title_label)

	live_label = Label.new()
	live_label.add_theme_font_size_override("font_size", font_size)
	live_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(live_label)

	result_box = TextEdit.new()
	result_box.editable = false
	result_box.context_menu_enabled = true
	result_box.virtual_keyboard_enabled = false
	result_box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	result_box.add_theme_font_size_override("font_size", font_size)
	if result_min_height > 0.0:
		result_box.custom_minimum_size = Vector2(0.0, result_min_height)
	else:
		result_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(result_box)

	if result_min_height > 0.0:
		_spacer = Control.new()
		_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_root.add_child(_spacer)

	_flow = HFlowContainer.new()
	_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flow.add_theme_constant_override("h_separation", 10)
	_flow.add_theme_constant_override("v_separation", 10)
	_root.add_child(_flow)

	add_action(&"copy", "Copy")
	add_action(&"up", "Up")
	add_action(&"down", "Down")
	add_action(&"back", "Back")


## Adds a large button. Custom ids are emitted through `action`; copy, up, down and back are handled here.
func add_action(id: StringName, text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150.0, 84.0)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(trigger.bind(id))
	_flow.add_child(b)
	_buttons[id] = b
	return b


func set_button_text(id: StringName, text: String) -> void:
	if _buttons.has(id):
		(_buttons[id] as Button).text = text


func set_button_disabled(id: StringName, disabled: bool) -> void:
	if _buttons.has(id):
		(_buttons[id] as Button).disabled = disabled


func set_live(text: String) -> void:
	live_label.text = text


func set_result(text: String) -> void:
	result_box.text = text
	result_box.scroll_vertical = 0
	_save_text(text)


func append_result(text: String) -> void:
	set_result(result_box.text + text)


func show_result_box(v: bool) -> void:
	result_box.visible = v


## Dictionary id -> Callable() -> Rect2 (global rect), for MHInputRouter.register_ui_region.
func get_button_rect_getters() -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in _buttons.keys():
		out[id] = Callable(_buttons[id], "get_global_rect")
	return out


func trigger(id: StringName) -> void:
	if id == &"copy":
		DisplayServer.clipboard_set(result_box.text)
		set_live("copied %d characters" % result_box.text.length())
	elif id == &"up":
		result_box.scroll_vertical = maxf(0.0, result_box.scroll_vertical - 6.0)
	elif id == &"down":
		result_box.scroll_vertical = result_box.scroll_vertical + 6.0
	elif id == &"back":
		if ResourceLoader.exists(LAUNCHER_PATH):
			get_tree().change_scene_to_file(LAUNCHER_PATH)
		else:
			set_live("launcher scene not in this build")
	else:
		action.emit(id)


func _save_text(text: String) -> void:
	var f: FileAccess = FileAccess.open("user://gate0_%s.txt" % save_name, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


## Pure: which button id (if any) contains `pos`. rects: Dictionary id -> Rect2. Later ids win on overlap.
static func hit_test(rects: Dictionary, pos: Vector2) -> StringName:
	var found: StringName = &""
	for id: Variant in rects.keys():
		var r: Rect2 = rects[id]
		if r.has_point(pos):
			found = StringName(id)
	return found


func _input(event: InputEvent) -> void:
	if not own_touch or not (event is InputEventScreenTouch):
		return
	var t: InputEventScreenTouch = event
	var rects: Dictionary = {}
	for id: Variant in _buttons.keys():
		var b: Button = _buttons[id]
		if b.is_visible_in_tree() and not b.disabled:
			rects[id] = b.get_global_rect()
	if t.pressed:
		var hit: StringName = hit_test(rects, t.position)
		if hit != &"":
			_touch_down[t.index] = hit
	elif _touch_down.has(t.index):
		var started: StringName = _touch_down[t.index]
		_touch_down.erase(t.index)
		if not t.canceled and hit_test(rects, t.position) == started:
			trigger(started)
