extends Node3D
## Gate 0 items 4/5 phone scene: 600 x 400 cell terrain, orbit camera, one-finger paint through the gesture
## router, Undo / Redo, brush picker, fps and stroke counters, and a scripted 50-stroke check
## (strokes, undo, redo, cancel, save, load, hashes). See docs/phase0/gate0_scenes.md. NOT YET RUN.

const SAVE_PATH: String = "user://gate0_terrain_paint.mhts"
const BRUSHES: Array = [
	["Raise", MHBrush.Mode.RAISE, 10, 150],
	["Lower", MHBrush.Mode.LOWER, 10, 150],
	["Smooth", MHBrush.Mode.SMOOTH, 10, 500],
	["Flatten", MHBrush.Mode.FLATTEN, 10, 500],
]

var editor: MHTerrainEditor
var chunks: MHTerrainChunks
var sink: MHGate0TerrainSink
var controller: MHCameraController
var router: MHInputRouter
var panel: MHGate0Panel
var stats: MHGate0Stats = MHGate0Stats.new(600)

var _picker: MHCellSentinel.TerrainPicker
var _brush_index: int = 0
var _hud_timer: float = 0.0
var _flush_ms_sum: float = 0.0
var _flush_frames: int = 0
var _last_check: Dictionary = {}
var _check_running: bool = false


func _ready() -> void:
	editor = MHGate0TerrainApi.make_editor(600, 400)
	MHGate0TerrainApi.fill_noise(editor, 1234, 30)
	_add_hills()
	chunks = MHGate0TerrainApi.make_chunks(self, editor)
	sink = MHGate0TerrainSink.new(editor)
	_apply_brush()

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)

	var cfg: MHCameraConfig = MHCameraConfig.new()
	cfg.min_distance = 12.0
	cfg.max_distance = 700.0
	cfg.start_distance = 260.0
	cfg.pan_per_pixel = 0.0015
	controller = MHCameraController.new()
	controller.config = cfg
	add_child(controller)
	controller.rig.target = Vector3(300.0, 0.0, 200.0)
	controller.camera.far = 4000.0
	controller.rig.target = Vector3(300.0, 0.0, 200.0)
	controller.desktop_pan(Vector2.ZERO)  # applies the rig to the camera

	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var overlay: MHDebugOverlay = MHDebugOverlay.new()
	layer.add_child(overlay)
	var compass: MHCompassButton = MHCompassButton.new()
	layer.add_child(compass)
	panel = MHGate0Panel.new()
	panel.own_touch = false
	panel.setup("Gate 0: terrain paint 600 x 400", "terrain_paint", 0.0, 300.0)
	layer.add_child(panel)
	panel.add_action(&"undo", "Undo")
	panel.add_action(&"redo", "Redo")
	panel.add_action(&"brush", "Brush: Raise")
	panel.add_action(&"check", "Run 50-stroke check")
	panel.add_action(&"hide", "Hide report")
	panel.add_action(&"save", "Save")
	panel.add_action(&"load", "Load")
	panel.action.connect(_on_action)
	panel.result_box.visible = false
	panel.set_live("one finger paints, two fingers move the camera")

	_picker = MHCellSentinel.TerrainPicker.new(editor.grid, Callable(self, "_get_camera"))
	router = MHInputRouter.new()
	add_child(router)
	router.setup(controller, compass, overlay, sink, Callable(_picker, "screen_to_cell"))
	var getters: Dictionary = panel.get_button_rect_getters()
	for id: Variant in getters.keys():
		router.register_ui_region(StringName(id), getters[id])
	router.ui_tapped.connect(_on_router_tap)
	MHGate0TerrainApi.mark_all_dirty(editor)


func _get_camera() -> Camera3D:
	return controller.camera


func _add_hills() -> void:
	var state: int = 99
	for i: int in range(10):
		state = MHGate0TerrainCheck.lcg_next(state)
		var x: int = (state >> 8) % 601
		state = MHGate0TerrainCheck.lcg_next(state)
		var y: int = (state >> 8) % 401
		MHBrush.apply_dab(editor.grid, MHBrush.Mode.RAISE, x, y, 40, 5000, 0, null)


