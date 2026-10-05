class_name MHGolferPoses
extends RefCounted
## Pose data and sampling for the procedural golfer (MHGolferMeshes). Pure data and maths, no engine state.
##
## A pose is a Dictionary: joint name -> Vector3 Euler degrees (see MHGolferMeshes for the joint list and
## sign conventions), plus "hips_pos" (Vector3 metres) and "club_scale" (float). Missing joints are zero
## (rest). A clip is a list of keyframes [time_seconds, pose]; `sample` blends the two keyframes around a
## time. Euler angles are lerped per joint (keyframes are close enough that this is fine; a slerp would
## only matter for a very large single step).
##
## STATUS: NOT YET RUN in Godot. The keyframes were solved offline with a small Python mirror of
## MHGolferMeshes.joint_transforms (hand on the grip, club head on the ball at address and impact,
## feet on the ground) and checked on stick-figure plots. They are first guesses and need a visual
## tuning pass in the gallery. tests/art/test_golfer_poses.gd re-checks grip gap, foot height and
## impact position through the real GDScript forward kinematics.
##
## Where the club head centre is at address and impact, in the golfer frame (the ball sits just in front).

const CLIP_IDLE: String = "idle"
const CLIP_WALK: String = "walk"
const CLIP_SWING: String = "swing"
const CLIP_PUTT: String = "putt"
const CLIPS: Array = ["idle", "walk", "swing", "putt"]

const LENGTH_IDLE: float = 3.0
const LENGTH_WALK: float = 1.0
const LENGTH_SWING: float = 2.4
const LENGTH_PUTT: float = 1.6

## Seconds into the clip at which the club meets the ball.
const IMPACT_SWING: float = 1.25
const IMPACT_PUTT: float = 0.95

## Club head centre at address and impact (golfer frame), within about 0.1 m.
const BALL_SWING: Vector3 = Vector3(0.0, 0.04, 0.96)
const BALL_PUTT: Vector3 = Vector3(0.0, 0.06, 0.70)

