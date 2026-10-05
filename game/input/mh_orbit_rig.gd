class_name MHOrbitRig
extends RefCounted
## Pure orbit camera state (no nodes). Named MHOrbitRig because MHCameraRig
## already exists in game/render/.
## Convention: yaw 0 = camera on +Z looking north (-Z). Positive twist
## (clockwise on screen) increases yaw, so the world turns with the fingers.

var config: MHCameraConfig
var target: Vector3 = Vector3.ZERO
var yaw: float = 0.0
var pitch_deg: float = 50.0
var distance: float = 40.0

var _snapping: bool = false
var _gesture_active: bool = false
var _pan_velocity: Vector3 = Vector3.ZERO
var _yaw_velocity: float = 0.0


func _init(cfg: MHCameraConfig = null) -> void:
	config = cfg if cfg != null else MHCameraConfig.new()
	reset()


func reset() -> void:
	distance = clampf(config.start_distance, config.min_distance, config.max_distance)
	yaw = MHGestureMath.wrap_angle(deg_to_rad(config.start_yaw_deg))
	pitch_deg = clampf(config.start_pitch_deg, config.tilt_min_deg, config.tilt_max_deg)
	target = Vector3.ZERO
	_snapping = false
	_gesture_active = false
	_pan_velocity = Vector3.ZERO
	_yaw_velocity = 0.0
	_update_pitch_from_zoom()


func is_snapping() -> bool:
	return _snapping


func apply_touch_gesture(pan_px: Vector2, zoom_ratio: float, twist_rad: float, dt: float) -> void:
	apply_twist(twist_rad, dt)
	apply_zoom_ratio(zoom_ratio)
	apply_pan_pixels(pan_px, dt)


func apply_twist(rad: float, dt: float) -> void:
	_begin_gesture()
	var d: float = rad * config.twist_sign * config.rotate_sensitivity * config.sensitivity
	yaw = MHGestureMath.wrap_angle(yaw + d)
	if dt > 0.0:
		_yaw_velocity = lerpf(_yaw_velocity, d / dt, 0.5)


## ratio > 1 means fingers moved apart (zoom in, distance shrinks).
func apply_zoom_ratio(ratio: float) -> void:
	if ratio <= 0.0:
		return
	var exponent: float = config.zoom_sensitivity * config.sensitivity
	distance = clampf(distance / pow(ratio, exponent), config.min_distance, config.max_distance)
	_update_pitch_from_zoom()


func apply_pan_pixels(px: Vector2, dt: float) -> void:
	_begin_gesture()
	var k: float = config.pan_per_pixel * config.pan_sensitivity * config.sensitivity
	var world: Vector3 = MHGestureMath.pan_world_delta(px, yaw, distance, k)
	target += world
	_clamp_target()
	if dt > 0.0:
		_pan_velocity = _pan_velocity.lerp(world / dt, 0.5)


func tilt_by_deg(delta_deg: float) -> void:
	if config.tilt_follows_zoom:
		return
	pitch_deg = clampf(pitch_deg + delta_deg, config.tilt_min_deg, config.tilt_max_deg)


func end_gesture() -> void:
	_gesture_active = false


## Starts an eased return to yaw 0 (north up) by the shortest way round.
func snap_north() -> void:
	_snapping = true
	_yaw_velocity = 0.0


## Advances easing and inertia. Returns true if the camera changed.
func update(dt: float) -> bool:
	if dt <= 0.0:
		return false
	var changed: bool = false
	if _snapping:
		var diff: float = MHGestureMath.wrap_angle(-yaw)
		if absf(diff) < 0.0005:
			yaw = 0.0
			_snapping = false
		else:
			yaw = MHGestureMath.wrap_angle(yaw + diff * MHGestureMath.ease_factor(config.snap_ease_rate, dt))
		changed = true
	elif config.inertia_enabled and not _gesture_active:
		var decay: float = exp(-config.inertia_damping * dt)
		if _pan_velocity.length() > config.inertia_min_speed:
			target += _pan_velocity * dt
			_clamp_target()
			_pan_velocity *= decay
			changed = true
		else:
			_pan_velocity = Vector3.ZERO
		if absf(_yaw_velocity) > config.inertia_min_speed:
			yaw = MHGestureMath.wrap_angle(yaw + _yaw_velocity * dt)
			_yaw_velocity *= decay
			changed = true
		else:
			_yaw_velocity = 0.0
	return changed


func get_camera_position() -> Vector3:
	return target + MHGestureMath.orbit_offset(yaw, deg_to_rad(pitch_deg), distance)


func _begin_gesture() -> void:
	if not _gesture_active:
		_gesture_active = true
		_snapping = false
		_pan_velocity = Vector3.ZERO
		_yaw_velocity = 0.0


func _update_pitch_from_zoom() -> void:
	if not config.tilt_follows_zoom:
		return
	var t: float = MHGestureMath.zoom01(distance, config.min_distance, config.max_distance)
	pitch_deg = clampf(lerpf(config.tilt_close_deg, config.tilt_far_deg, t), config.tilt_min_deg, config.tilt_max_deg)


func _clamp_target() -> void:
	if not config.use_pan_bounds:
		return
	var b: Rect2 = config.pan_bounds
	target.x = clampf(target.x, b.position.x, b.end.x)
	target.z = clampf(target.z, b.position.y, b.end.y)



## Presentation focus cancels residual pan/spin/snap so the next frame cannot undo recentering.
func focus_target(point: Vector3, new_distance: float = -1.0) -> void:
	target = point
	_clamp_target()
	_pan_velocity = Vector3.ZERO
	_yaw_velocity = 0.0
	_gesture_active = false
	_snapping = false
	if new_distance > 0.0:
		distance = clampf(new_distance, config.min_distance, config.max_distance)
		_update_pitch_from_zoom()
