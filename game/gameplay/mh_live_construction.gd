class_name MHLiveConstruction
extends Node3D
## First Real Round integration scene: terrain, club simulation, finalized/rated hole, player practice and checkpoint.
## The development slot/ledger is isolated from ordinary saves and token balances while this path is hardened.
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
var aim_input: MHPracticeAimInput
var one_hole: MHOneHolePanel
var _status: Label
## Responsive layout (MHLiveLayout zones inside the area the HUD leaves free). See docs/phase1/live_construction.md.
var _dock: Control
var _actions: HFlowContainer
var _action_buttons: Array = []
var _status_zone: PanelContainer
var _panel_frame: PanelContainer
var _layout_key: Array = []
var _pending_save: bool = false
var _active: bool = false
var _last_usec: int = 0
var _resumed_checkpoint: bool = false

func _ready() -> void:
	MHOrientation.apply_game() # No-op off mobile; one switch, see MHOrientation.
	var ledger: MHTokenLedger = MHTokenLedger.new()
	var loaded: MHSaveResult = store.load_slot(0)
	if loaded.is_ok():
		_resumed_checkpoint = true
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
	_dock = Control.new()
	_dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.theme = shell.theme # The dock is a sibling of the shell, so it does not inherit the shell's theme.
	layer.add_child(_dock)
	_actions = MHUIKit.flow(8)
	_dock.add_child(_actions)
	var save_button: MHTapButton = MHUIKit.button(shell.ctx, "Save", &"ChipButton", 96)
	save_button.pressed.connect(_request_save)
	var back: MHTapButton = MHUIKit.button(shell.ctx, "Save & launcher", &"ChipButton", 160)
	back.pressed.connect(_back)
	var play_label: String = "Continue first round" if _resumed_checkpoint and not session.hole_definitions().is_empty() else "Build / play first hole"
	var play: MHTapButton = MHUIKit.button(shell.ctx, play_label, &"ChipButton", 180)
	for b: MHTapButton in [save_button, back, play]:
		_actions.add_child(b)
		_action_buttons.append(b)
	_status_zone = MHUIKit.panel(&"HudChip")
	_status_zone.clip_contents = true
	_dock.add_child(_status_zone)
	_panel_frame = MHUIKit.panel(&"CardPanel")
	_panel_frame.clip_contents = true
	_panel_frame.visible = false
	_dock.add_child(_panel_frame)
	one_hole = MHOneHolePanel.new()
	_panel_frame.add_child(one_hole)
	one_hole.setup(self)
	one_hole.visibility_changed.connect(_on_panel_visibility)
	one_hole.layout_changed.connect(_relayout)
	get_viewport().size_changed.connect(_relayout)
	shell.screen_changed.connect(func(_id: String) -> void: _relayout())
	play.pressed.connect(one_hole.open)
	router.register_ui_region(&"live_practice", _button_rect.bind(play))
	router.register_ui_region(&"live_save", _button_rect.bind(save_button))
	router.register_ui_region(&"live_back", _button_rect.bind(back))
	router.ui_tapped.connect(func(id: StringName) -> void:
		if id == &"live_save": save_button.pressed.emit()
		elif id == &"live_back": back.pressed.emit()
		elif id == &"live_practice": play.pressed.emit()
		else: shell.trigger_region(id))
	# The status label sits in a container with a real width (an autowrap Label directly under a CanvasLayer has
	# zero width and wraps one character per line) and is limited to MHLiveLayout.STATUS_LINES lines.
	_status = MHUIKit.label(_first_round_status(), &"SmallLabel")
	_status.max_lines_visible = MHLiveLayout.STATUS_LINES
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_zone.add_child(_status)
	editor.stroke_began.connect(func() -> void: view.changed.emit())
	editor.stroke_ended.connect(_edited)
	editor.history_applied.connect(_history)
	editor.stroke_cancelled.connect(func() -> void: view.changed.emit())
	session.autosave_requested.connect(_request_save)
	aim_input = MHPracticeAimInput.new()
	aim_input.panel = one_hole
	add_child(aim_input) # Last sibling sees input before the UI bridge; UI contacts remain unconsumed.
	_active = true
	_last_usec = Time.get_ticks_usec()
	_request_save()
	_relayout()

