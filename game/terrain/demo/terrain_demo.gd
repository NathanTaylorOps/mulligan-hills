extends Node3D
## Desktop demo. Left drag = raise, right drag or Shift+left drag = lower.
## 1 raise, 2 lower, 3 smooth, 4 flatten. [ and ] change radius. Ctrl+Z undo, Ctrl+Y redo.
## Esc during a drag cancels the stroke. F5 save, F9 load (user://demo_terrain.mhts).
## WASD move camera, Q/E down/up. Stats are printed at each stroke end and shown top-left.

const CELLS: int = 512
const SAVE_PATH: String = "user://demo_terrain.mhts"

var editor: MHTerrainEditor
var chunks: MHTerrainChunks
var camera: Camera3D
var label: Label
var _dragging: bool = false
var _last_cell: Vector2i = Vector2i(-1, -1)
var _stroke_usec: int = 0
var _stroke_dabs: int = 0
var _last_summary: String = ""


func _ready() -> void:
	var grid := MHHeightGrid.new(CELLS, CELLS, 1000)
	var splat := MHSplatMap.new(grid.samples_x, grid.samples_y)
	editor = MHTerrainEditor.new(grid, splat, 32)
	# Initial hills: direct dabs with no stroke (not undoable). LCG so it is deterministic.
	var state: int = 12345
	for i in range(14):
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var x: int = (state >> 8) % CELLS
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		var y: int = (state >> 8) % CELLS
		MHBrush.apply_dab(grid, MHBrush.Mode.RAISE, x, y, 45, 6000, 0, null)
	splat.paint_disc(256, 256, 60, MHSplatMap.Layer.FAIRWAY, 1000)
	chunks = MHTerrainChunks.new()
	add_child(chunks)
	chunks.setup(grid, splat, 32)

	camera = Camera3D.new()
	camera.far = 3000.0
	add_child(camera)
	camera.position = Vector3(256.0, 140.0, 470.0)
	camera.look_at(Vector3(256.0, 0.0, 256.0), Vector3.UP)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(8.0, 8.0)
	layer.add_child(label)
	editor.stroke_ended.connect(_on_stroke_ended)
	print("MH terrain demo: %d chunks, grid hash %d" % [chunks.chunk_count(), grid.hash_fnv1a()])


func _on_stroke_ended(changed: int) -> void:
	_last_summary = "last stroke: %d dabs, %d cells changed, %.2f ms brush+flush total" % [
		_stroke_dabs, changed, float(_stroke_usec) / 1000.0]
	print(_last_summary, " | undo=", editor.undo_stack.undo_count(),
		" undo_bytes=", editor.undo_stack.undo_bytes(), " hash=", editor.grid.hash_fnv1a())


func _cell_under_mouse() -> Vector2i:
	var mp: Vector2 = get_viewport().get_mouse_position()
	return MHPicking.pick(editor.grid, camera.project_ray_origin(mp), camera.project_ray_normal(mp), 1500.0)


func _dab_to(cell: Vector2i) -> void:
	if cell == MHPicking.MISS:
		return
	var t0: int = Time.get_ticks_usec()
	if _last_cell == MHPicking.MISS:
		editor.apply_brush_at(cell.x, cell.y)
		_stroke_dabs += 1
	else:
		editor.apply_brush_segment(_last_cell.x, _last_cell.y, cell.x, cell.y)
		_stroke_dabs += 1
	_last_cell = cell
	chunks.flush(editor.dirty)
	_stroke_usec += Time.get_ticks_usec() - t0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed and not _dragging:
				var lower: bool = mb.button_index == MOUSE_BUTTON_RIGHT or Input.is_key_pressed(KEY_SHIFT)
				if lower:
					editor.brush_mode = MHBrush.Mode.LOWER
				elif editor.brush_mode == MHBrush.Mode.LOWER:
					editor.brush_mode = MHBrush.Mode.RAISE
				_dragging = editor.begin_stroke()
				_stroke_usec = 0
				_stroke_dabs = 0
				_last_cell = MHPicking.MISS
				_dab_to(_cell_under_mouse())
			elif not mb.pressed and _dragging:
				_dragging = false
				editor.end_stroke()
	elif event is InputEventMouseMotion and _dragging:
		_dab_to(_cell_under_mouse())
	elif event is InputEventKey:
		var k: InputEventKey = event
		if not k.pressed or k.echo:
			return
		if k.keycode == KEY_ESCAPE and _dragging:
			_dragging = false
			editor.cancel_stroke()
			chunks.flush(editor.dirty)
		elif k.keycode == KEY_Z and k.ctrl_pressed:
			if k.shift_pressed:
				editor.redo()
			else:
				editor.undo()
			chunks.flush(editor.dirty)
		elif k.keycode == KEY_Y and k.ctrl_pressed:
			editor.redo()
			chunks.flush(editor.dirty)
		elif k.keycode == KEY_1:
			editor.set_brush(MHBrush.Mode.RAISE, editor.brush_radius, 300)
		elif k.keycode == KEY_2:
			editor.set_brush(MHBrush.Mode.LOWER, editor.brush_radius, 300)
		elif k.keycode == KEY_3:
			editor.set_brush(MHBrush.Mode.SMOOTH, editor.brush_radius, 500)
		elif k.keycode == KEY_4:
			editor.set_brush(MHBrush.Mode.FLATTEN, editor.brush_radius, 500)
		elif k.keycode == KEY_5:
			editor.set_paint_brush(MHSplatMap.Layer.BUNKER_SAND, editor.brush_radius, 600)
		elif k.keycode == KEY_BRACKETLEFT:
			editor.brush_radius = maxi(1, editor.brush_radius - 2)
		elif k.keycode == KEY_BRACKETRIGHT:
			editor.brush_radius = mini(64, editor.brush_radius + 2)
		elif k.keycode == KEY_F5:
			var t0: int = Time.get_ticks_usec()
			var err: int = MHTerrainSave.save_to_file(SAVE_PATH, editor.grid, editor.splat)
			print("save err=", err, " ms=", float(Time.get_ticks_usec() - t0) / 1000.0)
		elif k.keycode == KEY_F9:
			var t1: int = Time.get_ticks_usec()
			var res: MHTerrainSave.LoadResult = MHTerrainSave.load_with_fallback(SAVE_PATH)
			print("load err=", res.error, " ", res.message, " ms=", float(Time.get_ticks_usec() - t1) / 1000.0)
			if res.error == OK:
				editor.grid.heights = res.grid.heights
				editor.splat.bytes = res.splat.bytes
				editor.undo_stack.clear()
				editor.mark_all_dirty()
				chunks.flush(editor.dirty)


func _process(delta: float) -> void:
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		v.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		v.z += 1.0
	if Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_key_pressed(KEY_Q):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_E):
		v.y += 1.0
	camera.position += v * 80.0 * delta
	var modes: Array[String] = ["raise", "lower", "smooth", "flatten", "paint"]
	label.text = "FPS %d | mode %s r=%d s=%d | chunks flushed %d texels %d %.2f ms\nundo %d redo %d bytes %d\n%s" % [
		Engine.get_frames_per_second(), modes[editor.brush_mode], editor.brush_radius, editor.brush_strength,
		chunks.last_flush_chunks, chunks.last_flush_texels, float(chunks.last_flush_usec) / 1000.0,
		editor.undo_stack.undo_count(), editor.undo_stack.redo_count(), editor.undo_stack.undo_bytes(), _last_summary]
