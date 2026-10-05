class_name MHGolferMeshes
extends RefCounted
## Procedural low-poly golfer (DEC-062: built from code, no imported assets).
##
## The body is a hierarchy of 12 joints. Each joint owns one flat-shaded part mesh drawn in the joint's
## own frame (origin at the joint, limbs hang down -Y), so the same geometry serves two uses:
##   1. MHGolferFigure: a Node3D tree, one MeshInstance3D per joint, posed by rotating the joints.
##   2. build_posed(): the whole golfer baked into ONE ArrayMesh at one pose (distant crowds, MultiMesh,
##      thumbnails). One draw call per golfer.
##
## Conventions (match docs/phase0/animation.md and MHProceduralSwing): the golfer faces +Z, its LEFT
## is +X, up is +Y, units are metres, origin is on the ground between the feet. A right-handed golfer
## aims at a target along +X. Pose values are Euler DEGREES per joint, composed as
## R = Rx * Ry * Rz (see `rot`): Rz is applied to the limb first, Rx last. This order is spelled out
## with three explicit axis rotations so it does not depend on Godot's Euler-order enum.
##   hips:   yaw only (turns pelvis and legs). `hips_pos` (Vector3) shifts the whole body.
##   spine:  x bends forward, y turns the chest (negative = away from the target), z leans sideways.
##   limbs hang at rest; x swings forward when NEGATIVE, z moves the arm/leg away from the body
##   (left +, right -).
##   knee/elbow (the *_lower joints): x NEGATIVE bends the elbow forward, POSITIVE bends the knee.
##   club:   rotation relative to the right forearm; `club_scale` scales its length (putter 0.82).
## Rest pose (empty Dictionary) is a straight stand with arms and legs hanging.
##
## LODs: 0 (near, up to ~230 triangles), 1 (mid, ~165), 2 (far, ~90, no hands, shoes, hair, club).

const LOD_COUNT: int = 3
## Triangle budgets per LOD for a whole golfer (worst-case look). Checked by tests/art/test_golfer_meshes.gd.
const BUDGETS: Array = [250, 180, 100]

const JOINTS: Array = [
	"hips", "spine", "head", "arm_l_upper", "arm_l_lower", "arm_r_upper", "arm_r_lower", "club",
	"leg_l_upper", "leg_l_lower", "leg_r_upper", "leg_r_lower",
]

const PARENT: Dictionary = {
	"hips": "",
	"spine": "hips",
	"head": "spine",
	"arm_l_upper": "spine",
	"arm_l_lower": "arm_l_upper",
	"arm_r_upper": "spine",
	"arm_r_lower": "arm_r_upper",
	"club": "arm_r_lower",
	"leg_l_upper": "hips",
	"leg_l_lower": "leg_l_upper",
	"leg_r_upper": "hips",
	"leg_r_lower": "leg_r_upper",
}

## Joint position relative to its parent, at rest.
const OFFSET: Dictionary = {
	"hips": Vector3(0.0, 0.94, 0.0),
	"spine": Vector3(0.0, 0.08, 0.0),
	"head": Vector3(0.0, 0.55, 0.0),
	"arm_l_upper": Vector3(0.22, 0.50, 0.0),
	"arm_l_lower": Vector3(0.0, -0.30, 0.0),
	"arm_r_upper": Vector3(-0.22, 0.50, 0.0),
	"arm_r_lower": Vector3(0.0, -0.30, 0.0),
	"club": Vector3(0.0, -0.28, 0.0),
	"leg_l_upper": Vector3(0.10, -0.02, 0.0),
	"leg_l_lower": Vector3(0.0, -0.44, 0.0),
	"leg_r_upper": Vector3(-0.10, -0.02, 0.0),
	"leg_r_lower": Vector3(0.0, -0.44, 0.0),
}

const UPPER_ARM: float = 0.30
const LOWER_ARM: float = 0.28
const UPPER_LEG: float = 0.44
const LOWER_LEG: float = 0.44
## Club shaft length below the hand (the grip extends 0.10 above it).
const CLUB_LENGTH: float = 1.02
## Local point on the club where the left hand rests (the right hand is the club joint origin).
const CLUB_LEFT_HAND: Vector3 = Vector3(0.0, 0.08, 0.0)
## Local point of the club head (centre), at scale 1.0.
const CLUB_HEAD: Vector3 = Vector3(0.0, -1.04, 0.04)
## Nominal standing height in metres at height 1.0.
const STAND_HEIGHT: float = 1.83


## Joint rotation from Euler degrees: Rx * Ry * Rz.
static func rot(e: Vector3) -> Basis:
	return Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(e.x)) \
		* Basis(Vector3(0.0, 1.0, 0.0), deg_to_rad(e.y)) \
		* Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(e.z))


## Local basis of a joint for a pose (club includes its length scale).
static func local_basis(joint: String, pose: Dictionary) -> Basis:
	var e: Vector3 = pose.get(joint, Vector3.ZERO) as Vector3
	var b: Basis = rot(e)
	if joint == "club":
		var s: float = float(pose.get("club_scale", 1.0))
		b = b * Basis.from_scale(Vector3(1.0, s, 1.0))
	return b


