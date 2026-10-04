class_name MHMeshBuilder
extends RefCounted
## Flat-shaded, vertex-coloured mesh builder for procedural art (DEC-062: no imported assets).
## Every triangle owns its three vertices and one face normal, so the result looks faceted and the
## triangle count equals indices / 3 exactly. Output is one ArrayMesh with one surface, which is
## what MultiMesh needs.
##
## Winding: Godot front faces are clockwise. `tri` takes an `outward` hint point (a point the face
## should look away from) and fixes the winding itself, so callers never think about order.
## All geometry is passed through `xf`, the current transform (default identity), so parts can be
## built in a local frame and placed with `set_xf`.
##
## Determinism: no randomness in here. Callers pass explicit values (see MHArtRng).

var verts: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()
var xf: Transform3D = Transform3D.IDENTITY


func set_xf(t: Transform3D) -> void:
	xf = t


func reset_xf() -> void:
	xf = Transform3D.IDENTITY


func tri_count() -> int:
	@warning_ignore("integer_division")
	return indices.size() / 3


## Adds one triangle. `outward` is a point the face must look away from. Degenerate triangles are dropped.
func tri(a0: Vector3, b0: Vector3, c0: Vector3, ca: Color, cb: Color, cc: Color, outward0: Vector3) -> void:
	var a: Vector3 = xf * a0
	var b: Vector3 = xf * b0
	var c: Vector3 = xf * c0
	var out: Vector3 = xf * outward0
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 0.00000001:
		return
	n = n.normalized()
	var mid: Vector3 = (a + b + c) / 3.0
	var base: int = verts.size()
	if n.dot(mid - out) > 0.0:
		# (a, b, c) is counter-clockwise seen from outside; emit clockwise (a, c, b).
		verts.append(a)
		verts.append(c)
		verts.append(b)
		colors.append(ca)
		colors.append(cc)
		colors.append(cb)
	else:
		n = -n
		verts.append(a)
		verts.append(b)
		verts.append(c)
		colors.append(ca)
		colors.append(cb)
		colors.append(cc)
	for i in range(3):
		normals.append(n)
		indices.append(base + i)


