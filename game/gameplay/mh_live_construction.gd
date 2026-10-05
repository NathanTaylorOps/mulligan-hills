class_name MHLiveConstruction
extends Node3D
## First live connection: real terrain, clock, economy, menus and exact checkpoint. No finalized golf holes yet.
## Isolated development slot/ledger never overwrite ordinary saves or token balances.
const SAVE_DIR: String = "user://phase1_live/saves"
const LEDGER_DIR: String = "user://phase1_live/ledgers"
const CELLS: int = 128 # Integration surface, not a measured final course/map budget.

## Tests may isolate ledger files as well as their MHSaveStore directory.
var ledger_dir: String = LEDGER_DIR

var session: MHGameSession
var editor: MHTerrainEditor
var shell: MHUIShell
var view: MHLiveGameStateView
var chunks: MHTerrainChunks
var router: MHInputRouter
var controller: MHCameraController
var store: MHSaveStore = MHSaveStore.new(SAVE_DIR)
var document: Dictionary = {}
var one_hole: MHOneHolePanel
var _status: Label
var _pending_save: bool = false
var _active: bool = false
var _last_usec: int = 0

func _ready() -> void:
	var ledger: MHTokenLedger = MHTokenLedger.new()
	var loaded: MHSaveResult = store.load_slot(0)
	if loaded.is_ok():
		var saved: MHLoadedSave = loaded.value as MHLoadedSave
		var ledger_result: MHSaveResult = MHSessionSave.load_ledger(saved.data, ledger_dir)
		if not ledger_result.is_ok():
			_fail("Checkpoint ledger could not load. " + ledger_result.message)
			return
		ledger = ledger_result.value as MHTokenLedger
		var restored: MHSaveResult = MHSessionSave.restore(saved.data, ledger)
		var terrain: MHTerrainSave.LoadResult = MHTerrainSave.decode(saved.blob)
		if not restored.is_ok() or terrain.error != OK:
			_fail("Checkpoint could not load. " + restored.message + " " + terrain.message)
			return
		session = restored.value as MHGameSession
		document = saved.data.duplicate(true)
		editor = MHTerrainEditor.new(terrain.grid, terrain.splat, 32)
	elif loaded.code == MHSaveResult.Code.NOT_FOUND:
		session = MHGameSession.create()
		if session == null:
			_fail("Game data could not load.")
			return
		session.ledger = ledger
		var grid: MHHeightGrid = MHHeightGrid.new(CELLS, CELLS, 1000)
		editor = MHTerrainEditor.new(grid, MHSplatMap.new(grid.samples_x, grid.samples_y), 32)
		document = _new_document()
	else:
		_fail("Checkpoint could not load; existing files were kept. " + loaded.message)
		return
	if not MHOneHolePanel.supported(document["course"] as Dictionary):
		_fail("This development view cannot display that hole layout. Existing files were kept.")
		return
	chunks = MHTerrainChunks.new()
	add_child(chunks)
	chunks.setup(editor.grid, editor.splat, 32)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var cfg: MHCameraConfig = MHCameraConfig.new()
	cfg.min_distance = 12.0
	cfg.max_distance = 400.0
	cfg.start_distance = 150.0
	controller = MHCameraController.new()
	controller.config = cfg
	add_child(controller)
	controller.rig.target = Vector3(64, 0, 64)
	controller.desktop_pan(Vector2.ZERO)
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var compass: MHCompassButton = MHCompassButton.new()
	var debug: MHDebugOverlay = MHDebugOverlay.new()
	layer.add_child(compass)
	layer.add_child(debug)
	compass.hide()
	debug.hide()
	router = MHInputRouter.new()
	add_child(router)
	router.setup(controller, compass, debug, MHLiveTerrainSink.new(editor), Callable(self, "_pick"))
	router.register_ui_region(&"compass", func() -> Rect2: return Rect2())
	router.register_ui_region(&"overlay_toggle", func() -> Rect2: return Rect2())
	view = MHLiveGameStateView.new(session)
	view.editor = editor
	shell = MHUIShell.new()
	layer.add_child(shell) # Its touch bridge receives UI taps before the world router.
	var settings: MHUISettings = MHUISettings.new()
	settings.load_from()
	shell.setup(view, settings)
	router.world_input_allowed = func() -> bool: return shell.current_screen_id() == MHScreenIds.EDITOR and shell.modal_id() == "" and (one_hole == null or not one_hole.visible)
	shell.intent.connect(_on_intent)
	shell.screen_changed.connect(_screen_changed)
	shell.show_root(MHScreenIds.HUD)
	var bar: HFlowContainer = MHUIKit.flow(6)
	bar.position = Vector2(8, 180)
	layer.add_child(bar)
	var save_button: MHTapButton = MHUIKit.button(shell.ctx, "Save", &"ChipButton", 96)
	save_button.pressed.connect(_request_save)
	bar.add_child(save_button)
	var back: MHTapButton = MHUIKit.button(shell.ctx, "Save & launcher", &"ChipButton", 160)
	back.pressed.connect(_back)
	bar.add_child(back)
	var play: MHTapButton = MHUIKit.button(shell.ctx, "Build / play one hole", &"ChipButton", 180)
	bar.add_child(play)
	one_hole = MHOneHolePanel.new()
	layer.add_child(one_hole)
	one_hole.setup(self)
	play.pressed.connect(one_hole.open)
	router.register_ui_region(&"live_practice", Callable(play, "get_global_rect"))
	router.register_ui_region(&"live_save", Callable(save_button, "get_global_rect"))
	router.register_ui_region(&"live_back", Callable(back, "get_global_rect"))
	router.ui_tapped.connect(func(id: StringName) -> void:
		if id == &"live_save": save_button.pressed.emit()
		elif id == &"live_back": back.pressed.emit()
		elif id == &"live_practice": play.pressed.emit()
		else: shell.trigger_region(id))
	_status = MHUIKit.label("Live construction: ground edits are separate from the exact Build / play one hole layout.")
	_status.position = Vector2(8, 245)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_status)
	editor.stroke_began.connect(func() -> void: view.changed.emit())
	editor.stroke_ended.connect(_edited)
	editor.history_applied.connect(_history)
	editor.stroke_cancelled.connect(func() -> void: view.changed.emit())
	session.autosave_requested.connect(_request_save)
	_active = true
	_last_usec = Time.get_ticks_usec()
	_request_save()