func _on_router_tap(region: StringName) -> void:
	if region == &"compass" or region == &"overlay_toggle":
		return
	panel.trigger(region)


func _apply_brush() -> void:
	var b: Array = BRUSHES[_brush_index]
	editor.set_brush(int(b[1]), int(b[2]), int(b[3]))


func _on_action(id: StringName) -> void:
	if id == &"undo":
		sink.undo()
	elif id == &"redo":
		sink.redo()
	elif id == &"brush":
		_brush_index = (_brush_index + 1) % BRUSHES.size()
		_apply_brush()
		panel.set_button_text(&"brush", "Brush: %s" % str((BRUSHES[_brush_index] as Array)[0]))
	elif id == &"hide":
		panel.show_result_box(not panel.result_box.visible)
	elif id == &"check":
		_run_check()
	elif id == &"save":
		var err: int = MHGate0TerrainApi.save_file(SAVE_PATH, editor)
		panel.set_live("saved to %s, error code %d, hash %d" % [SAVE_PATH, err, MHGate0TerrainApi.content_hash(editor)])
	elif id == &"load":
		_load_saved()


func _load_saved() -> void:
	var r: Dictionary = MHGate0TerrainApi.load_file(SAVE_PATH)
	if not bool(r["ok"]):
		panel.set_live("load failed: %s" % str(r["message"]))
		return
	var g: MHHeightGrid = r["grid"] as MHHeightGrid
	var same: bool = MHGate0TerrainApi.grid_equals(editor.grid, g)
	panel.set_live("loaded hash %d, current hash %d, identical: %s" % [int(r["hash"]), MHGate0TerrainApi.content_hash(editor), "yes" if same else "no"])


## The check edits the live terrain (and clears nothing), so run it before painting by hand if you want
## the hashes to start from the generated hills.
func _run_check() -> void:
	if _check_running or editor.is_stroke_open():
		return
	_check_running = true
	panel.set_live("running the scripted check ...")
	panel.show_result_box(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_last_check = MHGate0TerrainCheck.run(editor, MHGate0TerrainCheck.DEFAULT_STROKES, SAVE_PATH)
	MHGate0TerrainApi.mark_all_dirty(editor)
	var text: String = MHGate0Report.header_lines("terrain scripted check") + "\n" + MHGate0TerrainCheck.format_result(_last_check)
	text += "\n\nfps while painting (last window): " + stats.live_line()
	text += "\n\n" + MHGate0Report.to_json(_evidence())
	panel.set_result(text)
	panel.set_live("check finished: %s" % ("PASS" if bool(_last_check["pass"]) else "FAIL"))
	_check_running = false


func _evidence() -> Dictionary:
	var s: Dictionary = stats.summary()
	var fields: Dictionary = {
		"grid_cells": [editor.grid.cells_x, editor.grid.cells_y],
		"scripted_check": _last_check,
		"fps_avg": s["avg_fps"], "frame_p95_ms": s["p95_ms"], "frame_max_ms": s["max_ms"],
		"fps_note": "window of recent frames including idle frames; paint continuously for 30 s before the check for a meaningful figure",
		"strokes_committed_by_hand": sink.strokes_committed, "strokes_cancelled_by_hand": sink.strokes_cancelled,
	}
	var res: String = "pass" if bool(_last_check.get("pass", false)) else "fail"
	return MHGate0Report.evidence_now("05_terrain_android", res, fields)


func _process(delta: float) -> void:
	stats.add(delta * 1000.0)
	var t0: int = Time.get_ticks_usec()
	var uploaded: int = MHGate0TerrainApi.flush(chunks, editor)
	if uploaded > 0:
		_flush_ms_sum += float(Time.get_ticks_usec() - t0) / 1000.0
		_flush_frames += 1
	_hud_timer += delta
	if _hud_timer >= 0.5:
		_hud_timer = 0.0
		var flush_avg: float = _flush_ms_sum / float(_flush_frames) if _flush_frames > 0 else 0.0
		panel.set_live("%s\n%s\nchunk flush avg %.2f ms over %d frames with edits" % [stats.live_line(), sink.counters_text(), flush_avg, _flush_frames])