## Local origin of a joint for a pose (only the hips move: `hips_pos`).
static func local_origin(joint: String, pose: Dictionary) -> Vector3:
	var o: Vector3 = OFFSET[joint] as Vector3
	if joint == "hips":
		o += pose.get("hips_pos", Vector3.ZERO) as Vector3
	return o


## Forward kinematics: joint name -> Transform3D relative to the golfer root (the ground point).
static func joint_transforms(pose: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for j: Variant in JOINTS:
		var joint: String = str(j)
		var local: Transform3D = Transform3D(local_basis(joint, pose), local_origin(joint, pose))
		var parent: String = str(PARENT[joint])
		if parent == "":
			out[joint] = local
		else:
			out[joint] = (out[parent] as Transform3D) * local
	return out


## Lowest point of either ankle (metres above the ground) for a pose. Standing is about 0.04.
static func ankle_height(pose: Dictionary) -> float:
	var t: Dictionary = joint_transforms(pose)
	var a: Vector3 = (t["leg_l_lower"] as Transform3D) * Vector3(0.0, -LOWER_LEG, 0.0)
	var b: Vector3 = (t["leg_r_lower"] as Transform3D) * Vector3(0.0, -LOWER_LEG, 0.0)
	return minf(a.y, b.y)


## World (root-frame) position of the club head centre for a pose.
static func club_head_position(pose: Dictionary) -> Vector3:
	var t: Dictionary = joint_transforms(pose)
	return (t["club"] as Transform3D) * CLUB_HEAD


## Distance between the left hand and its resting spot on the grip. Near zero means a clean two-hand grip.
static func grip_gap(pose: Dictionary) -> float:
	var t: Dictionary = joint_transforms(pose)
	var hand: Vector3 = (t["arm_l_lower"] as Transform3D) * Vector3(0.0, -LOWER_ARM, 0.0)
	var grip: Vector3 = (t["club"] as Transform3D) * CLUB_LEFT_HAND
	return hand.distance_to(grip)


# ---------------------------------------------------------------- part geometry

static func _limb_sides(lod: int) -> int:
	if lod == 0:
		return 5
	if lod == 1:
		return 4
	return 3


## Adds the geometry of one joint's part to `b`, in the joint frame (the caller sets b.xf).
static func add_part(b: MHMeshBuilder, look: MHGolferLook, joint: String, lod: int) -> void:
	var l: int = clampi(lod, 0, LOD_COUNT - 1)
	var sides: int = _limb_sides(l)
	var shirt: Color = look.shirt
	var shirt_dark: Color = MHPalette.shade(look.shirt, 0.82)
	var trousers: Color = look.trousers
	var trousers_dark: Color = MHPalette.shade(look.trousers, 0.85)
	match joint:
		"hips":
			b.box(Vector3.ZERO, Vector3(0.30 * look.build, 0.16, 0.20), trousers, trousers, trousers_dark)
		"spine":
			var saved: Transform3D = b.xf
			b.set_xf(saved * Transform3D(Basis.from_scale(Vector3(1.3 * look.build, 1.0, 0.78)), Vector3.ZERO))
			var torso_sides: int = 6
			if l == 1:
				torso_sides = 4
			elif l == 2:
				torso_sides = 3
			b.frustum(-0.04, 0.55, 0.14, 0.17, torso_sides, shirt_dark, shirt, true, true)
			b.set_xf(saved)
		"head":
			_add_head(b, look, l)
		"arm_l_upper", "arm_r_upper":
			b.tube(Vector3.ZERO, Vector3(0.0, -UPPER_ARM, 0.0), 0.055, 0.05, sides, shirt, shirt_dark)
		"arm_l_lower", "arm_r_lower":
			b.tube(Vector3.ZERO, Vector3(0.0, -LOWER_ARM, 0.0), 0.045, 0.04, sides, look.skin,
				MHPalette.shade(look.skin, 0.92), false, l == 0)
		"club":
			if l <= 1:
				_add_club(b, l)
		"leg_l_upper", "leg_r_upper":
			b.tube(Vector3.ZERO, Vector3(0.0, -UPPER_LEG, 0.0), 0.075, 0.065, sides, trousers, trousers_dark)
		"leg_l_lower", "leg_r_lower":
			b.tube(Vector3.ZERO, Vector3(0.0, -LOWER_LEG, 0.0), 0.06, 0.05, sides, trousers_dark, trousers_dark,
				false, false)
			if l <= 1:
				b.box(Vector3(0.0, -LOWER_LEG, 0.06), Vector3(0.11, 0.08, 0.26), MHPalette.shade(look.shoes, 1.06),
					look.shoes, MHPalette.shade(look.shoes, 0.6))
			else:
				# Far LOD: a flat cap closes the ankle (3 triangles) instead of a shoe.
				var a0: Vector3 = Vector3(0.0, -LOWER_LEG, 0.0)
				b.disc(a0, 0.05, 3, look.shoes, false)


static func _add_head(b: MHMeshBuilder, look: MHGolferLook, lod: int) -> void:
	var skin: Color = look.skin
	var skin_dark: Color = MHPalette.shade(look.skin, 0.9)
	var stacks: int = 3
	var sides: int = 6
	if lod == 1:
		stacks = 2
		sides = 5
	elif lod == 2:
		stacks = 2
		sides = 4
	b.blob(Vector3(0.0, 0.13, 0.0), Vector3(0.105, 0.125, 0.115), stacks, sides, skin_dark, skin, 901, 0.03)
	if lod >= 2:
		return
	var hair: Color = look.hair
	var hair_dark: Color = MHPalette.shade(look.hair, 0.8)
	var style: int = look.hair_style
	if lod == 0:
		if style == MHGolferLook.HAIR_SHORT or style == MHGolferLook.HAIR_LONG:
			b.blob(Vector3(0.0, 0.185, -0.02), Vector3(0.112, 0.095, 0.12), 3, 6, hair_dark, hair, 902, 0.04)
			if style == MHGolferLook.HAIR_LONG:
				b.tube(Vector3(0.0, 0.12, -0.08), Vector3(0.0, -0.12, -0.10), 0.07, 0.05, 4, hair, hair_dark)
		else:
			_add_hat(b, look, 6)
	else:
		if style == MHGolferLook.HAIR_SHORT or style == MHGolferLook.HAIR_LONG:
			b.blob(Vector3(0.0, 0.185, -0.02), Vector3(0.112, 0.095, 0.12), 2, 5, hair_dark, hair, 902, 0.04)
		else:
			_add_hat(b, look, 4)


## Cap (brim quad) or sun hat (round brim) with `sides`-sided geometry.
## Cap: sides*3 + 4 triangles. Sun hat: sides*3 + 2*sides.
static func _add_hat(b: MHMeshBuilder, look: MHGolferLook, sides: int) -> void:
	var c: Color = look.hat
	var c_dark: Color = MHPalette.shade(look.hat, 0.8)
	b.frustum(0.20, 0.30, 0.115, 0.10, sides, c_dark, c, false, true)
	if look.hair_style == MHGolferLook.HAT_CAP:
		b.quad_two_sided(Vector3(-0.10, 0.205, 0.09), Vector3(0.10, 0.205, 0.09), Vector3(0.08, 0.20, 0.26),
			Vector3(-0.08, 0.20, 0.26), c_dark, c)
	else:
		var centre: Vector3 = Vector3(0.0, 0.20, 0.0)
		b.disc(centre, 0.26, sides, c, true)
		b.disc(centre, 0.26, sides, c_dark, false)


static func _add_club(b: MHMeshBuilder, lod: int) -> void:
	var shaft_sides: int = 3
	b.tube(Vector3(0.0, 0.10, 0.0), Vector3(0.0, -CLUB_LENGTH, 0.0), 0.012, 0.009, shaft_sides,
		MHPalette.METAL, MHPalette.METAL)
	if lod == 0:
		b.tube(Vector3(0.0, 0.10, 0.0), Vector3(0.0, -0.25, 0.0), 0.016, 0.016, 3, MHPalette.RUBBER, MHPalette.RUBBER)
	b.box(CLUB_HEAD, Vector3(0.045, 0.04, 0.12), MHPalette.METAL, MHPalette.METAL_DARK, MHPalette.METAL_DARK)


## One joint's part as a mesh in the joint frame (empty mesh if the part has no geometry at this LOD).
static func build_part(look: MHGolferLook, joint: String, lod: int) -> ArrayMesh:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	add_part(b, look, joint, lod)
	return b.to_mesh()


## The whole golfer baked into one mesh at `pose`, including look.height. Origin on the ground.
static func build_posed_builder(look: MHGolferLook, lod: int, pose: Dictionary) -> MHMeshBuilder:
	var b: MHMeshBuilder = MHMeshBuilder.new()
	var t: Dictionary = joint_transforms(pose)
	var root: Transform3D = Transform3D(Basis.from_scale(Vector3(look.height, look.height, look.height)), Vector3.ZERO)
	for j: Variant in JOINTS:
		var joint: String = str(j)
		b.set_xf(root * (t[joint] as Transform3D))
		add_part(b, look, joint, lod)
	b.reset_xf()
	return b


static func build_posed(look: MHGolferLook, lod: int, pose: Dictionary) -> ArrayMesh:
	return build_posed_builder(look, lod, pose).to_mesh()


## Triangle count of the full golfer at this LOD (counts every joint's part).
static func total_tri_count(look: MHGolferLook, lod: int) -> int:
	return build_posed_builder(look, lod, {}).tri_count()


static func budget(lod: int) -> int:
	return int(BUDGETS[clampi(lod, 0, LOD_COUNT - 1)])
