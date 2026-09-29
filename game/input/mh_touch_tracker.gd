class_name MHTouchTracker
extends RefCounted
## Tracks fingers by index from InputEventScreenTouch and InputEventScreenDrag.
## Assumes ProjectSettings emulate_mouse_from_touch is OFF.
## Palm/edge rejection: edge_margin_px, plus reject_filter hook
## Callable(pos: Vector2, index: int, active_count: int) -> bool (true = accept).
## Godot touch events carry no contact size or pressure, so real palm
## detection is limited to position rules supplied through the hook.

enum Result { IGNORED, DOWN, MOVED, UP }

var screen_size: Vector2 = Vector2.ZERO
var edge_margin_px: float = 0.0
var reject_filter: Callable = Callable()

## Set by handle_event for DOWN, MOVED and UP results.
var last_index: int = -1
var last_canceled: bool = false

var _pos: Dictionary = {}
var _start_pos: Dictionary = {}
var _down_ms: Dictionary = {}
var _rejected: Dictionary = {}


func handle_event(event: InputEvent, now_ms: int) -> int:
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		if t.pressed:
			return _down(t.index, t.position, now_ms)
		return _up(t.index, t.canceled)
	if event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		return _drag(d.index, d.position)
	return Result.IGNORED


func count() -> int:
	return _pos.size()


## Active finger indices, ascending.
func ids() -> Array[int]:
	var keys: Array = _pos.keys()
	keys.sort()
	var out: Array[int] = []
	for k in keys:
		out.append(int(k))
	return out


func position(index: int) -> Vector2:
	return _pos.get(index, Vector2.ZERO)


func start_position(index: int) -> Vector2:
	return _start_pos.get(index, Vector2.ZERO)


func down_ms(index: int) -> int:
	return _down_ms.get(index, 0)


func clear() -> void:
	_pos.clear()
	_start_pos.clear()
	_down_ms.clear()
	_rejected.clear()
	last_index = -1
	last_canceled = false


func _is_rejected(pos: Vector2, index: int) -> bool:
	if edge_margin_px > 0.0 and screen_size.x > 0.0 and screen_size.y > 0.0:
		var m: float = edge_margin_px
		if pos.x < m or pos.y < m or pos.x > screen_size.x - m or pos.y > screen_size.y - m:
			return true
	if reject_filter.is_valid():
		var accept: bool = reject_filter.call(pos, index, _pos.size())
		if not accept:
			return true
	return false


func _down(index: int, pos: Vector2, now_ms: int) -> int:
	if _pos.has(index) or _rejected.has(index):
		return Result.IGNORED
	if _is_rejected(pos, index):
		_rejected[index] = true
		return Result.IGNORED
	_pos[index] = pos
	_start_pos[index] = pos
	_down_ms[index] = now_ms
	last_index = index
	last_canceled = false
	return Result.DOWN


func _drag(index: int, pos: Vector2) -> int:
	if not _pos.has(index):
		return Result.IGNORED
	_pos[index] = pos
	last_index = index
	return Result.MOVED


func _up(index: int, canceled: bool) -> int:
	if _rejected.has(index):
		_rejected.erase(index)
		return Result.IGNORED
	if not _pos.has(index):
		return Result.IGNORED
	_pos.erase(index)
	_start_pos.erase(index)
	_down_ms.erase(index)
	last_index = index
	last_canceled = canceled
	return Result.UP
