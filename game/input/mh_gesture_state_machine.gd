class_name MHGestureStateMachine
extends RefCounted
## Decides whether touches are painting or camera control.
##
## States: IDLE, PENDING (one finger, undecided), PAINTING (one finger),
## CAMERA (two fingers), IGNORED (three or more fingers, or long-press abort).
## Rules:
##  - A second finger while PENDING switches to CAMERA and no stroke ever starts.
##  - A second finger while PAINTING emits stroke_cancelled (rollback) and
##    switches to CAMERA.
##  - CAMERA and IGNORED persist until ALL fingers lift. A lifted second finger
##    never resumes painting.
##  - Three or more fingers cancel any open stroke and everything is ignored
##    until all fingers lift.
## Time is passed in (now_ms) so the class is testable without a scene.
## Call tick(now_ms) every frame so the commit window can expire with no events.

signal stroke_started(screen_pos: Vector2)
signal stroke_moved(screen_pos: Vector2)
signal stroke_ended()
signal stroke_cancelled()
## Incremental two-finger deltas since the last emission.
## twist_rad is positive for clockwise rotation on screen.
signal camera_gesture(pan_px: Vector2, zoom_ratio: float, twist_rad: float)
signal camera_gesture_ended()
signal state_changed(new_state: int)

enum State { IDLE, PENDING, PAINTING, CAMERA, IGNORED }

var config: MHGestureConfig
var tracker: MHTouchTracker
var state: int = State.IDLE

var _paint_index: int = -1
var _pending_start_pos: Vector2 = Vector2.ZERO
var _pending_start_ms: int = 0
var _snap_id_a: int = -1
var _snap_id_b: int = -1
var _snap_a: Vector2 = Vector2.ZERO
var _snap_b: Vector2 = Vector2.ZERO
var _camera_moving: bool = false
var _desktop_stroke: bool = false


func _init(cfg: MHGestureConfig = null) -> void:
	config = cfg if cfg != null else MHGestureConfig.new()
	tracker = MHTouchTracker.new()
	tracker.edge_margin_px = config.edge_margin_px


static func state_name(s: int) -> String:
	match s:
		State.IDLE:
			return "idle"
		State.PENDING:
			return "pending"
		State.PAINTING:
			return "painting"
		State.CAMERA:
			return "camera"
		State.IGNORED:
			return "ignored"
	return "?"


func handle_event(event: InputEvent, now_ms: int) -> void:
	tick(now_ms)
	var result: int = tracker.handle_event(event, now_ms)
	if result == MHTouchTracker.Result.DOWN:
		_on_down(now_ms)
	elif result == MHTouchTracker.Result.MOVED:
		_on_moved(tracker.last_index)
	elif result == MHTouchTracker.Result.UP:
		_on_up(tracker.last_index, tracker.last_canceled)


## Call every frame. Commits a pending stroke when its time window expires.
func tick(now_ms: int) -> void:
	if state != State.PENDING:
		return
	var held: int = now_ms - _pending_start_ms
	var need: int = config.long_press_ms if config.long_press_ms > 0 else config.commit_window_ms
	if held >= need:
		_commit_stroke()


## Call on app pause or focus loss. Rolls back any open stroke.
func cancel_all() -> void:
	if state == State.PAINTING:
		stroke_cancelled.emit()
	_end_camera_gesture()
	_desktop_stroke = false
	tracker.clear()
	_paint_index = -1
	_set_state(State.IDLE)


# Desktop dev mapping (left-drag paint). Not touch, so it bypasses the tracker.
func desktop_stroke_begin(pos: Vector2) -> void:
	if state != State.IDLE:
		return
	_desktop_stroke = true
	_set_state(State.PAINTING)
	stroke_started.emit(pos)


func desktop_stroke_move(pos: Vector2) -> void:
	if _desktop_stroke and state == State.PAINTING:
		stroke_moved.emit(pos)