func _first_round_status() -> String:
	if _resumed_checkpoint:
		if session.practice != null:
			return "Checkpoint restored: continue your saved round, or redesign the hole."
		if not session.hole_definitions().is_empty():
			return "Checkpoint restored: your rated hole is ready to play."
		return "Checkpoint restored: continue building your first hole."
	return "First Real Round: build a hole, finalize its rating, play it, then save and return."

func _pick(pos: Vector2) -> Vector2i:
	return MHPicking.pick(editor.grid, controller.camera.project_ray_origin(pos), controller.camera.project_ray_normal(pos), 1500.0)


func validate_building_placement(building_id: String, tier: int, world_m: Vector2) -> Dictionary:
	var existing: Array = []
	for v: Variant in session.building_placements.values():
		existing.append((v as Dictionary).duplicate(true))
	return MHBuildingPlacement.validate(editor.grid, editor.splat, session.land, building_id, tier,
		Vector2i(roundi(world_m.x * 1000.0), roundi(world_m.y * 1000.0)), existing)


func place_building(building_id: String, tier: int, world_m: Vector2) -> Dictionary:
	var result: Dictionary = validate_building_placement(building_id, tier, world_m)
	if not bool(result.get("ok", false)):
		return result
	if not session.set_building_placement(building_id, result):
		return {"ok": false, "reason": "building"}
	_request_save()
	return result

## Rect getter for router UI regions that is empty while the button is hidden (dock hidden, panel closed).
func _button_rect(b: Control) -> Rect2:
	if b == null or not is_instance_valid(b) or not b.is_visible_in_tree():
		return Rect2()
	return b.get_global_rect()

func _on_panel_visibility() -> void:
	if _panel_frame != null and one_hole != null:
		_panel_frame.visible = one_hole.visible
	_layout_key = []
	_relayout()

func _panel_state() -> int:
	if one_hole == null or not one_hole.visible:
		return MHLiveLayout.PanelState.HIDDEN
	return MHLiveLayout.PanelState.COLLAPSED if one_hole.collapsed else MHLiveLayout.PanelState.OPEN

## Places the three zones inside the rectangle the HUD/editor leaves free. Cheap; skips work when nothing changed.
func _relayout() -> void:
	if _dock == null or shell == null or one_hole == null:
		return
	if _dock.theme != shell.theme:
		_dock.theme = shell.theme # Text-size changes build a new theme.
	var on: bool = shell.overlay_active()
	_dock.visible = on
	if not on:
		_layout_key = []
		return
	var free: Rect2 = shell.overlay_free_rect()
	if free.size.x <= 0.0 or free.size.y <= 0.0:
		return # Not laid out yet; the next frame asks again.
	var tm: float = shell.ctx.touch_min()
	var state: int = _panel_state()
	var key: Array = [free, tm, state, shell.ctx.scaled(MHTheme.FONT_SMALL), shell.ctx.left_handed()]
	if key == _layout_key:
		return
	_layout_key = key
	var widths: Array = []
	for b: Variant in _action_buttons:
		widths.append((b as Control).custom_minimum_size.x)
	var line_h: float = ceilf(float(shell.ctx.scaled(MHTheme.FONT_SMALL)) * 1.4)
	var zones: Dictionary = MHLiveLayout.compute(free, tm, line_h, state, widths, shell.ctx.left_handed())
	_place(_actions, zones["actions"] as Rect2)
	_place(_status_zone, zones["status"] as Rect2)
	_place(_panel_frame, zones["panel"] as Rect2)
	_panel_frame.visible = state != MHLiveLayout.PanelState.HIDDEN and (zones["panel"] as Rect2).size.y > 0.0

func _place(c: Control, r: Rect2) -> void:
	c.visible = r.size.x > 0.0 and r.size.y > 0.0
	if c.visible:
		c.position = r.position
		c.size = r.size

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
	_relayout()
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

func _exit_tree() -> void:
	MHOrientation.restore_default()

func _back() -> void:
	if _active:
		router.cancel_world_input()
		if not save_now():
			return
	get_tree().change_scene_to_file(MHLauncher.LAUNCHER_PATH)

func _fail(message: String) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	layer.add_child(margin)
	var box: VBoxContainer = MHUIKit.vbox(12)
	margin.add_child(box)
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
