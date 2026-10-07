class_name MHTerrainGridOverlay
extends Node3D
## Lightweight default-on course-wide design grid.
##
## The 2-yard lattice is anchored to the same origin as MHCraftHole. It is a
## visual overlay only: it neither replaces the shared 1 m terrain nor changes
## saves, picking, pathing, rating or physics. Updating height-following lines
## is throttled during strokes so brush performance is not dominated by redraws.

const STEP_M: float = 1.8288 # Two yards, exactly.
const SURFACE_LIFT_M: float = 0.085
const REDRAW_INTERVAL_MS: int = 120

var grid: MHHeightGrid
var origin_m: Vector2 = Vector2(48.0, 34.0)
var _instance: MeshInstance3D
var _dirty: bool = false
var _last_draw_ms: int = -REDRAW_INTERVAL_MS


func setup(p_grid: MHHeightGrid, p_origin_m: Vector2 = Vector2(48.0, 34.0)) -> void:
	grid = p_grid
	origin_m = p_origin_m
	if _instance == null:
		_instance = MeshInstance3D.new()
		_instance.name = "CourseEditGrid"
		_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_instance)
	request_refresh()
	refresh_now()


func request_refresh() -> void:
	_dirty = true


func refresh_now() -> void:
	if grid == null or _instance == null:
		return
	_rebuild()
	_dirty = false
	_last_draw_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if not _dirty or not visible:
		return
	if Time.get_ticks_msec() - _last_draw_ms >= REDRAW_INTERVAL_MS:
		refresh_now()


func _height_m(x: float, z: float) -> float:
	var step: float = float(grid.cell_size_mm) * 0.001
	var fx: float = clampf(x / step, 0.0, float(grid.cells_x))
	var fz: float = clampf(z / step, 0.0, float(grid.cells_y))
	var ix: int = floori(fx)
	var iz: int = floori(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	var h00: float = float(grid.get_h_clamped(ix, iz))
	var h10: float = float(grid.get_h_clamped(ix + 1, iz))
	var h01: float = float(grid.get_h_clamped(ix, iz + 1))
	var h11: float = float(grid.get_h_clamped(ix + 1, iz + 1))
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz) * 0.001


func _vertex(x: float, z: float) -> Vector3:
	return Vector3(x, _height_m(x, z) + SURFACE_LIFT_M, z)


func _rebuild() -> void:
	var width_m: float = float(grid.cells_x * grid.cell_size_mm) * 0.001
	var depth_m: float = float(grid.cells_y * grid.cell_size_mm) * 0.001
	var sample_m: float = float(grid.cell_size_mm) * 0.001
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	var x_start: int = ceili(-origin_m.x / STEP_M)
	var x_end: int = floori((width_m - origin_m.x) / STEP_M)
	for xi: int in range(x_start, x_end + 1):
		var x: float = origin_m.x + float(xi) * STEP_M
		for iz: int in range(grid.cells_y):
			var z0: float = float(iz) * sample_m
			var z1: float = float(iz + 1) * sample_m
			st.add_vertex(_vertex(x, z0))
			st.add_vertex(_vertex(x, z1))
	var z_start: int = ceili(-origin_m.y / STEP_M)
	var z_end: int = floori((depth_m - origin_m.y) / STEP_M)
	for zi: int in range(z_start, z_end + 1):
		var z: float = origin_m.y + float(zi) * STEP_M
		for ix: int in range(grid.cells_x):
			var x0: float = float(ix) * sample_m
			var x1: float = float(ix + 1) * sample_m
			st.add_vertex(_vertex(x0, z))
			st.add_vertex(_vertex(x1, z))
	var mesh: ArrayMesh = st.commit()
	_instance.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.12, 0.08, 0.36)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_instance.material_override = mat
