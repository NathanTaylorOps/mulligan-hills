class_name MHTerrainChunks
extends Node3D
## Chunked terrain renderer. See docs/phase0/terrain.md.
## - One shared ArrayMesh (chunk_size+1)^2 vertices, flat, reused by every chunk MeshInstance3D.
## - Each chunk has its own small height texture (RG8, (chunk_size+3)^2 texels) and splat texture
##   (3 x RGBA8, same size, 11 layers, see MHSplatMap) and its own ShaderMaterial. Vertex shader displaces from the height texture.
## - Updates: only chunks reported dirty are touched; only the dirty rect is rewritten in the CPU byte
##   buffer; then Image.set_data + ImageTexture.update on that chunk's small texture (about 2.4 KB height,
##   14.7 KB splat (3 textures) at chunk_size 32). Godot's ImageTexture.update takes a whole image, so "region update"
##   here means "small per-chunk texture", not a sub-rectangle GPU upload.
## - Seams: adjacent chunks sample identical texels for shared edge vertices and share one-texel borders
##   for normals, so there are no cracks. No LOD, therefore no skirts.
## Grid cells need not be a multiple of chunk_size: the last chunk row/column is partial and its
## texels past the grid edge are clamped copies of the edge sample (600 / 32 = 18.75 -> 19 chunks).

const SHADER_PATH: String = "res://terrain/terrain.gdshader"

var chunk_size: int = 32
var cell_size_m: float = 1.0
var chunks_x: int = 0
var chunks_y: int = 0
var tex_n: int = 35

var _grid: MHHeightGrid
var _splat: MHSplatMap
var _mesh: ArrayMesh
var _hbuf: Array[PackedByteArray] = []
var _himg: Array[Image] = []
var _htex: Array[ImageTexture] = []
var _sbuf: Array[PackedByteArray] = []
var _simg: Array[Image] = []
var _stex: Array[ImageTexture] = []
var _instances: Array[MeshInstance3D] = []

var last_flush_chunks: int = 0
var last_flush_texels: int = 0
var last_flush_usec: int = 0


@warning_ignore("integer_division")
func setup(grid: MHHeightGrid, splat: MHSplatMap, p_chunk_size: int = 32) -> void:
	_grid = grid
	_splat = splat
	chunk_size = maxi(p_chunk_size, 1)
	cell_size_m = float(grid.cell_size_mm) * 0.001
	tex_n = chunk_size + 3
	chunks_x = (grid.cells_x + chunk_size - 1) / chunk_size
	chunks_y = (grid.cells_y + chunk_size - 1) / chunk_size
	_mesh = _build_grid_mesh()
	var shader: Shader = load(SHADER_PATH) as Shader
	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var hb := PackedByteArray()
			hb.resize(tex_n * tex_n * 2)
			_hbuf.append(hb)
			for _p in range(MHSplatMap.TEXTURE_COUNT):
				var sb := PackedByteArray()
				sb.resize(tex_n * tex_n * 4)
				_sbuf.append(sb)
			_write_rect(cx, cy, 0, 0, tex_n - 1, tex_n - 1)
			var cidx: int = cy * chunks_x + cx
			var himg: Image = Image.create_from_data(tex_n, tex_n, false, Image.FORMAT_RG8, hb)
			var htex: ImageTexture = ImageTexture.create_from_image(himg)
			_himg.append(himg)
			_htex.append(htex)
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("height_tex", htex)
			for p in range(MHSplatMap.TEXTURE_COUNT):
				var simg: Image = Image.create_from_data(tex_n, tex_n, false, Image.FORMAT_RGBA8, _sbuf[cidx * 3 + p])
				var stex: ImageTexture = ImageTexture.create_from_image(simg)
				_simg.append(simg)
				_stex.append(stex)
				mat.set_shader_parameter("splat_tex%d" % p, stex)
			mat.set_shader_parameter("cell_size_m", cell_size_m)
			mat.set_shader_parameter("tex_size", float(tex_n))
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [cx, cy]
			mi.mesh = _mesh
			mi.material_override = mat
			mi.position = Vector3(float(cx * chunk_size) * cell_size_m, 0.0, float(cy * chunk_size) * cell_size_m)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			_instances.append(mi)


func set_condition_overlay(condition: Array, pest: Array, cols: int = 4, rows: int = 4) -> void:
	# Presentation only. Never rewrite splat/height data for simulated maintenance condition.
	if condition.size() < cols * rows or pest.size() < cols * rows or _instances.is_empty():
		return
	for cy: int in range(chunks_y):
		for cx: int in range(chunks_x):
			var cidx: int = cy * chunks_x + cx
			var center_x: int = mini(_grid.cells_x - 1, cx * chunk_size + mini(chunk_size / 2, maxi(0, _grid.cells_x - cx * chunk_size - 1)))
			var center_y: int = mini(_grid.cells_y - 1, cy * chunk_size + mini(chunk_size / 2, maxi(0, _grid.cells_y - cy * chunk_size - 1)))
			var parcel: int = MHStaffGrounds.parcel_of_cell(center_x, center_y, _grid.cells_x, _grid.cells_y, cols, rows)
			if parcel < 0:
				continue
			var cond: float = clampf(float(int(condition[parcel])) / 1000.0, 0.0, 1.0)
			var pest_level: float = clampf(float(int(pest[parcel])) / 1000.0, 0.0, 1.0)
			var mat: ShaderMaterial = _instances[cidx].material_override as ShaderMaterial
			if mat != null:
				mat.set_shader_parameter("condition_health", cond)
				mat.set_shader_parameter("condition_pest", pest_level)


