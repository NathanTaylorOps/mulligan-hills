class_name MHIsoRig
extends RefCounted
## SimGolf-style isometric camera maths (DEC-085). Pure: no nodes, no engine frames, fully testable.
##
## Fixed pitch (the classic isometric 35.264 degrees), four rotation views at 45, 135, 225 and 315 degrees of yaw,
## five zoom levels (orthographic vertical extent in metres), a target point on the ground and a pan area.
## Yaw and zoom ease toward their goals in update(); everything else changes at once.
## NOT YET RUN in Godot.

const PITCH_DEG: float = 35.264
const VIEW_COUNT: int = 4
const BASE_YAW_DEG: float = 45.0
## Orthographic vertical extent in metres, closest first.
const ZOOM_SIZES: Array = [28.0, 44.0, 66.0, 96.0, 136.0]
const DEFAULT_ZOOM: int = 2
## Camera distance from the target along the view direction. Orthographic, so only clipping depends on it.
const EYE_DISTANCE_M: float = 400.0
## Easing speed (per second). About 0.25 s to settle.
const EASE_RATE: float = 14.0

var target: Vector3 = Vector3.ZERO
var bounds: Rect2 = Rect2(0.0, 0.0, 128.0, 150.0)
var view: int = 0
var zoom_index: int = DEFAULT_ZOOM
## Eased values actually drawn.
var yaw_deg: float = BASE_YAW_DEG
var size_m: float = float(ZOOM_SIZES[DEFAULT_ZOOM])


static func yaw_for_view(v: int) -> float:
	return BASE_YAW_DEG + 90.0 * float(posmod(v, VIEW_COUNT))


## +1 turns the world a quarter clockwise as seen from above, -1 anticlockwise. Returns the new view.
func rotate_step(direction: int) -> int:
	view = posmod(view + (1 if direction >= 0 else -1), VIEW_COUNT)
	return view


## direction +1 zooms in (smaller extent), -1 zooms out. Clamped. Returns the new zoom index.
func zoom_step(direction: int) -> int:
	zoom_index = clampi(zoom_index - (1 if direction >= 0 else -1), 0, ZOOM_SIZES.size() - 1)
	return zoom_index


func snap_view(v: int) -> void:
	view = posmod(v, VIEW_COUNT)
	yaw_deg = yaw_for_view(view)


func snap_zoom(i: int) -> void:
	zoom_index = clampi(i, 0, ZOOM_SIZES.size() - 1)
	size_m = float(ZOOM_SIZES[zoom_index])


## Unit vector from the target toward the camera, in world space.
func eye_direction() -> Vector3:
	var yaw: float = deg_to_rad(yaw_deg)
	var pitch: float = deg_to_rad(PITCH_DEG)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


func get_camera_position() -> Vector3:
	return target + eye_direction() * EYE_DISTANCE_M


## Ground direction that points toward the top of the screen.
func screen_up_ground() -> Vector3:
	var yaw: float = deg_to_rad(yaw_deg)
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Ground direction that points toward the right of the screen.
func screen_right_ground() -> Vector3:
	var yaw: float = deg_to_rad(yaw_deg)
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## Pan by a finger or mouse drag of `pixels`: the ground follows the finger. `viewport_h` is the screen height in px.
func pan_pixels(pixels: Vector2, viewport_h: float) -> void:
	var per_px: float = size_m / maxf(1.0, viewport_h)
	var ground_up: float = per_px / sin(deg_to_rad(PITCH_DEG)) # a screen row covers more ground than its height
	target -= screen_right_ground() * pixels.x * per_px
	target += screen_up_ground() * pixels.y * ground_up
	clamp_target()


func clamp_target() -> void:
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
	target.y = 0.0


func focus_target(point: Vector3) -> void:
	target = Vector3(point.x, 0.0, point.z)
	clamp_target()


## Eases yaw and size toward their goals. Returns true while anything moved.
func update(delta: float) -> bool:
	var goal_yaw: float = yaw_for_view(view)
	var goal_size: float = float(ZOOM_SIZES[zoom_index])
	var k: float = 1.0 - exp(-EASE_RATE * maxf(0.0, delta))
	var moved: bool = false
	var diff: float = wrapf(goal_yaw - yaw_deg, -180.0, 180.0)
	if absf(diff) > 0.01:
		yaw_deg = yaw_deg + diff * k
		moved = true
	else:
		yaw_deg = goal_yaw
	var sd: float = goal_size - size_m
	if absf(sd) > 0.01:
		size_m += sd * k
		moved = true
	else:
		size_m = goal_size
	return moved


## A point on the view axis, used only to sort golfers by distance for level of detail.
func lod_eye() -> Vector3:
	return target + eye_direction() * size_m * 1.5
