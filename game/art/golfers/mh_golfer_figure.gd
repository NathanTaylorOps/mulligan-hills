class_name MHGolferFigure
extends Node3D
## A posed, animated golfer built from MHGolferMeshes: one Node3D per joint, one MeshInstance3D per joint
## part. Good for the few golfers near the camera. For crowds use MHGolferMeshes.build_posed (one mesh per
## golfer) or a cache of baked frames; 12 draw calls per golfer is too many for 40 golfers on a phone
## (see docs/phase1/art_nature_golfers_props.md).
##
## `advance(dt)` is public and does not depend on the scene tree, so tests and the gallery can drive it
## directly. With `auto_advance` true (default) `_process` calls it every frame.
##
## STATUS: NOT YET RUN in Godot.

signal impact
signal clip_finished(clip_name: String)

var look: MHGolferLook = null
var lod: int = 0
var clip: String = ""
var time: float = 0.0
var speed: float = 1.0
var auto_advance: bool = true
var playing: bool = false

var _joints: Dictionary = {}
var _impact_fired: bool = false
var _finished: bool = false


## Builds the joint tree. `mat` is shared by every part (use MHArtMaterials.vertex_color()).
func setup(new_look: MHGolferLook, new_lod: int, mat: Material) -> void:
	clear()
	look = new_look
	lod = clampi(new_lod, 0, MHGolferMeshes.LOD_COUNT - 1)
	scale = Vector3(look.height, look.height, look.height)
	for j: Variant in MHGolferMeshes.JOINTS:
		var joint: String = str(j)
		var node: Node3D = Node3D.new()
		node.name = joint
		var parent_name: String = str(MHGolferMeshes.PARENT[joint])
		if parent_name == "":
			add_child(node)
		else:
			(_joints[parent_name] as Node3D).add_child(node)
		_joints[joint] = node
		var mesh: ArrayMesh = MHGolferMeshes.build_part(look, joint, lod)
		if mesh.get_surface_count() > 0:
			var mi: MeshInstance3D = MHArtMaterials.make_instance(mesh, mat, lod == 0)
			node.add_child(mi)
	set_pose({})


## Removes the joint tree.
func clear() -> void:
	for c: Node in get_children():
		remove_child(c)
		c.free()
	_joints.clear()


func joint_node(joint: String) -> Node3D:
	return _joints.get(joint, null) as Node3D


func joint_count() -> int:
	return _joints.size()


## Applies a pose Dictionary (see MHGolferMeshes) to the joint nodes.
func set_pose(pose: Dictionary) -> void:
	for j: Variant in MHGolferMeshes.JOINTS:
		var joint: String = str(j)
		var node: Node3D = _joints.get(joint, null) as Node3D
		if node == null:
			continue
		node.transform = Transform3D(MHGolferMeshes.local_basis(joint, pose), MHGolferMeshes.local_origin(joint, pose))


## Starts a clip (MHGolferPoses.CLIP_*). Restarting resets time and impact. A clip already playing is
## left alone when `restart` is false.
func play(clip_name: String, restart: bool = true) -> void:
	if not restart and playing and clip == clip_name:
		return
	clip = clip_name
	time = 0.0
	playing = true
	_impact_fired = false
	_finished = false
	set_pose(MHGolferPoses.sample(clip, 0.0))


func stop() -> void:
	playing = false


func advance(dt: float) -> void:
	if not playing or clip == "":
		return
	var prev: float = time
	time += dt * speed
	var length: float = MHGolferPoses.length_of(clip)
	var looping: bool = MHGolferPoses.is_looping(clip)
	var hit_at: float = MHGolferPoses.impact_time(clip)
	if hit_at >= 0.0 and not _impact_fired and prev < hit_at and time >= hit_at:
		_impact_fired = true
		impact.emit()
	if looping:
		time = fposmod(time, length)
	elif time >= length:
		time = length
		if not _finished:
			_finished = true
			playing = false
			clip_finished.emit(clip)
	set_pose(MHGolferPoses.sample(clip, time))


func _process(delta: float) -> void:
	if auto_advance:
		advance(delta)