func chunk_count() -> int:
	return chunks_x * chunks_y


func _build_grid_mesh() -> ArrayMesh:
	var n: int = chunk_size + 1
	var verts := PackedVector3Array()
	verts.resize(n * n)
	for j in range(n):
		for i in range(n):
			verts[j * n + i] = Vector3(float(i), 0.0, float(j))
	var idx := PackedInt32Array()
	for j in range(chunk_size):
		for i in range(chunk_size):
			var a: int = j * n + i
			var b: int = a + 1
			var c: int = a + n
			var d: int = c + 1
			# Clockwise seen from above (+y): a-b-c and b-d-c.
			idx.append(a)
			idx.append(b)
			idx.append(c)
			idx.append(b)
			idx.append(d)
			idx.append(c)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Heights are int16 mm, so displacement is within +-32.8 m. Custom AABB keeps culling correct.
	m.custom_aabb = AABB(Vector3(0.0, -33.0, 0.0),
			Vector3(float(chunk_size) * cell_size_m, 66.0, float(chunk_size) * cell_size_m))
	return m


## Rewrites texels [tx0..tx1] x [ty0..ty1] of chunk (cx, cy) in the CPU byte buffers.
func _write_rect(cx: int, cy: int, tx0: int, ty0: int, tx1: int, ty1: int) -> void:
	var c: int = cy * chunks_x + cx
	var hb: PackedByteArray = _hbuf[c]
	var sx: int = _grid.samples_x
	var sy: int = _grid.samples_y
	for ty in range(ty0, ty1 + 1):
		var gy: int = clampi(cy * chunk_size + ty - 1, 0, sy - 1)
		for tx in range(tx0, tx1 + 1):
			var gx: int = clampi(cx * chunk_size + tx - 1, 0, sx - 1)
			var si: int = gy * sx + gx
			var u: int = _grid.heights[si] + 32768
			var o: int = (ty * tex_n + tx) * 2
			hb[o] = u >> 8
			hb[o + 1] = u & 255
			var so: int = (ty * tex_n + tx) * 4
			var sso: int = si * MHSplatMap.LAYER_COUNT
			for p in range(MHSplatMap.TEXTURE_COUNT):
				var sb: PackedByteArray = _sbuf[c * 3 + p]
				for ch in range(4):
					var layer: int = p * 4 + ch
					sb[so + ch] = _splat.bytes[sso + layer] if layer < MHSplatMap.LAYER_COUNT else 0
				_sbuf[c * 3 + p] = sb
	# hb and sb are the same objects stored in the arrays (typed arrays hold references),
	# but write back explicitly so correctness does not depend on that.
	_hbuf[c] = hb


## Uploads every dirty chunk reported by the tracker (and clears it). Call once per frame.
@warning_ignore("integer_division")
func flush(tracker: MHDirtyTracker) -> void:
	var t0: int = Time.get_ticks_usec()
	var entries: PackedInt32Array = tracker.take()
	var texels: int = 0
	var count: int = entries.size() / 5
	for k in range(count):
		var c: int = entries[k * 5]
		var x0: int = entries[k * 5 + 1]
		var y0: int = entries[k * 5 + 2]
		var x1: int = entries[k * 5 + 3]
		var y1: int = entries[k * 5 + 4]
		var cx: int = c % chunks_x
		var cy: int = c / chunks_x
		var tx0: int = x0 - cx * chunk_size + 1
		var ty0: int = y0 - cy * chunk_size + 1
		var tx1: int = x1 - cx * chunk_size + 1
		var ty1: int = y1 - cy * chunk_size + 1
		# Border texels outside the grid are clamped duplicates of the edge sample.
		if x0 == 0:
			tx0 = 0
		if y0 == 0:
			ty0 = 0
		if x1 == _grid.samples_x - 1:
			tx1 = tex_n - 1
		if y1 == _grid.samples_y - 1:
			ty1 = tex_n - 1
		tx0 = clampi(tx0, 0, tex_n - 1)
		ty0 = clampi(ty0, 0, tex_n - 1)
		tx1 = clampi(tx1, 0, tex_n - 1)
		ty1 = clampi(ty1, 0, tex_n - 1)
		_write_rect(cx, cy, tx0, ty0, tx1, ty1)
		texels += (tx1 - tx0 + 1) * (ty1 - ty0 + 1)
		_himg[c].set_data(tex_n, tex_n, false, Image.FORMAT_RG8, _hbuf[c])
		_htex[c].update(_himg[c])
		for p in range(MHSplatMap.TEXTURE_COUNT):
			_simg[c * 3 + p].set_data(tex_n, tex_n, false, Image.FORMAT_RGBA8, _sbuf[c * 3 + p])
			_stex[c * 3 + p].update(_simg[c * 3 + p])
	last_flush_chunks = count
	last_flush_texels = texels
	last_flush_usec = Time.get_ticks_usec() - t0