func _pick(pos: Vector2) -> Vector2i:
	return MHPicking.pick(editor.grid, controller.camera.project_ray_origin(pos), controller.camera.project_ray_normal(pos), 1500.0)

func _screen_changed(id: String) -> void:
	if router == null:
		return
	router.accept_world_input = id == MHScreenIds.EDITOR and shell.modal_id() == "" and (one_hole == null or not one_hole.visible)
	if not router.accept_world_input:
		router.cancel_world_input()
	for region: Variant in shell.region_rects().keys():
		router.register_ui_region(StringName(region), _region_rect.bind(StringName(region)))

func _region_rect(id: StringName) -> Rect2:
	var getters: Dictionary = shell.region_rects()
	if not getters.has(id):
		return Rect2()
	var getter: Callable = getters[id]
	return getter.call()

func _on_intent(id: StringName, args: Dictionary) -> void:
	if id == &"editor_tool":
		var mode: int = int(args.get("brush_mode", MHBrush.Mode.RAISE))
		var radius: int = int(args.get("radius", 8))
		if mode == MHBrush.Mode.PAINT:
			editor.set_paint_brush(int(args.get("surface_layer", 1)), radius, 1000)
		else:
			editor.set_brush(mode, radius, 300 if mode <= MHBrush.Mode.LOWER else 500)
	elif id == &"editor_undo":
		editor.undo()
	elif id == &"editor_redo":
		editor.redo()
	else:
		var result: Dictionary = session.handle_intent(id, args)
		if bool(result.get("handled", false)):
			if bool(result.get("ok", false)):
				_request_save()
			elif _status != null:
				_status.text = "Action unavailable: " + str(result.get("reason", ""))

func _edited(_count: int) -> void:
	view.changed.emit()
	_request_save()

func _history(_undo: bool) -> void:
	view.changed.emit()
	_request_save()

func _request_save() -> void:
	_pending_save = true

func save_now() -> bool:
	if not _active or editor.is_stroke_open():
		return false
	_pending_save = false # Failed writes require an explicit retry; never retry every frame.
	var captured: MHSaveResult = MHSessionSave.capture(session, document)
	if not captured.is_ok():
		_status.text = "Save failed: " + captured.message
		return false
	# Immutable separate ledger generation first: a failed world write cannot destroy the old pair.
	var ledger_hash: String = str((captured.value as Dictionary)["runtime"]["ledger_hash"])
	var token_error: int = session.ledger.save_to(ledger_dir + "/" + ledger_hash + ".json")
	if token_error != OK:
		_status.text = "Token save failed: " + str(token_error)
		return false
	var saved: MHSaveResult = store.autosave(captured.value as Dictionary,
		MHTerrainSave.encode(editor.grid, editor.splat), session.unix_now)
	if not saved.is_ok():
		_status.text = "Save failed: " + saved.message
		return false
	var summary: MHSaveSummary = saved.value as MHSaveSummary
	document = (captured.value as Dictionary).duplicate(true)
	document["revision"] = summary.revision
	document["saved_at_unix"] = summary.saved_at_unix
	_pending_save = false
	_status.text = "Saved: ground, club and exact hole/practice state."
	return true