const SWING_KEYS: Array = [
	[0.00, {"spine": Vector3(34.0, 0.0, 0.0), "arm_l_upper": Vector3(-15.8, -2.8, -25.4), "arm_l_lower": Vector3(-25.9, 0.0, 0.0), "arm_r_upper": Vector3(-33.8, 0.0, 17.5), "club": Vector3(-33.4, 26.3, -16.3), "leg_l_upper": Vector3(-27.0, 0.0, 6.0), "leg_l_lower": Vector3(37.0, 0.0, 0.0), "leg_r_upper": Vector3(-27.0, 0.0, -6.0), "leg_r_lower": Vector3(37.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.059, 0.000)}],
	[0.50, {"hips": Vector3(0.0, -15.0, 0.0), "spine": Vector3(34.0, -30.0, 0.0), "head": Vector3(0.0, 18.0, 0.0), "arm_l_upper": Vector3(-52.3, 0.0, -20.1), "arm_r_upper": Vector3(-59.0, 0.0, 17.6), "club": Vector3(-73.9, 13.0, -38.2), "leg_l_upper": Vector3(-27.0, 15.0, 6.0), "leg_l_lower": Vector3(37.0, 0.0, 0.0), "leg_r_upper": Vector3(-27.0, 15.0, -6.0), "leg_r_lower": Vector3(37.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.053, 0.000)}],
	[1.00, {"hips": Vector3(0.0, -40.0, 0.0), "spine": Vector3(32.0, -55.0, 0.0), "head": Vector3(0.0, 33.0, 0.0), "arm_l_upper": Vector3(-170.0, -0.8, -22.3), "arm_l_lower": Vector3(-13.2, 0.0, 0.0), "arm_r_upper": Vector3(-170.0, 2.7, 23.0), "arm_r_lower": Vector3(-29.7, 0.0, 0.0), "club": Vector3(-95.5, 27.2, 24.3), "leg_l_upper": Vector3(-24.0, 40.0, 2.0), "leg_l_lower": Vector3(38.0, 0.0, 0.0), "leg_r_upper": Vector3(-24.0, 40.0, -6.0), "leg_r_lower": Vector3(34.0, 0.0, 0.0), "hips_pos": Vector3(-0.040, -0.070, 0.000)}],
	[1.15, {"hips": Vector3(0.0, 10.0, 0.0), "spine": Vector3(34.0, -20.0, 0.0), "head": Vector3(0.0, 12.0, 0.0), "arm_l_upper": Vector3(-44.6, -3.7, -27.8), "arm_l_lower": Vector3(-31.1, 0.0, 0.0), "arm_r_upper": Vector3(-61.6, 0.0, 18.4), "club": Vector3(-21.6, 73.4, 9.2), "leg_l_upper": Vector3(-24.0, -10.0, 3.0), "leg_l_lower": Vector3(34.0, 0.0, 0.0), "leg_r_upper": Vector3(-26.0, -10.0, -3.0), "leg_r_lower": Vector3(40.0, 0.0, 0.0), "hips_pos": Vector3(0.040, -0.050, 0.000)}],
	[1.25, {"hips": Vector3(0.0, 40.0, 0.0), "spine": Vector3(34.0, -20.0, 0.0), "head": Vector3(0.0, 12.0, 0.0), "arm_l_upper": Vector3(-17.9, -4.1, -24.3), "arm_l_lower": Vector3(-38.7, 0.0, 0.0), "arm_r_upper": Vector3(-39.6, 0.0, 17.5), "club": Vector3(-16.9, 10.5, -30.5), "leg_l_upper": Vector3(-16.0, -40.0, 5.0), "leg_l_lower": Vector3(20.0, 0.0, 0.0), "leg_r_upper": Vector3(-26.0, -40.0, -2.0), "leg_r_lower": Vector3(42.0, 0.0, 0.0), "hips_pos": Vector3(0.060, -0.044, 0.000)}],
	[1.45, {"hips": Vector3(0.0, 65.0, 0.0), "spine": Vector3(30.0, 5.0, 0.0), "arm_l_upper": Vector3(-89.4, 0.0, -22.6), "arm_r_upper": Vector3(-97.1, 0.0, 17.2), "club": Vector3(-99.8, -36.9, -31.7), "leg_l_upper": Vector3(-8.0, -65.0, 4.0), "leg_l_lower": Vector3(10.0, 0.0, 0.0), "leg_r_upper": Vector3(-22.0, -65.0, 0.0), "leg_r_lower": Vector3(48.0, 0.0, 0.0), "hips_pos": Vector3(0.080, -0.020, 0.000)}],
	[1.90, {"hips": Vector3(0.0, 85.0, 0.0), "spine": Vector3(14.0, 22.0, -8.0), "arm_l_upper": Vector3(-169.8, 0.0, -21.4), "arm_r_upper": Vector3(-167.2, 0.0, 27.7), "club": Vector3(55.3, 11.8, 76.3), "leg_l_upper": Vector3(-4.0, -85.0, 4.0), "leg_l_lower": Vector3(4.0, 0.0, 0.0), "leg_r_upper": Vector3(-16.0, -85.0, 2.0), "leg_r_lower": Vector3(52.0, 0.0, 0.0), "hips_pos": Vector3(0.080, -0.009, 0.000)}],
	[2.40, {"hips": Vector3(0.0, 85.0, 0.0), "spine": Vector3(14.0, 22.0, -8.0), "arm_l_upper": Vector3(-169.8, 0.0, -21.4), "arm_r_upper": Vector3(-167.2, 0.0, 27.7), "club": Vector3(55.3, 11.8, 76.3), "leg_l_upper": Vector3(-4.0, -85.0, 4.0), "leg_l_lower": Vector3(4.0, 0.0, 0.0), "leg_r_upper": Vector3(-16.0, -85.0, 2.0), "leg_r_lower": Vector3(52.0, 0.0, 0.0), "hips_pos": Vector3(0.080, -0.009, 0.000)}],
]

