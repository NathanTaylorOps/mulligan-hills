class_name MHForest
extends Node3D
## Builds the forest: one MultiMeshInstance3D per (chunk, LOD) plus one blob-shadow MultiMesh per chunk.
## LOD switching uses GeometryInstance3D visibility ranges, so it is per CHUNK (distance to the
## chunk instance), not per tree. See docs/phase0/forest.md for the consequence.

const TREE_SHADER: String = "res://render/shaders/tree.gdshader"
const BILLBOARD_SHADER: String = "res://render/shaders/tree_billboard.gdshader"
const BLOB_SHADER: String = "res://render/shaders/blob_shadow.gdshader"

var tree_seed: int = 20260929
var tree_count: int = 800
var placement: PackedInt32Array = PackedInt32Array()

var _mesh_lod0: ArrayMesh
var _mesh_lod1: ArrayMesh
var _mesh_lod2: ArrayMesh
var _mat_lod0: ShaderMaterial
var _mat_lod1: ShaderMaterial
var _mat_lod2: ShaderMaterial
var _blob_mat: ShaderMaterial
var _blob_mesh: ArrayMesh

var _lod0_nodes: Array[MultiMeshInstance3D] = []
var _lod1_nodes: Array[MultiMeshInstance3D] = []
var _lod2_nodes: Array[MultiMeshInstance3D] = []
var _blob_nodes: Array[MultiMeshInstance3D] = []
var _built: bool = false


func build() -> void:
	if _built:
		return
	_built = true
	placement = MHTreePlacement.place(tree_seed, tree_count)
	_mesh_lod0 = MHTreeMeshes.build_lod0()
	_mesh_lod1 = MHTreeMeshes.build_lod1()
	_mesh_lod2 = MHTreeMeshes.build_lod2()
	_mat_lod0 = _make_material(TREE_SHADER)
	_mat_lod1 = _make_material(TREE_SHADER)
	_mat_lod2 = _make_material(BILLBOARD_SHADER)
	_blob_mesh = _make_blob_mesh()
	_blob_mat = ShaderMaterial.new()
	_blob_mat.shader = load(BLOB_SHADER) as Shader

	var groups: Array = MHTreePlacement.group_by_chunk(placement)
	for c in range(MHTreePlacement.chunk_count()):
		var idxs: PackedInt32Array = groups[c]
		_lod0_nodes.append(_make_chunk_node(idxs, _mesh_lod0, _mat_lod0, "Chunk%d_LOD0" % c))
		_lod1_nodes.append(_make_chunk_node(idxs, _mesh_lod1, _mat_lod1, "Chunk%d_LOD1" % c))
		_lod2_nodes.append(_make_chunk_node(idxs, _mesh_lod2, _mat_lod2, "Chunk%d_LOD2" % c))
		_blob_nodes.append(_make_blob_node(idxs, "Chunk%d_Blob" % c))


func _make_material(shader_path: String) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(shader_path) as Shader
	return m


func _make_blob_mesh() -> ArrayMesh:
	var verts: PackedVector3Array = PackedVector3Array([
		Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5)])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)])
	var normals: PackedVector3Array = PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	# Clockwise seen from above (+Y) is the front face in Godot.
	var idx: PackedInt32Array = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Converts integer mm placement to a world-space position (metres), centred on the origin.
static func world_pos_of(x_mm: int, z_mm: int) -> Vector3:
	var half: float = float(MHTreePlacement.WORLD_MM) * 0.0005
	return Vector3(float(x_mm) * 0.001 - half, 0.0, float(z_mm) * 0.001 - half)


static func variant_tint(variant: int) -> Color:
	match variant:
		1:
			return Color(0.92, 1.0, 0.9)
		2:
			return Color(1.0, 0.95, 0.85)
		_:
			return Color(1.0, 1.0, 1.0)


func _tree_transform(i: int) -> Transform3D:
	var o: int = i * MHTreePlacement.STRIDE
	var pos: Vector3 = world_pos_of(placement[o], placement[o + 1])
	var yaw: float = deg_to_rad(float(placement[o + 2]) * 0.1)
	var s: float = float(placement[o + 3]) * 0.01
	var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s))
	return Transform3D(basis, pos)


func _make_chunk_node(idxs: PackedInt32Array, mesh: ArrayMesh, mat: ShaderMaterial, node_name: String) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = idxs.size()
	for k in range(idxs.size()):
		var i: int = idxs[k]
		mm.set_instance_transform(k, _tree_transform(i))
		mm.set_instance_color(k, variant_tint(placement[i * MHTreePlacement.STRIDE + 4]))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = mat
	add_child(node)
	return node


func _make_blob_node(idxs: PackedInt32Array, node_name: String) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _blob_mesh
	mm.instance_count = idxs.size()
	for k in range(idxs.size()):
		var t: Transform3D = _tree_transform(idxs[k])
		var s: float = t.basis.get_scale().x * 4.6
		t.basis = Basis(Vector3.UP, 0.0).scaled(Vector3(s, 1.0, s))
		t.origin.y = 0.06
		mm.set_instance_transform(k, t)
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = _blob_mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## Applies tier settings: LOD ranges, shadow casting, blob shadows, dither.
func apply_tier(cfg: Dictionary) -> void:
	if not _built:
		build()
	var l0: float = float(cfg["lod0_end"])
	var l1: float = float(cfg["lod1_end"])
	var casts: bool = str(cfg["shadow_mode"]) != MHQuality.SHADOW_OFF
	var shadow_on: int = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var blobs: bool = bool(cfg["blob_shadows"])
	for c in range(_lod0_nodes.size()):
		var n0: MultiMeshInstance3D = _lod0_nodes[c]
		var n1: MultiMeshInstance3D = _lod1_nodes[c]
		var n2: MultiMeshInstance3D = _lod2_nodes[c]
		# LOD0 disabled entirely when lod0_end is 0 (Low tier).
		n0.visible = l0 > 0.0
		n0.visibility_range_begin = 0.0
		n0.visibility_range_end = l0
		n1.visibility_range_begin = l0
		n1.visibility_range_end = l1
		n2.visibility_range_begin = l1
		n2.visibility_range_end = 0.0
		for n in [n0, n1, n2]:
			var gi: MultiMeshInstance3D = n
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		n0.cast_shadow = shadow_on
		n1.cast_shadow = shadow_on
		n2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_blob_nodes[c].visible = blobs
	if not bool(cfg["foliage_dither"]):
		set_brush(Vector3.ZERO, 1.0, 0.0)


## World-space brush: trees near `pos` (XZ distance under `radius`) dither out. strength 0..1.
func set_brush(pos: Vector3, radius: float, strength: float) -> void:
	for m in [_mat_lod0, _mat_lod1, _mat_lod2]:
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("brush_pos", pos)
		sm.set_shader_parameter("brush_radius", radius)
		sm.set_shader_parameter("brush_strength", strength)


func chunk_node_count() -> int:
	return _lod0_nodes.size() + _lod1_nodes.size() + _lod2_nodes.size() + _blob_nodes.size()


@warning_ignore("integer_division")
func placed_tree_count() -> int:
	return placement.size() / MHTreePlacement.STRIDE
