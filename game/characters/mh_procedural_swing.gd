class_name MHProceduralSwing
extends RefCounted
## Builds Animation resources in code by keyframing bone rotations. No mocap or imported clips.
##
## STATUS: NOT YET RUN. The pose numbers are first guesses written without seeing the character
## move. They need a visual tuning pass in a Godot scene (see docs/phase0/animation.md).
##
## Conventions (match tools/animation/make_golfer_gltf.py, T-pose rest, all rest rotations identity):
##   Character faces +Z, its LEFT is +X, up is +Y. Right-handed golfer, target line is +X.
##   Pose values are Euler DEGREES (x, y, z) applied by Basis.from_euler with Godot's default order
##   (YXZ, i.e. R = Ry * Rx * Rz: Z first, then X, then Y). UNVERIFIED: default order.
##   Torso: +X bends forward, -Y turns the chest away from the target (backswing), +Y through it.
##   Upper leg: -X lifts the thigh forward. Lower leg: +X bends the knee.
##   Upper arm: Z lowers the arm from the T-pose (left -Z, right +Z), then -X swings it forward.
##   Lower arm: left -Y bends the forearm forward, right +Y.
##   Pose dictionary keys: "Hips" (centre bones by name), "L:UpperArm" (left only),
##   "R:UpperArm" (right only), "S:UpperArm" (left as given, right mirrored: (x, -y, -z)).

const CLIP_IDLE: StringName = &"idle"
const CLIP_ADDRESS: StringName = &"address"
const CLIP_WALK: StringName = &"walk"
const CLIP_PUTT: StringName = &"putt"
const CLIP_SWING_FULL: StringName = &"swing_full"

const LENGTH_IDLE: float = 3.0
const LENGTH_ADDRESS: float = 2.0
const LENGTH_WALK: float = 1.0
const LENGTH_PUTT: float = 1.8
const LENGTH_SWING_FULL: float = 2.6

## Seconds into the clip at which the club meets the ball. The game fires the shot at this time.
const IMPACT_TIME_PUTT: float = 1.05
const IMPACT_TIME_SWING_FULL: float = 1.35


static func mirror_euler(e: Vector3) -> Vector3:
	return Vector3(e.x, -e.y, -e.z)


static func euler_deg_to_quat(e: Vector3) -> Quaternion:
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))
	return b.get_rotation_quaternion()