const PUTT_KEYS: Array = [
	[0.00, {"spine": Vector3(44.0, 0.0, 0.0), "arm_l_upper": Vector3(-32.1, 0.0, -25.9), "arm_l_lower": Vector3(-0.1, 0.0, 0.0), "arm_r_upper": Vector3(-36.3, 0.0, 16.6), "club": Vector3(-22.7, 45.3, -19.1), "leg_l_upper": Vector3(-18.0, 0.0, 3.0), "leg_l_lower": Vector3(28.0, 0.0, 0.0), "leg_r_upper": Vector3(-18.0, 0.0, -3.0), "leg_r_lower": Vector3(28.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.029, 0.000), "club_scale": 0.82}],
	[0.60, {"spine": Vector3(44.0, -10.0, 0.0), "arm_l_upper": Vector3(-33.5, 0.0, -25.9), "arm_r_upper": Vector3(-37.6, 0.0, 16.3), "club": Vector3(-20.4, 43.9, -22.2), "leg_l_upper": Vector3(-18.0, 0.0, 3.0), "leg_l_lower": Vector3(28.0, 0.0, 0.0), "leg_r_upper": Vector3(-18.0, 0.0, -3.0), "leg_r_lower": Vector3(28.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.029, 0.000), "club_scale": 0.82}],
	[0.95, {"spine": Vector3(44.0, 2.0, 0.0), "arm_l_upper": Vector3(-31.9, 0.0, -25.8), "arm_l_lower": Vector3(-0.4, 0.0, 0.0), "arm_r_upper": Vector3(-36.3, 0.0, 16.4), "club": Vector3(-23.5, 39.8, -20.7), "leg_l_upper": Vector3(-18.0, 0.0, 3.0), "leg_l_lower": Vector3(28.0, 0.0, 0.0), "leg_r_upper": Vector3(-18.0, 0.0, -3.0), "leg_r_lower": Vector3(28.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.029, 0.000), "club_scale": 0.82}],
	[1.20, {"spine": Vector3(44.0, 10.0, 0.0), "arm_l_upper": Vector3(-33.3, 0.0, -26.1), "arm_r_upper": Vector3(-37.4, 0.0, 16.8), "club": Vector3(-31.1, 23.6, -10.7), "leg_l_upper": Vector3(-18.0, 0.0, 3.0), "leg_l_lower": Vector3(28.0, 0.0, 0.0), "leg_r_upper": Vector3(-18.0, 0.0, -3.0), "leg_r_lower": Vector3(28.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.029, 0.000), "club_scale": 0.82}],
	[1.60, {"spine": Vector3(44.0, 10.0, 0.0), "arm_l_upper": Vector3(-33.3, 0.0, -26.1), "arm_r_upper": Vector3(-37.4, 0.0, 16.8), "club": Vector3(-31.1, 23.6, -10.7), "leg_l_upper": Vector3(-18.0, 0.0, 3.0), "leg_l_lower": Vector3(28.0, 0.0, 0.0), "leg_r_upper": Vector3(-18.0, 0.0, -3.0), "leg_r_lower": Vector3(28.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.029, 0.000), "club_scale": 0.82}],
]

