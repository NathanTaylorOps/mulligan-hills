class_name MHGolferRig
extends Node3D
## Loads the golfer model, finds its Skeleton3D, checks it against Godot's humanoid bone names,
## and installs procedural (or imported) animations.
##
## STATUS: NOT YET RUN. Written without access to a Godot editor. Items marked UNVERIFIED must be
## checked against the docs for the Godot version pinned in docs/GODOT_VERSION.md.
##
## Typical use:
##   var rig := MHGolferRig.new()
##   add_child(rig)
##   if rig.load_model():
##       var lib := MHProceduralSwing.build_library(rig.skeleton_track_path(), rig.capture_rest_rotations(), rig.hips_rest_position())
##       var player := rig.install_animations(lib)
##       var animator := MHGolferAnimator.new()
##       add_child(animator)
##       animator.setup(player)
##       animator.set_state(MHGolferAnimator.State.IDLE)

const MODEL_PATH: String = "res://characters/golfer_placeholder.gltf"

## Godot SkeletonProfileHumanoid names for the bones this project uses (the full profile also has
## Root, eyes, jaw and finger bones, which the placeholder does not have). UNVERIFIED: exact string
## list for the pinned version, see
## https://docs.godotengine.org/en/stable/classes/class_skeletonprofilehumanoid.html
const HUMANOID_BONES: PackedStringArray = [
	"Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "LeftToes",
	"RightUpperLeg", "RightLowerLeg", "RightFoot", "RightToes",
]

var model_root: Node = null
var skeleton: Skeleton3D = null
## Prefix added to profile bone names to get this skeleton's names, for example "mixamorig:" for a
## raw Mixamo skeleton. Empty for the generated placeholder.
var bone_prefix: String = ""


## Loads and instances the model. Returns true on success. Safe to call again (replaces the model).
func load_model(path: String = MODEL_PATH) -> bool:
	unload_model()
	var root: Node = null
	# Preferred: the editor-imported resource (works in exported builds).
	var res: Resource = load(path)
	if res is PackedScene:
		root = (res as PackedScene).instantiate()
	else:
		# Fallback for raw files at runtime. UNVERIFIED: GLTFDocument.append_from_file / generate_scene
		# signatures; confirm in the GLTFDocument class reference.
		var doc: GLTFDocument = GLTFDocument.new()
		var state: GLTFState = GLTFState.new()
		var err: int = doc.append_from_file(ProjectSettings.globalize_path(path), state)
		if err != OK:
			push_error("MHGolferRig: cannot load %s (error %d)" % [path, err])
			return false
		root = doc.generate_scene(state)
	if root == null:
		push_error("MHGolferRig: no scene produced for %s" % path)
		return false
	add_child(root)
	model_root = root
	# owned=false is required: instanced children are not owned by the scene root we created.
	var found: Array = root.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("MHGolferRig: model has no Skeleton3D")
		unload_model()
		return false
	skeleton = found[0] as Skeleton3D
	return true


func unload_model() -> void:
	if model_root != null:
		model_root.queue_free()
	model_root = null
	skeleton = null


func skeleton_bone_name(profile_bone: String) -> String:
	return bone_prefix + profile_bone


## Returns the profile bone names that this skeleton lacks (empty means the rig is complete).
func missing_bones() -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	if skeleton == null:
		return HUMANOID_BONES.duplicate()
	for b: String in HUMANOID_BONES:
		if skeleton.find_bone(skeleton_bone_name(b)) < 0:
			missing.append(b)
	return missing


## Builds a BoneMap for SkeletonProfileHumanoid. BoneMap is mainly used by the editor's import
## retargeting (Import dock, Skeleton3D > Retarget > Bone Map) so this is for editor tooling and
## tests; runtime code should use skeleton_bone_name(). UNVERIFIED: that set_skeleton_bone_name
## works after assigning profile at runtime; see
## https://docs.godotengine.org/en/stable/classes/class_bonemap.html
func build_bone_map() -> BoneMap:
	var bm: BoneMap = BoneMap.new()
	bm.profile = SkeletonProfileHumanoid.new()
	for b: String in HUMANOID_BONES:
		bm.set_skeleton_bone_name(StringName(b), StringName(skeleton_bone_name(b)))
	return bm


## Path from the model root to the skeleton, as a String, for building animation track paths.
## Requires the model to be inside the tree (load_model adds it as a child).
func skeleton_track_path() -> NodePath:
	if model_root == null or skeleton == null:
		return NodePath("")
	return model_root.get_path_to(skeleton)


## Rest rotation of each humanoid bone, keyed by profile bone name. Used so animation keys are
## rest * delta (correct even when a skeleton's rest pose is not all-identity, e.g. Mixamo).
func capture_rest_rotations() -> Dictionary:
	var out: Dictionary = {}
	if skeleton == null:
		return out
	for b: String in HUMANOID_BONES:
		var idx: int = skeleton.find_bone(skeleton_bone_name(b))
		if idx >= 0:
			out[b] = skeleton.get_bone_rest(idx).basis.get_rotation_quaternion()
	return out


func hips_rest_position() -> Vector3:
	if skeleton == null:
		return Vector3(0.0, 0.92, 0.0)
	var idx: int = skeleton.find_bone(skeleton_bone_name("Hips"))
	if idx < 0:
		return Vector3(0.0, 0.92, 0.0)
	return skeleton.get_bone_rest(idx).origin


## Creates an AnimationPlayer whose root is the model root and adds the library as the default one.
func install_animations(library: AnimationLibrary) -> AnimationPlayer:
	var player: AnimationPlayer = AnimationPlayer.new()
	add_child(player)
	player.root_node = player.get_path_to(model_root)
	var err: int = player.add_animation_library(&"", library)
	if err != OK:
		push_error("MHGolferRig: add_animation_library failed (%d)" % err)
	return player


## Attaches a node (a golf club mesh, say) to a bone. Returns the BoneAttachment3D.
func attach_to_bone(profile_bone: String, node: Node3D) -> BoneAttachment3D:
	var att: BoneAttachment3D = BoneAttachment3D.new()
	att.name = "Attach_" + profile_bone
	skeleton.add_child(att)
	att.bone_name = skeleton_bone_name(profile_bone)
	att.add_child(node)
	return att


## Forces a flat toon material that reads the model's vertex colours. Call this if the imported
## glTF material shows plain white in Godot. UNVERIFIED whether the importer already does this.
func apply_vertex_color_material() -> void:
	if model_root == null:
		return
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for n: Node in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi != null:
			mi.material_override = mat