## A triangle visible from both sides (2 triangles). Used for thin blades, flags, fronds.
func tri_two_sided(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 0.00000001:
		return
	n = n.normalized()
	var mid: Vector3 = (a + b + c) / 3.0
	tri(a, b, c, ca, cb, cc, mid - n)
	tri(a, b, c, ca, cb, cc, mid + n)


## Quad a,b,c,d in order around the edge (2 triangles), single colour.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, outward: Vector3) -> void:
	tri(a, b, c, col, col, col, outward)
	tri(a, c, d, col, col, col, outward)


## Quad visible from both sides (4 triangles).
func quad_two_sided(a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color) -> void:
	# ca colours the a/d edge, cb colours the b/c edge (a gradient along the strip).
	tri_two_sided(a, b, c, ca, cb, cb)
	tri_two_sided(a, c, d, ca, cb, ca)


static func ring_point(radius: float, y: float, sides: int, i: int) -> Vector3:
	var ang: float = TAU * float(i) / float(sides)
	return Vector3(cos(ang) * radius, y, sin(ang) * radius)


## Frustum (or cylinder, or cone when r1 is about 0) along local +Y from y0 to y1.
## Triangles: sides*2 (sides*1 for a cone), plus `sides` per cap.
func frustum(y0: float, y1: float, r0: float, r1: float, sides: int, c0: Color, c1: Color,
		cap_bottom: bool, cap_top: bool) -> void:
	var axis: Vector3 = Vector3(0.0, (y0 + y1) * 0.5, 0.0)
	var cone_top: bool = r1 <= 0.0001
	var apex: Vector3 = Vector3(0.0, y1, 0.0)
	for i in range(sides):
		var b0: Vector3 = ring_point(r0, y0, sides, i)
		var b1: Vector3 = ring_point(r0, y0, sides, i + 1)
		if cone_top:
			tri(b0, b1, apex, c0, c0, c1, axis)
		else:
			var t0: Vector3 = ring_point(r1, y1, sides, i)
			var t1: Vector3 = ring_point(r1, y1, sides, i + 1)
			tri(b0, b1, t1, c0, c0, c1, axis)
			tri(b0, t1, t0, c0, c1, c1, axis)
		if cap_bottom:
			tri(Vector3(0.0, y0, 0.0), b0, b1, c0, c0, c0, axis)
		if cap_top and not cone_top:
			var u0: Vector3 = ring_point(r1, y1, sides, i)
			var u1: Vector3 = ring_point(r1, y1, sides, i + 1)
			tri(Vector3(0.0, y1, 0.0), u0, u1, c1, c1, c1, axis)


## Frustum between two arbitrary points (limbs, poles, branches, club shafts).
## Restores the previous transform afterwards.
func tube(p0: Vector3, p1: Vector3, r0: float, r1: float, sides: int, c0: Color, c1: Color,
		cap_bottom: bool = false, cap_top: bool = false) -> void:
	var d: Vector3 = p1 - p0
	var length: float = d.length()
	if length < 0.0001:
		return
	var saved: Transform3D = xf
	xf = saved * Transform3D(basis_y_along(d / length), p0)
	frustum(0.0, length, r0, r1, sides, c0, c1, cap_bottom, cap_top)
	xf = saved


## A basis whose +Y axis is `dir` (unit length). Deterministic for any direction.
static func basis_y_along(dir: Vector3) -> Basis:
	var helper: Vector3 = Vector3(1.0, 0.0, 0.0)
	if absf(dir.x) > 0.9:
		helper = Vector3(0.0, 0.0, 1.0)
	var x_axis: Vector3 = helper.cross(dir).normalized()
	var z_axis: Vector3 = x_axis.cross(dir).normalized()
	return Basis(x_axis, dir, z_axis)


## Axis-aligned box centred at `centre` (in the current transform). `top` colours the +Y face,
## `side` the four sides, `bottom` the -Y face. 12 triangles.
func box(centre: Vector3, size: Vector3, top: Color, side: Color, bottom: Color) -> void:
	var h: Vector3 = size * 0.5
	var x0: float = centre.x - h.x
	var x1: float = centre.x + h.x
	var y0: float = centre.y - h.y
	var y1: float = centre.y + h.y
	var z0: float = centre.z - h.z
	var z1: float = centre.z + h.z
	var p000: Vector3 = Vector3(x0, y0, z0)
	var p100: Vector3 = Vector3(x1, y0, z0)
	var p110: Vector3 = Vector3(x1, y1, z0)
	var p010: Vector3 = Vector3(x0, y1, z0)
	var p001: Vector3 = Vector3(x0, y0, z1)
	var p101: Vector3 = Vector3(x1, y0, z1)
	var p111: Vector3 = Vector3(x1, y1, z1)
	var p011: Vector3 = Vector3(x0, y1, z1)
	quad(p010, p110, p111, p011, top, centre)
	quad(p000, p100, p101, p001, bottom, centre)
	quad(p000, p100, p110, p010, side, centre)
	quad(p001, p101, p111, p011, side, centre)
	quad(p000, p001, p011, p010, side, centre)
	quad(p100, p101, p111, p110, side, centre)


## Low-poly irregular blob (ellipsoid with hashed vertex jitter). `stacks` >= 2 latitude bands,
## `sides` >= 3 around. Triangles: 2 * sides * (stacks - 1). `jitter` is a fraction of the radius.
## Colour blends c_low (bottom) to c_high (top) by height.
func blob(centre: Vector3, radii: Vector3, stacks: int, sides: int, c_low: Color, c_high: Color,
		seed_value: int, jitter: float) -> void:
	var rows: Array = []
	for s in range(stacks + 1):
		var row: Array = []
		var lat: float = PI * float(s) / float(stacks)
		var ring_r: float = sin(lat)
		var y_unit: float = cos(lat)
		if s == 0 or s == stacks:
			var pole_j: float = 1.0 + jitter * MHArtRng.noise2(seed_value, 1000 + s)
			row.append(centre + Vector3(0.0, y_unit * radii.y * pole_j, 0.0))
		else:
			for i in range(sides):
				var ang: float = TAU * float(i) / float(sides)
				var j: float = 1.0 + jitter * MHArtRng.noise2(seed_value, s * 64 + i)
				row.append(centre + Vector3(cos(ang) * ring_r * radii.x * j, y_unit * radii.y * j,
					sin(ang) * ring_r * radii.z * j))
		rows.append(row)
	for s in range(stacks):
		var t_a: float = 1.0 - float(s) / float(stacks)
		var t_b: float = 1.0 - float(s + 1) / float(stacks)
		var col_a: Color = c_low.lerp(c_high, t_a)
		var col_b: Color = c_low.lerp(c_high, t_b)
		var upper: Array = rows[s]
		var lower: Array = rows[s + 1]
		for i in range(sides):
			var i2: int = (i + 1) % sides
			if s == 0:
				tri(upper[0], lower[i2], lower[i], col_a, col_b, col_b, centre)
			elif s == stacks - 1:
				tri(upper[i], upper[i2], lower[0], col_a, col_a, col_b, centre)
			else:
				tri(upper[i], upper[i2], lower[i2], col_a, col_a, col_b, centre)
				tri(upper[i], lower[i2], lower[i], col_a, col_b, col_b, centre)


## Flat disc (triangle fan) facing +Y (or -Y when `facing_up` is false). `sides` triangles.
func disc(centre: Vector3, radius: float, sides: int, col: Color, facing_up: bool = true) -> void:
	var hint: Vector3 = centre + Vector3(0.0, -1.0 if facing_up else 1.0, 0.0)
	for i in range(sides):
		tri(centre, ring_point(radius, centre.y, sides, i) + Vector3(centre.x, 0.0, centre.z),
			ring_point(radius, centre.y, sides, i + 1) + Vector3(centre.x, 0.0, centre.z),
			col, col, col, hint)


func to_mesh() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	if verts.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## FNV-1a style hash of this builder's geometry. Positions are quantised to 1 mm and colours to 1/255
## so that harmless float noise does not change the value. Same code, same seed, same hash.
func geometry_hash() -> int:
	return MHMeshBuilder.hash_arrays(verts, colors, indices)


static func hash_arrays(v: PackedVector3Array, c: PackedColorArray, idx: PackedInt32Array) -> int:
	var h: int = 2166136261
	for p in v:
		h = _mix(h, int(roundf(p.x * 1000.0)))
		h = _mix(h, int(roundf(p.y * 1000.0)))
		h = _mix(h, int(roundf(p.z * 1000.0)))
	for col in c:
		h = _mix(h, int(roundf(col.r * 255.0)))
		h = _mix(h, int(roundf(col.g * 255.0)))
		h = _mix(h, int(roundf(col.b * 255.0)))
		h = _mix(h, int(roundf(col.a * 255.0)))
	for i in idx:
		h = _mix(h, i)
	return h


static func _mix(h: int, value: int) -> int:
	return ((h ^ (value & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF


## Hash of a built mesh (surface 0). Empty mesh hashes to the FNV offset basis.
static func hash_mesh(mesh: ArrayMesh) -> int:
	if mesh.get_surface_count() == 0:
		return 2166136261
	var arrays: Array = mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return MHMeshBuilder.hash_arrays(v, c, idx)


@warning_ignore("integer_division")
static func mesh_tri_count(mesh: ArrayMesh) -> int:
	if mesh.get_surface_count() == 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	return idx.size() / 3


## Axis-aligned bounds of a built mesh (surface 0).
static func mesh_bounds(mesh: ArrayMesh) -> AABB:
	return mesh.get_aabb()