const IDLE_KEYS: Array = [
	[0.00, {"spine": Vector3(3.0, 0.0, 0.0), "arm_l_upper": Vector3(-4.0, 0.0, -6.0), "arm_l_lower": Vector3(-8.0, 0.0, 0.0), "arm_r_upper": Vector3(-24.1, 0.0, 0.4), "club": Vector3(7.8, -27.9, 16.3), "leg_l_upper": Vector3(-3.0, 0.0, 3.0), "leg_l_lower": Vector3(4.0, 0.0, 0.0), "leg_r_upper": Vector3(-3.0, 0.0, -3.0), "leg_r_lower": Vector3(4.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.002, 0.000)}],
	[1.50, {"spine": Vector3(4.5, 0.0, 0.0), "arm_l_upper": Vector3(-4.0, 0.0, -6.0), "arm_l_lower": Vector3(-8.0, 0.0, 0.0), "arm_r_upper": Vector3(-24.1, 0.0, 0.4), "club": Vector3(7.8, -27.9, 16.3), "leg_l_upper": Vector3(-3.0, 0.0, 3.0), "leg_l_lower": Vector3(4.0, 0.0, 0.0), "leg_r_upper": Vector3(-3.0, 0.0, -3.0), "leg_r_lower": Vector3(4.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.002, 0.000)}],
	[3.00, {"spine": Vector3(3.0, 0.0, 0.0), "arm_l_upper": Vector3(-4.0, 0.0, -6.0), "arm_l_lower": Vector3(-8.0, 0.0, 0.0), "arm_r_upper": Vector3(-24.1, 0.0, 0.4), "club": Vector3(7.8, -27.9, 16.3), "leg_l_upper": Vector3(-3.0, 0.0, 3.0), "leg_l_lower": Vector3(4.0, 0.0, 0.0), "leg_r_upper": Vector3(-3.0, 0.0, -3.0), "leg_r_lower": Vector3(4.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.002, 0.000)}],
]

const WALK_KEYS: Array = [
	[0.00, {"spine": Vector3(5.0, -6.0, 0.0), "arm_l_upper": Vector3(18.0, 0.0, -5.0), "arm_l_lower": Vector3(-12.0, 0.0, 0.0), "arm_r_upper": Vector3(-10.0, 0.0, 5.0), "arm_r_lower": Vector3(-18.0, 0.0, 0.0), "club": Vector3(-30.0, 0.0, 0.0), "leg_l_upper": Vector3(-28.0, 0.0, 2.0), "leg_l_lower": Vector3(6.0, 0.0, 0.0), "leg_r_upper": Vector3(18.0, 0.0, -2.0), "leg_r_lower": Vector3(28.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.084, 0.000)}],
	[0.25, {"spine": Vector3(5.0, 0.0, 0.0), "arm_l_upper": Vector3(4.0, 0.0, -5.0), "arm_l_lower": Vector3(-12.0, 0.0, 0.0), "arm_r_upper": Vector3(-2.0, 0.0, 5.0), "arm_r_lower": Vector3(-18.0, 0.0, 0.0), "club": Vector3(-30.0, 0.0, 0.0), "leg_l_upper": Vector3(-2.0, 0.0, 2.0), "leg_l_lower": Vector3(6.0, 0.0, 0.0), "leg_r_upper": Vector3(-14.0, 0.0, -2.0), "leg_r_lower": Vector3(58.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.002, 0.000)}],
	[0.50, {"spine": Vector3(5.0, 6.0, 0.0), "arm_l_upper": Vector3(-18.0, 0.0, -5.0), "arm_l_lower": Vector3(-12.0, 0.0, 0.0), "arm_r_upper": Vector3(10.0, 0.0, 5.0), "arm_r_lower": Vector3(-18.0, 0.0, 0.0), "club": Vector3(-30.0, 0.0, 0.0), "leg_l_upper": Vector3(18.0, 0.0, 2.0), "leg_l_lower": Vector3(28.0, 0.0, 0.0), "leg_r_upper": Vector3(-28.0, 0.0, -2.0), "leg_r_lower": Vector3(6.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.084, 0.000)}],
	[0.75, {"spine": Vector3(5.0, 0.0, 0.0), "arm_l_upper": Vector3(-4.0, 0.0, -5.0), "arm_l_lower": Vector3(-12.0, 0.0, 0.0), "arm_r_upper": Vector3(2.0, 0.0, 5.0), "arm_r_lower": Vector3(-18.0, 0.0, 0.0), "club": Vector3(-30.0, 0.0, 0.0), "leg_l_upper": Vector3(-14.0, 0.0, 2.0), "leg_l_lower": Vector3(58.0, 0.0, 0.0), "leg_r_upper": Vector3(-2.0, 0.0, -2.0), "leg_r_lower": Vector3(6.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.002, 0.000)}],
	[1.00, {"spine": Vector3(5.0, -6.0, 0.0), "arm_l_upper": Vector3(18.0, 0.0, -5.0), "arm_l_lower": Vector3(-12.0, 0.0, 0.0), "arm_r_upper": Vector3(-10.0, 0.0, 5.0), "arm_r_lower": Vector3(-18.0, 0.0, 0.0), "club": Vector3(-30.0, 0.0, 0.0), "leg_l_upper": Vector3(-28.0, 0.0, 2.0), "leg_l_lower": Vector3(6.0, 0.0, 0.0), "leg_r_upper": Vector3(18.0, 0.0, -2.0), "leg_r_lower": Vector3(28.0, 0.0, 0.0), "hips_pos": Vector3(0.000, -0.084, 0.000)}],
]