## Expands S:/L:/R: keys into full bone names (LeftUpperArm ...). Later L:/R: keys override S:.
static func expand_pose(pose: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in pose.keys():
		var pk: String = str(k)
		var e: Vector3 = pose[k]
		if pk.begins_with("S:"):
			var n: String = pk.substr(2)
			out["Left" + n] = e
			out["Right" + n] = mirror_euler(e)
	for k: Variant in pose.keys():
		var pk: String = str(k)
		var e: Vector3 = pose[k]
		if pk.begins_with("L:"):
			out["Left" + pk.substr(2)] = e
		elif pk.begins_with("R:"):
			out["Right" + pk.substr(2)] = e
		elif not pk.begins_with("S:"):
			out[pk] = e
	return out


## Mirrors a whole pose left<->right (used to make the second half of the walk cycle).
static func swap_sides(pose: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in pose.keys():
		var pk: String = str(k)
		var e: Vector3 = pose[k]
		if pk.begins_with("S:"):
			out[pk] = e
		elif pk.begins_with("L:"):
			out["R:" + pk.substr(2)] = mirror_euler(e)
		elif pk.begins_with("R:"):
			out["L:" + pk.substr(2)] = mirror_euler(e)
		else:
			out[pk] = mirror_euler(e)
	return out


static func merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	for k: Variant in over.keys():
		out[k] = over[k]
	return out


static func make_key(t: float, pose: Dictionary, hips_offset: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"t": t, "pose": pose, "hips": hips_offset}


# ---------------------------------------------------------------------------------------------
# Base poses
# ---------------------------------------------------------------------------------------------

static func pose_stand() -> Dictionary:
	return {
		"S:UpperArm": Vector3(-6.0, 0.0, -78.0),
		"S:LowerArm": Vector3(0.0, -12.0, 0.0),
		"S:UpperLeg": Vector3(0.0, 0.0, 3.0),
	}


## Golf address: hips hinged, knees flexed, arms hanging together in front.
static func pose_address() -> Dictionary:
	return {
		"Hips": Vector3(22.0, 0.0, 0.0),
		"Spine": Vector3(6.0, 0.0, 0.0),
		"Chest": Vector3(6.0, 0.0, 0.0),
		"Neck": Vector3(-14.0, 0.0, 0.0),
		"Head": Vector3(-8.0, 0.0, 0.0),
		"S:UpperLeg": Vector3(-47.0, 0.0, 9.0),
		"S:LowerLeg": Vector3(38.0, 0.0, 0.0),
		"S:Foot": Vector3(-13.0, 0.0, 0.0),
		"S:UpperArm": Vector3(-40.0, 0.0, -98.0),
		"S:LowerArm": Vector3(0.0, -10.0, 0.0),
	}


# ---------------------------------------------------------------------------------------------
# Clip data (arrays of key dictionaries)
# ---------------------------------------------------------------------------------------------

static func keys_idle() -> Array:
	var a: Dictionary = pose_stand()
	var b: Dictionary = merged(pose_stand(), {
		"Chest": Vector3(2.0, 0.0, 0.0),
		"UpperChest": Vector3(1.0, 0.0, 0.0),
		"Head": Vector3(-1.5, 0.0, 0.0),
		"Hips": Vector3(0.0, 0.0, 1.0),
	})
	return [make_key(0.0, a), make_key(1.5, b, Vector3(0.0, 0.004, 0.0)), make_key(LENGTH_IDLE, a)]


static func keys_address() -> Array:
	var a: Dictionary = pose_address()
	var b: Dictionary = merged(pose_address(), {"Chest": Vector3(7.0, 0.0, 0.0), "Hips": Vector3(22.0, 0.0, 0.8)})
	return [make_key(0.0, a), make_key(1.0, b), make_key(LENGTH_ADDRESS, a)]


static func keys_walk() -> Array:
	# Pose A: left leg forward (heel strike), right arm forward.
	var a: Dictionary = {
		"Hips": Vector3(0.0, 6.0, 0.0),
		"Chest": Vector3(0.0, -8.0, 0.0),
		"L:UpperLeg": Vector3(-28.0, 0.0, 2.0),
		"L:LowerLeg": Vector3(6.0, 0.0, 0.0),
		"R:UpperLeg": Vector3(18.0, 0.0, -2.0),
		"R:LowerLeg": Vector3(30.0, 0.0, 0.0),
		"L:UpperArm": Vector3(22.0, 0.0, -80.0),
		"R:UpperArm": Vector3(-22.0, 0.0, 80.0),
		"S:LowerArm": Vector3(0.0, -18.0, 0.0),
	}
	# Pose B: passing (left leg planted, right leg swinging through).
	var b: Dictionary = {
		"L:UpperLeg": Vector3(0.0, 0.0, 2.0),
		"L:LowerLeg": Vector3(4.0, 0.0, 0.0),
		"R:UpperLeg": Vector3(-14.0, 0.0, -2.0),
		"R:LowerLeg": Vector3(55.0, 0.0, 0.0),
		"S:UpperArm": Vector3(0.0, 0.0, -80.0),
		"S:LowerArm": Vector3(0.0, -14.0, 0.0),
	}
	var down: Vector3 = Vector3(0.0, -0.025, 0.0)
	var up: Vector3 = Vector3(0.0, 0.015, 0.0)
	return [
		make_key(0.0, a, down),
		make_key(0.25, b, up),
		make_key(0.5, swap_sides(a), down),
		make_key(0.75, swap_sides(b), up),
		make_key(LENGTH_WALK, a, down),
	]


static func keys_putt() -> Array:
	var base: Dictionary = merged(pose_address(), {
		"Hips": Vector3(30.0, 0.0, 0.0),
		"S:UpperLeg": Vector3(-52.0, 0.0, 6.0),
		"S:LowerLeg": Vector3(32.0, 0.0, 0.0),
		"S:Foot": Vector3(-10.0, 0.0, 0.0),
		"Neck": Vector3(-20.0, 0.0, 0.0),
	})
	var back: Dictionary = merged(base, {
		"Chest": Vector3(6.0, -8.0, 0.0),
		"L:UpperArm": Vector3(-40.0, 0.0, -110.0),
		"R:UpperArm": Vector3(-40.0, 0.0, 86.0),
	})
	var through: Dictionary = merged(base, {
		"Chest": Vector3(6.0, 8.0, 0.0),
		"L:UpperArm": Vector3(-40.0, 0.0, -84.0),
		"R:UpperArm": Vector3(-40.0, 0.0, 112.0),
	})
	return [
		make_key(0.0, base),
		make_key(0.7, back),
		make_key(IMPACT_TIME_PUTT, base),
		make_key(1.35, through),
		make_key(LENGTH_PUTT, through),
	]


static func keys_swing_full() -> Array:
	var address: Dictionary = pose_address()
	var takeaway: Dictionary = merged(address, {
		"Hips": Vector3(22.0, -8.0, 0.0),
		"Chest": Vector3(6.0, -22.0, 0.0),
		"L:UpperArm": Vector3(-55.0, 0.0, -98.0),
		"R:UpperArm": Vector3(-55.0, 0.0, 98.0),
	})
	var top: Dictionary = merged(address, {
		"Hips": Vector3(22.0, -38.0, 0.0),
		"Spine": Vector3(6.0, -12.0, 0.0),
		"Chest": Vector3(6.0, -22.0, 0.0),
		"UpperChest": Vector3(0.0, -18.0, 0.0),
		"Neck": Vector3(-14.0, 30.0, 0.0),
		"Head": Vector3(-8.0, 20.0, 0.0),
		"L:UpperArm": Vector3(-110.0, 0.0, -85.0),
		"L:LowerArm": Vector3(0.0, -15.0, 0.0),
		"R:UpperArm": Vector3(-70.0, 0.0, 115.0),
		"R:LowerArm": Vector3(0.0, 75.0, 0.0),
		"R:LowerLeg": Vector3(44.0, 0.0, 0.0),
		"L:LowerLeg": Vector3(46.0, 0.0, 0.0),
	})
	var impact: Dictionary = merged(address, {
		"Hips": Vector3(22.0, 20.0, 0.0),
		"Spine": Vector3(6.0, 3.0, 0.0),
		"Chest": Vector3(6.0, 8.0, 0.0),
		"UpperChest": Vector3(0.0, 4.0, 0.0),
		"Neck": Vector3(-14.0, -18.0, 0.0),
		"L:UpperArm": Vector3(-45.0, 0.0, -100.0),
		"R:UpperArm": Vector3(-45.0, 0.0, 100.0),
	})
	var finish: Dictionary = {
		"Hips": Vector3(8.0, 55.0, 0.0),
		"Spine": Vector3(0.0, 15.0, 0.0),
		"Chest": Vector3(0.0, 25.0, 0.0),
		"UpperChest": Vector3(0.0, 15.0, 0.0),
		"Neck": Vector3(-6.0, -50.0, 0.0),
		"S:UpperLeg": Vector3(-18.0, 0.0, 5.0),
		"S:LowerLeg": Vector3(18.0, 0.0, 0.0),
		"S:Foot": Vector3(0.0, 0.0, 0.0),
		"R:LowerLeg": Vector3(50.0, 0.0, 0.0),
		"L:UpperArm": Vector3(-130.0, 0.0, -40.0),
		"L:LowerArm": Vector3(0.0, -95.0, 0.0),
		"R:UpperArm": Vector3(-110.0, 0.0, 110.0),
		"R:LowerArm": Vector3(0.0, 80.0, 0.0),
	}
	return [
		make_key(0.0, address),
		make_key(0.45, takeaway),
		make_key(1.05, top),
		make_key(IMPACT_TIME_SWING_FULL, impact),
		make_key(1.9, finish),
		make_key(LENGTH_SWING_FULL, finish),
	]


# ---------------------------------------------------------------------------------------------
# Animation construction
# ---------------------------------------------------------------------------------------------

## Builds one Animation from key dictionaries. Every humanoid bone that appears in any key gets a
## rotation track with a key at every key time (bones absent from a key rest at zero delta).
## Hips also gets a position track when any key has a hips offset.
static func make_animation(keys: Array, length: float, loop: bool, skeleton_path: NodePath,
		rest_rot: Dictionary, hips_rest: Vector3) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	var expanded: Array = []
	var used: Dictionary = {}
	var need_hips_pos: bool = false
	for k: Dictionary in keys:
		var full: Dictionary = expand_pose(k["pose"])
		expanded.append(full)
		for b: Variant in full.keys():
			used[str(b)] = true
		var ho: Vector3 = k["hips"]
		if ho != Vector3.ZERO:
			need_hips_pos = true

	for bone: String in MHGolferRig.HUMANOID_BONES:
		if not used.has(bone):
			continue
		var track: int = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath(str(skeleton_path) + ":" + bone))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		var rest_q: Quaternion = rest_rot.get(bone, Quaternion.IDENTITY)
		for i: int in range(keys.size()):
			var e: Vector3 = expanded[i].get(bone, Vector3.ZERO)
			var kt: float = keys[i]["t"]
			anim.rotation_track_insert_key(track, kt, rest_q * euler_deg_to_quat(e))

	if need_hips_pos:
		var ptrack: int = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(ptrack, NodePath(str(skeleton_path) + ":Hips"))
		anim.track_set_interpolation_type(ptrack, Animation.INTERPOLATION_LINEAR)
		for k: Dictionary in keys:
			var kt2: float = k["t"]
			var off: Vector3 = k["hips"]
			anim.position_track_insert_key(ptrack, kt2, hips_rest + off)
	return anim


## Builds the library with idle, address, walk, putt and swing_full.
## skeleton_path: path from the AnimationPlayer's root_node to the Skeleton3D (MHGolferRig.skeleton_track_path()).
static func build_library(skeleton_path: NodePath, rest_rot: Dictionary = {},
		hips_rest: Vector3 = Vector3(0.0, 0.92, 0.0)) -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation(CLIP_IDLE, make_animation(keys_idle(), LENGTH_IDLE, true, skeleton_path, rest_rot, hips_rest))
	lib.add_animation(CLIP_ADDRESS, make_animation(keys_address(), LENGTH_ADDRESS, true, skeleton_path, rest_rot, hips_rest))
	lib.add_animation(CLIP_WALK, make_animation(keys_walk(), LENGTH_WALK, true, skeleton_path, rest_rot, hips_rest))
	lib.add_animation(CLIP_PUTT, make_animation(keys_putt(), LENGTH_PUTT, false, skeleton_path, rest_rot, hips_rest))
	lib.add_animation(CLIP_SWING_FULL, make_animation(keys_swing_full(), LENGTH_SWING_FULL, false, skeleton_path, rest_rot, hips_rest))
	return lib