func desktop_stroke_end() -> void:
	if not _desktop_stroke:
		return
	_desktop_stroke = false
	_set_state(State.IDLE)
	stroke_ended.emit()


func _set_state(s: int) -> void:
	if s == state:
		return
	state = s
	state_changed.emit(s)


func _on_down(now_ms: int) -> void:
	var count: int = tracker.count()
	if count >= 3:
		_enter_ignored()
		return
	if count == 2:
		if state == State.IGNORED:
			return
		if state == State.PAINTING:
			stroke_cancelled.emit()
		_paint_index = -1
		_set_state(State.CAMERA)
		_reset_camera_snapshot()
		return
	# count == 1
	if state == State.IDLE:
		_paint_index = tracker.ids()[0]
		_pending_start_pos = tracker.position(_paint_index)
		_pending_start_ms = now_ms
		_set_state(State.PENDING)


func _enter_ignored() -> void:
	if state == State.PAINTING:
		stroke_cancelled.emit()
	_end_camera_gesture()
	_paint_index = -1
	_set_state(State.IGNORED)


func _on_moved(index: int) -> void:
	if state == State.PENDING and index == _paint_index:
		var moved: float = tracker.position(index).distance_to(_pending_start_pos)
		if moved > config.dead_zone_px:
			if config.long_press_ms > 0:
				_paint_index = -1
				_set_state(State.IGNORED)
			else:
				_commit_stroke()
	elif state == State.PAINTING and index == _paint_index:
		stroke_moved.emit(tracker.position(index))
	elif state == State.CAMERA and tracker.count() == 2:
		_emit_camera()


func _on_up(index: int, canceled: bool) -> void:
	var count: int = tracker.count()
	if state == State.PENDING and index == _paint_index:
		_paint_index = -1
		_set_state(State.IDLE)
		if config.tap_dab_enabled and config.long_press_ms <= 0 and not canceled:
			stroke_started.emit(_pending_start_pos)
			stroke_ended.emit()
	elif state == State.PAINTING and index == _paint_index and not _desktop_stroke:
		_paint_index = -1
		_set_state(State.IDLE)
		if canceled:
			stroke_cancelled.emit()
		else:
			stroke_ended.emit()
	elif state == State.CAMERA and count < 2:
		_end_camera_gesture()
		if count == 0:
			_set_state(State.IDLE)
	elif count == 0 and not _desktop_stroke:
		_set_state(State.IDLE)


func _commit_stroke() -> void:
	_set_state(State.PAINTING)
	stroke_started.emit(_pending_start_pos)
	var cur: Vector2 = tracker.position(_paint_index)
	if cur != _pending_start_pos:
		stroke_moved.emit(cur)


func _reset_camera_snapshot() -> void:
	var ids: Array[int] = tracker.ids()
	if ids.size() < 2:
		return
	_snap_id_a = ids[0]
	_snap_id_b = ids[1]
	_snap_a = tracker.position(_snap_id_a)
	_snap_b = tracker.position(_snap_id_b)


func _emit_camera() -> void:
	var ids: Array[int] = tracker.ids()
	if ids[0] != _snap_id_a or ids[1] != _snap_id_b:
		_reset_camera_snapshot()
		return
	var ca: Vector2 = tracker.position(ids[0])
	var cb: Vector2 = tracker.position(ids[1])
	var d: MHGestureMath.TwoFingerDelta = MHGestureMath.two_finger_delta(_snap_a, _snap_b, ca, cb)
	_snap_a = ca
	_snap_b = cb
	if d.pan == Vector2.ZERO and d.twist == 0.0 and is_equal_approx(d.scale_ratio, 1.0):
		return
	_camera_moving = true
	camera_gesture.emit(d.pan, d.scale_ratio, d.twist)


func _end_camera_gesture() -> void:
	if _camera_moving:
		_camera_moving = false
		camera_gesture_ended.emit()