static func keys_for(clip: String) -> Array:
	match clip:
		"idle":
			return IDLE_KEYS
		"walk":
			return WALK_KEYS
		"swing":
			return SWING_KEYS
		"putt":
			return PUTT_KEYS
	return []


static func length_of(clip: String) -> float:
	match clip:
		"idle":
			return LENGTH_IDLE
		"walk":
			return LENGTH_WALK
		"swing":
			return LENGTH_SWING
		"putt":
			return LENGTH_PUTT
	return 0.0


## True for clips that repeat (idle, walk).
static func is_looping(clip: String) -> bool:
	return clip == "idle" or clip == "walk"


## Impact time in seconds, or -1.0 when the clip does not hit a ball.
static func impact_time(clip: String) -> float:
	if clip == "swing":
		return IMPACT_SWING
	if clip == "putt":
		return IMPACT_PUTT
	return -1.0


## Pose at time `t`. Looping clips wrap, one-shot clips clamp to the first and last key.
static func sample(clip: String, t: float) -> Dictionary:
	var keys: Array = keys_for(clip)
	if keys.is_empty():
		return {}
	var length: float = length_of(clip)
	var tt: float = t
	if is_looping(clip):
		tt = fposmod(t, length)
	else:
		tt = clampf(t, 0.0, length)
	var n: int = keys.size()
	var first: Array = keys[0] as Array
	if tt <= float(first[0]):
		return (first[1] as Dictionary).duplicate()
	for i in range(n - 1):
		var k0: Array = keys[i] as Array
		var k1: Array = keys[i + 1] as Array
		var t0: float = float(k0[0])
		var t1: float = float(k1[0])
		if tt <= t1:
			var w: float = 0.0
			if t1 > t0:
				w = (tt - t0) / (t1 - t0)
			if clip != "walk":
				w = w * w * (3.0 - 2.0 * w)
			return blend(k0[1] as Dictionary, k1[1] as Dictionary, w)
	var last: Array = keys[n - 1] as Array
	return (last[1] as Dictionary).duplicate()


## Per-joint linear blend of two poses (w = 0 gives a, w = 1 gives b). Missing joints count as zero.
static func blend(a: Dictionary, b: Dictionary, w: float) -> Dictionary:
	var out: Dictionary = {}
	for j: Variant in MHGolferMeshes.JOINTS:
		var joint: String = str(j)
		if a.has(joint) or b.has(joint):
			var ea: Vector3 = a.get(joint, Vector3.ZERO) as Vector3
			var eb: Vector3 = b.get(joint, Vector3.ZERO) as Vector3
			out[joint] = ea.lerp(eb, w)
	var pa: Vector3 = a.get("hips_pos", Vector3.ZERO) as Vector3
	var pb: Vector3 = b.get("hips_pos", Vector3.ZERO) as Vector3
	out["hips_pos"] = pa.lerp(pb, w)
	var sa: float = float(a.get("club_scale", 1.0))
	var sb: float = float(b.get("club_scale", 1.0))
	out["club_scale"] = lerpf(sa, sb, w)
	return out


## Number of keyframes in a clip.
static func key_count(clip: String) -> int:
	return keys_for(clip).size()
