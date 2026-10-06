class_name MHCartDriveInput
extends Control
## Touch-first cart controls. Desktop keys are a test/development fallback.
signal drive_changed(throttle: float, steer: float)
signal exit_requested()
signal respawn_requested()

var throttle: float = 0.0
var steer: float = 0.0
var _left := false
var _right := false
var _forward := false
var _reverse := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_hold_button("◀", Vector2(24, -150), Vector2(92, 92), func(v: bool) -> void: _left = v)
	_add_hold_button("▶", Vector2(126, -150), Vector2(92, 92), func(v: bool) -> void: _right = v)
	_add_hold_button("▲", Vector2(-218, -150), Vector2(92, 92), func(v: bool) -> void: _forward = v)
	_add_hold_button("▼", Vector2(-116, -150), Vector2(92, 92), func(v: bool) -> void: _reverse = v)
	_add_action_button("Exit", Vector2(-218, 24), func() -> void: exit_requested.emit())
	_add_action_button("Respawn", Vector2(-116, 24), func() -> void: respawn_requested.emit())

func _process(_delta: float) -> void:
	var new_throttle: float = float(int(_forward) - int(_reverse))
	var new_steer: float = float(int(_left) - int(_right))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): new_throttle = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): new_throttle = -1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): new_steer = 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): new_steer = -1.0
	if new_throttle != throttle or new_steer != steer:
		throttle = new_throttle
		steer = new_steer
		drive_changed.emit(throttle, steer)

func _add_hold_button(label: String, offset: Vector2, size: Vector2, setter: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = size
	b.position = Vector2(offset.x if offset.x >= 0 else get_viewport_rect().size.x + offset.x,
		get_viewport_rect().size.y + offset.y)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.button_down.connect(func() -> void: setter.call(true))
	b.button_up.connect(func() -> void: setter.call(false))
	add_child(b)

func _add_action_button(label: String, offset: Vector2, action: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(92, 54)
	b.position = Vector2(get_viewport_rect().size.x + offset.x, offset.y)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.pressed.connect(action)
	add_child(b)
