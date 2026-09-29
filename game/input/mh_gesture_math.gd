class_name MHGestureMath
extends RefCounted
## Pure gesture and orbit math. No scene, no nodes, no input events.
## Screen coordinates: x right, y DOWN. Vector2.angle() therefore grows
## clockwise on screen.

class TwoFingerDelta extends RefCounted:
	var pan: Vector2 = Vector2.ZERO
	var scale_ratio: float = 1.0
	var twist: float = 0.0


## Wraps an angle into (-PI, PI].
static func wrap_angle(angle: float) -> float:
	var wrapped: float = fposmod(angle + PI, TAU) - PI
	if wrapped <= -PI:
		wrapped = PI
	return wrapped


## Signed shortest rotation from prev_vec to cur_vec, wrapped at PI.
## Positive = clockwise on screen. Returns 0 for degenerate vectors.
static func angle_delta(prev_vec: Vector2, cur_vec: Vector2) -> float:
	if prev_vec.length_squared() < 0.000001 or cur_vec.length_squared() < 0.000001:
		return 0.0
	return wrap_angle(cur_vec.angle() - prev_vec.angle())


## cur/prev finger distance. 1.0 if prev distance is degenerate.
static func pinch_ratio(prev_dist: float, cur_dist: float) -> float:
	if prev_dist < 0.001:
		return 1.0
	return cur_dist / prev_dist


static func two_finger_delta(prev_a: Vector2, prev_b: Vector2, cur_a: Vector2, cur_b: Vector2) -> TwoFingerDelta:
	var d: TwoFingerDelta = TwoFingerDelta.new()
	d.pan = (cur_a + cur_b) * 0.5 - (prev_a + prev_b) * 0.5
	d.scale_ratio = pinch_ratio(prev_a.distance_to(prev_b), cur_a.distance_to(cur_b))
	d.twist = angle_delta(prev_b - prev_a, cur_b - cur_a)
	return d


## Camera offset from target. yaw 0 puts the camera on +Z looking north (-Z).
static func orbit_offset(yaw: float, pitch_rad: float, distance: float) -> Vector3:
	var cp: float = cos(pitch_rad)
	return Vector3(sin(yaw) * cp, sin(pitch_rad), cos(yaw) * cp) * distance


static func ground_forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


static func ground_right(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


## Screen drag (pixels) to world target movement so the ground follows the
## fingers. Scales with distance so pan speed feels constant at any zoom.
static func pan_world_delta(px: Vector2, yaw: float, distance: float, world_per_px_per_unit: float) -> Vector3:
	var s: float = distance * world_per_px_per_unit
	return -ground_right(yaw) * px.x * s + ground_forward(yaw) * px.y * s


static func clamp_distance(distance: float, min_d: float, max_d: float) -> float:
	return clampf(distance, min_d, max_d)


## 0 at min distance, 1 at max distance.
static func zoom01(distance: float, min_d: float, max_d: float) -> float:
	if max_d - min_d < 0.0001:
		return 0.0
	return clampf((distance - min_d) / (max_d - min_d), 0.0, 1.0)


## Frame-rate independent exponential easing factor.
static func ease_factor(rate: float, dt: float) -> float:
	return 1.0 - exp(-maxf(rate, 0.0) * maxf(dt, 0.0))