func _process(_delta: float) -> void:
	if not _active:
		return
	var now: int = Time.get_ticks_usec()
	var elapsed: int = maxi(0, now - _last_usec)
	_last_usec = now
	session.advance(elapsed, int(Time.get_unix_time_from_system()))
	chunks.flush(editor.dirty)
	router.accept_world_input = shell.current_screen_id() == MHScreenIds.EDITOR and shell.modal_id() == "" and (one_hole == null or not one_hole.visible)
	if not router.accept_world_input:
		router.cancel_world_input()
	if _pending_save and not editor.is_stroke_open():
		save_now()

func _notification(what: int) -> void:
	if not _active:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		router.cancel_world_input()
		save_now()

func _back() -> void:
	if _active:
		router.cancel_world_input()
		if not save_now():
			return
	get_tree().change_scene_to_file(MHLauncher.LAUNCHER_PATH)

func _fail(message: String) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var box: VBoxContainer = VBoxContainer.new()
	layer.add_child(box)
	box.add_child(MHUIKit.label(message))
	var back: MHTapButton = MHTapButton.new()
	back.text = "Back to launcher"
	back.custom_minimum_size = Vector2(200, 64)
	back.pressed.connect(_back)
	box.add_child(back)
	box.add_child(MHTouchBridge.new())

func _new_document() -> Dictionary:
	var parcels: Array = []
	for p: Variant in session.defs.land_config()["parcels"]:
		var row: Dictionary = p
		var x: int = int(row["col"]) * 320
		var y: int = int(row["row"]) * 320
		parcels.append({"parcel_id": int(row["id"]), "x0": x, "y0": y, "x1": x + 319,
			"y1": y + 319, "owned": session.land.is_owned(int(row["id"]))})
	return {"schema": "mh.save", "save_version": 1, "min_reader_version": 2,
		"written_by": {"app_version": "0.1.0", "sim_version": "MHSIM-1.0.0",
			"rating_version": MHRatingEngine.RATING_VERSION, "platform": "test"},
		"slot": 0, "slot_kind": "autosave", "revision": 0, "saved_at_unix": 0,
		"install_id": "00000000-0000-0000-0000-000000000001", "mode": "standard",
		"checksum": {"alg": "sha256", "value": "0".repeat(64)},
		"world": {"day": 0, "minute_of_day": 0, "season": "spring"},
		"club": {"name_preset_id": 0, "cash": 0, "lifetime_earned": 0, "green_fee": 35,
			"members": 0, "reputation": 1000, "prestige": 0,
			"staff": {"greenkeepers": 0, "marshals": 0, "pro_shop_staff": 0, "caterers": 0}},
		"buildings": [], "land": {"owned_parcel_ids": []},
		"course": {"schema": "mh.course", "schema_version": 1,
			"rating_engine_version": MHRatingEngine.RATING_VERSION,
			"course_id": "00000000-0000-0000-0000-000000000002", "name_preset_id": 0,
			"world": {"width_dm": 1280, "height_dm": 1280, "parcels": parcels},
			"terrain": {"format_version": MHTerrainSave.VERSION, "file": "slot_0.mhts", "content_hash": "00000000",
				"width_cells": CELLS, "height_cells": CELLS, "cell_size_dm": 10, "height_unit_mm": 1,
				"height_min_mm": -32768, "height_max_mm": 32767, "surface_layers": MHSplatMap.LAYER_NAMES.duplicate()},
			"holes": [], "objects": [], "paths": []},
		"sim": {"rating_epoch": 0, "rng_seed": "0000000000000000", "rng_inc": "0000000000000001", "golfer_serial": 0},
		"ratings": {"rating_version": MHRatingEngine.RATING_VERSION, "computed_day": 0, "course_score": 0, "holes": []},
		"progress": {"tutorial_step": 0, "achievements": [], "tournaments": {"hosted_levels": [], "cooldown_until_day": 0}}}
