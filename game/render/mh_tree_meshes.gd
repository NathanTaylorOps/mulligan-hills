class_name MHTreeMeshes
extends RefCounted
## Procedural low-poly conifer meshes, flat shaded with vertex colours. No external assets.
## LOD0: 6-sided trunk + 3 cones of 10 sides (42 tris)
## LOD1: 4-sided trunk + 2 cones of 6 sides (20 tris)
## LOD2: billboard silhouette (canopy triangle + trunk quad, 3 tris), faced to camera by shader
## Tree height is about 8 m at scale 1.0; scale variation comes from the instance transform.

const TRUNK_COLOR: Color = Color(0.36, 0.24, 0.14)
const LEAF_LOW: Color = Color(0.12, 0.34, 0.16)
const LEAF_HIGH: Color = Color(0.22, 0.52, 0.24)


class Builder:
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	## Adds a triangle. `outward` is a point the face should look away from (winding fixed automatically;
	## Godot front faces are clockwise).
	func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, outward: Vector3) -> void:
		var n: Vector3 = (b - a).cross(c - a)
		if n.length_squared() < 0.0000001:
			return
		n = n.normalized()
		var mid: Vector3 = (a + b + c) / 3.0
		var bb: Vector3 = b
		var cc2: Vector3 = c
		var cb2: Color = cb
		var cc3: Color = cc
		if n.dot(mid - outward) < 0.0:
			n = -n
			bb = c
			cc2 = b
			cb2 = cc
			cc3 = cb
		# After the swap the counter-clockwise normal points outward; Godot wants clockwise front,
		# so emit in reverse order (a, c', b').
		var base: int = verts.size()
		verts.append(a)
		verts.append(cc2)
		verts.append(bb)
		colors.append(ca)
		colors.append(cc3)
		colors.append(cb2)
		for i in range(3):
			normals.append(n)
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)

	func to_mesh() -> ArrayMesh:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh: ArrayMesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


static func _ring(radius: float, y: float, sides: int, i: int) -> Vector3:
	var ang: float = TAU * float(i) / float(sides)
	return Vector3(cos(ang) * radius, y, sin(ang) * radius)


static func _add_trunk(b: Builder, sides: int, radius: float, height: float) -> void:
	var axis: Vector3 = Vector3(0.0, height * 0.5, 0.0)
	for i in range(sides):
		var b0: Vector3 = _ring(radius, 0.0, sides, i)
		var b1: Vector3 = _ring(radius, 0.0, sides, i + 1)
		var t0: Vector3 = _ring(radius * 0.7, height, sides, i)
		var t1: Vector3 = _ring(radius * 0.7, height, sides, i + 1)
		b.tri(b0, b1, t1, TRUNK_COLOR, TRUNK_COLOR, TRUNK_COLOR, axis)
		b.tri(b0, t1, t0, TRUNK_COLOR, TRUNK_COLOR, TRUNK_COLOR, axis)


static func _add_cone(b: Builder, sides: int, base_y: float, height: float, radius: float) -> void:
	var apex: Vector3 = Vector3(0.0, base_y + height, 0.0)
	var center: Vector3 = Vector3(0.0, base_y + height * 0.3, 0.0)
	for i in range(sides):
		var p0: Vector3 = _ring(radius, base_y, sides, i)
		var p1: Vector3 = _ring(radius, base_y, sides, i + 1)
		b.tri(p0, p1, apex, LEAF_LOW, LEAF_LOW, LEAF_HIGH, center)


static func build_lod0() -> ArrayMesh:
	var b: Builder = Builder.new()
	_add_trunk(b, 6, 0.28, 2.0)
	_add_cone(b, 10, 1.6, 3.4, 2.1)
	_add_cone(b, 10, 3.6, 3.0, 1.6)
	_add_cone(b, 10, 5.4, 2.7, 1.1)
	return b.to_mesh()


static func build_lod1() -> ArrayMesh:
	var b: Builder = Builder.new()
	_add_trunk(b, 4, 0.3, 2.0)
	_add_cone(b, 6, 1.6, 4.2, 2.0)
	_add_cone(b, 6, 4.4, 3.6, 1.3)
	return b.to_mesh()


## Vertical silhouette in the local XY plane (faces +Z); the billboard shader turns it to the camera.
static func build_lod2() -> ArrayMesh:
	var b: Builder = Builder.new()
	var front: Vector3 = Vector3(0.0, 4.0, -10.0)
	b.tri(Vector3(-2.0, 1.6, 0.0), Vector3(2.0, 1.6, 0.0), Vector3(0.0, 8.0, 0.0),
		LEAF_LOW, LEAF_LOW, LEAF_HIGH, front)
	b.tri(Vector3(-0.3, 0.0, 0.0), Vector3(0.3, 0.0, 0.0), Vector3(0.3, 1.6, 0.0),
		TRUNK_COLOR, TRUNK_COLOR, TRUNK_COLOR, front)
	b.tri(Vector3(-0.3, 0.0, 0.0), Vector3(0.3, 1.6, 0.0), Vector3(-0.3, 1.6, 0.0),
		TRUNK_COLOR, TRUNK_COLOR, TRUNK_COLOR, front)
	return b.to_mesh()


@warning_ignore("integer_division")
static func triangle_count(mesh: ArrayMesh) -> int:
	var arrays: Array = mesh.surface_get_arrays(0)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return idx.size() / 3
