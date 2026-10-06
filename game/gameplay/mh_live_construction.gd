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
var building_input: MHBuildingPlacementInput
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
var _placement_id: String = ""
var _placement_tier: int = 1
var _placement_rotation: int = 0
var _placement_ghost: MeshInstance3D
var _placement_status: Label
var _placement_last: Dictionary = {}
var _placement_controls: HFlowContainer
var _ghost_valid_mat: StandardMaterial3D
var _ghost_invalid_mat: StandardMaterial3D
var _placed_buildings_root: Node3D
var _placed_building_nodes: Dictionary = {}
var _building_mat: StandardMaterial3D
var _building_mesh_cache: Dictionary = {}
var _visible_golfers: MHSliceGolfers
var _facility_walkers: Dictionary = {}

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
		if not _revalidate_restored_buildings():
			_fail("Checkpoint building placements no longer match terrain, ownership or course geometry.")
			return
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
	_placed_buildings_root = Node3D.new()
	_placed_buildings_root.name = "PlacedBuildings"
	add_child(_placed_buildings_root)
	_building_mat = MHArtMaterials.vertex_color()
	_visible_golfers = MHSliceGolfers.new()
	_visible_golfers.name = "VisibleGolfers"
	add_child(_visible_golfers)
	_visible_golfers.setup(_building_mat)
	_visible_golfers.terrain_grid = editor.grid
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
	var world_center_x: float = float(editor.grid.cells_x * editor.grid.cell_size_mm) / 2000.0
	var world_center_z: float = float(editor.grid.cells_y * editor.grid.cell_size_mm) / 2000.0
	controller.rig.target = Vector3(world_center_x, 0.0, world_center_z)
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
	router.world_input_allowed = func() -> bool: return _placement_id == "" and shell.current_screen_id() == MHScreenIds.EDITOR and shell.modal_id() == "" and (one_hole == null or not one_hole.visible)
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
	var build: MHTapButton = MHUIKit.button(shell.ctx, "Place building", &"ChipButton", 150)
	_actions.add_child(build)
	_action_buttons.append(build)
	build.pressed.connect(_begin_first_owned_building)
	_placement_controls = MHUIKit.flow(6)
	_status_zone.add_child(_placement_controls)
	var rotate_b: MHTapButton = MHUIKit.button(shell.ctx, "Rotate", &"ChipButton", 105)
	var confirm_b: MHTapButton = MHUIKit.button(shell.ctx, "Confirm", &"ChipButton", 105)
	var cancel_b: MHTapButton = MHUIKit.button(shell.ctx, "Cancel", &"ChipButton", 105)
	_placement_controls.add_child(rotate_b); _placement_controls.add_child(confirm_b); _placement_controls.add_child(cancel_b)
	rotate_b.pressed.connect(rotate_building_preview)
	confirm_b.pressed.connect(confirm_building_preview)
	cancel_b.pressed.connect(cancel_building_preview)
	_placement_controls.hide()
	_ghost_valid_mat = StandardMaterial3D.new()
	_ghost_valid_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.45)
	_ghost_valid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_invalid_mat = StandardMaterial3D.new()
	_ghost_invalid_mat.albedo_color = Color(1.0, 0.2, 0.2, 0.45)
	_ghost_invalid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	_placement_status = MHUIKit.label("", &"SmallLabel")
	_status_zone.add_child(_placement_status)
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
	building_input = MHBuildingPlacementInput.new()
	building_input.live = self
	add_child(building_input)
	_active = true
	_last_usec = Time.get_ticks_usec()
	_sync_placed_buildings()
	_request_save()
	_relayout()


func _revalidate_restored_buildings() -> bool:
	if session == null or editor == null:
		return false
	var accepted: Array = []
	var ids: Array = session.building_placements.keys()
	ids.sort()
	for id_v: Variant in ids:
		var instance_id: String = str(id_v)
		var saved: Dictionary = session.building_placements[instance_id] as Dictionary
		var building_id: String = str(saved.get("building_id", ""))
		var index: int = session.economy.params.building_index(building_id)
		if index < 0:
			return false
		var tier: int = session.economy.tier_of(index)
		var center: Array = saved.get("center_mm", []) as Array
		if tier <= 0 or center.size() != 2:
			return false
		var checked: Dictionary = MHBuildingPlacement.validate(editor.grid, editor.splat, session.land, building_id, tier,
			Vector2i(int(center[0]), int(center[1])), accepted, int(saved.get("rotation_quarters", 0)),
			session.hole_definitions(), _placement_obstacles(), document.get("course", {}) as Dictionary)
		if not bool(checked.get("ok", false)):
			return false
		# The terrain/ownership validator is authoritative. Replace derived geometry from the save
		# with its canonical result so stale ground/size fields cannot survive a valid restore.
		var canonical: Dictionary = checked.duplicate(true)
		canonical["building_id"] = building_id
		canonical["instance_id"] = instance_id
		session.building_placements[instance_id] = canonical
		accepted.append(canonical)
	return true


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


func _begin_first_owned_building() -> void:
	for idv: Variant in session.economy.params.building_ids:
		var id: String = str(idv)
		var tier: int = session.economy.tier_of(session.economy.params.building_index(id))
		if tier > 0:
			_begin_building_placement(id, tier)
			return
	_status.text = "Buy a building tier first, then place it."


func _begin_building_placement(building_id: String, tier: int) -> void:
	_placement_id = building_id
	_placement_tier = tier
	_placement_rotation = 0
	if _placement_ghost == null:
		_placement_ghost = MeshInstance3D.new()
		add_child(_placement_ghost)
	_update_ghost_mesh()
	_status.text = "Placing %s: move over terrain, rotate, then confirm." % building_id.replace("_", " ")
	_placement_controls.show()


func _update_ghost_mesh() -> void:
	if _placement_ghost == null or _placement_id == "":
		return
	var mesh_key: String = "%s:%d:a" % [_placement_id, _placement_tier]
	if not _building_mesh_cache.has(mesh_key):
		_building_mesh_cache[mesh_key] = MHBuildingMeshes.build(_placement_id, _placement_tier, "a")
	_placement_ghost.mesh = _building_mesh_cache[mesh_key] as Mesh
	_placement_ghost.rotation.y = float(_placement_rotation) * PI * 0.5


func _placement_preview(world_m: Vector2) -> void:
	if _placement_id == "":
		return
	_placement_last = validate_building_placement(_placement_id, _placement_tier, world_m, _placement_rotation)
	if _placement_ghost != null:
		var ground: float = float(int(_placement_last.get("ground_mm", 0))) / 1000.0
		_placement_ghost.position = Vector3(world_m.x, ground, world_m.y)
		_placement_ghost.material_override = _ghost_valid_mat if bool(_placement_last.get("ok", false)) else _ghost_invalid_mat
	_placement_status.text = "VALID — click/tap to build" if bool(_placement_last.get("ok", false)) else "INVALID — " + _placement_reason(str(_placement_last.get("reason", "")))


func _placement_reason(reason: String) -> String:
	var labels: Dictionary = {"world_edge": "outside world", "unowned_land": "footprint crosses unowned land",
		"building_overlap": "too close to another building", "hazard": "natural/man-made hazard under footprint",
		"terrain_relief": "site is too uneven", "terrain_slope": "site is too steep", "golf_feature": "overlaps playable golf area",
		"unsupported": "unsupported site", "obstacle": "tree, rock or placed object blocks footprint"}
	return str(labels.get(reason, reason))


func rotate_building_preview() -> void:
	if _placement_id == "":
		return
	_placement_rotation = posmod(_placement_rotation + 1, 4)
	_update_ghost_mesh()


func cancel_building_preview() -> void:
	_placement_id = ""
	_placement_last = {}
	if _placement_ghost != null:
		_placement_ghost.queue_free()
		_placement_ghost = null
	if _placement_controls != null:
		_placement_controls.hide()
	_placement_status.text = ""
	_status.text = _first_round_status()


func confirm_building_preview() -> Dictionary:
	if _placement_id == "" or not bool(_placement_last.get("ok", false)):
		return {"ok": false, "reason": str(_placement_last.get("reason", "invalid"))}
	if not session.set_building_placement(_placement_id, _placement_last):
		return {"ok": false, "reason": "building"}
	var result: Dictionary = _placement_last.duplicate(true)
	_placement_id = ""
	_placement_last = {}
	if _placement_ghost != null:
		_placement_ghost.queue_free()
		_placement_ghost = null
	_placement_status.text = ""
	_placement_controls.hide()
	_sync_placed_buildings()
	_request_save()
	return result


func validate_building_placement(building_id: String, tier: int, world_m: Vector2, rotation_quarters: int = 0) -> Dictionary:
	var existing: Array = []
	for v: Variant in session.building_placements.values():
		existing.append((v as Dictionary).duplicate(true))
	return MHBuildingPlacement.validate(editor.grid, editor.splat, session.land, building_id, tier,
		Vector2i(roundi(world_m.x * 1000.0), roundi(world_m.y * 1000.0)), existing, rotation_quarters, session.hole_definitions(), _placement_obstacles(), document.get("course", {}) as Dictionary)


func place_building(building_id: String, tier: int, world_m: Vector2) -> Dictionary:
	var result: Dictionary = validate_building_placement(building_id, tier, world_m)
	if not bool(result.get("ok", false)):
		return result
	if not session.set_building_placement(building_id, result):
		return {"ok": false, "reason": "building"}
	_sync_placed_buildings()
	_request_save()
	return result

func _sync_placed_buildings() -> void:
	if _placed_buildings_root == null or session == null:
		return
	var keep: Dictionary = {}
	for idv: Variant in session.building_placements.keys():
		var instance_id: String = str(idv)
		var placement: Dictionary = session.building_placements[instance_id] as Dictionary
		var building_id: String = str(placement.get("building_id", ""))
		var tier: int = session.economy.tier_of(session.economy.params.building_index(building_id))
		if building_id.is_empty() or tier <= 0:
			continue
		var node: MeshInstance3D
		if _placed_building_nodes.has(instance_id) and is_instance_valid(_placed_building_nodes[instance_id]):
			node = _placed_building_nodes[instance_id] as MeshInstance3D
		else:
			node = MHArtMaterials.make_instance(null, _building_mat, false)
			_placed_buildings_root.add_child(node)
			_placed_building_nodes[instance_id] = node
		var mesh_key: String = "%s:%d:a" % [building_id, tier]
		if not _building_mesh_cache.has(mesh_key):
			_building_mesh_cache[mesh_key] = MHBuildingMeshes.build(building_id, tier, "a")
		node.mesh = _building_mesh_cache[mesh_key] as Mesh
		var center: Array = placement.get("center_mm", []) as Array
		if center.size() != 2:
			continue
		var ground: float = float(int(placement.get("ground_mm", 0))) / 1000.0
		node.position = Vector3(float(int(center[0])) / 1000.0, ground, float(int(center[1])) / 1000.0)
		node.rotation.y = float(int(placement.get("rotation_quarters", 0))) * PI * 0.5
		keep[instance_id] = true
	for idv: Variant in _placed_building_nodes.keys():
		var id: String = str(idv)
		if not keep.has(id):
			var old: Node = _placed_building_nodes[id] as Node
			if old != null and is_instance_valid(old):
				old.queue_free()
			_placed_building_nodes.erase(id)


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
	_advance_customer_playback(float(elapsed) / 1000000.0)
	_advance_facility_walkers(float(elapsed) / 1000000.0)
	_visible_golfers.advance(float(elapsed) / 1000000.0, controller.rig.global_position)
	chunks.flush(editor.dirty)
	_relayout()
	router.accept_world_input = _placement_id == "" and shell.current_screen_id() == MHScreenIds.EDITOR and shell.modal_id() == "" and (one_hole == null or not one_hole.visible)
	if not router.accept_world_input:
		router.cancel_world_input()
	if _pending_save and not editor.is_stroke_open():
		save_now()

func _advance_customer_playback(delta_s: float) -> void:
	if _visible_golfers == null or session.customer_playback == null or session.clock.is_paused():
		return
	var now_s: float = float(session.clock.total_minutes()) * 60.0
	var event: Dictionary = session.customer_playback.advance(now_s)
	var kind: String = str(event.get("kind", ""))
	if kind == "finished":
		_queue_finished_customer_facility(event.get("customer", {}) as Dictionary, now_s)
		return
	if kind != "started":
		return
	var customer: Dictionary = event.get("customer", {}) as Dictionary
	var slot: int = int(customer.get("hole_slot", -1))
	var hole: Dictionary = {}
	for hole_v: Variant in session.hole_definitions():
		var candidate: Dictionary = hole_v
		if int(candidate.get("slot_id", -1)) == slot:
			hole = candidate
			break
	if hole.is_empty():
		return
	var tee_v: Array = hole.get("tee", [])
	var green_v: Array = hole.get("green", [])
	if tee_v.size() < 2 or green_v.size() < 2:
		return
	var tee: Vector2 = Vector2(float(tee_v[0]), float(tee_v[1]))
	var green: Vector2 = Vector2(float(green_v[0]), float(green_v[1]))
	var identity: Dictionary = customer.get("identity", {}) as Dictionary
	var size: int = clampi(int(identity.get("party_size", customer.get("group_size", 1))), 1, 4)
	_visible_golfers.spawn_group(int(customer.get("serial", 0)), size, tee, green, customer.get("round", {}) as Dictionary)

func _queue_finished_customer_facility(customer: Dictionary, now_s: float) -> void:
	if int(customer.get("satisfaction", 0)) < 55:
		return
	var identity: Dictionary = customer.get("identity", {}) as Dictionary
	var favorite_facility: String = str(identity.get("favorite_facility", ""))
	var facility_ids: Array = MHClubPedestrian.instance_ids_for_type(session, favorite_facility)
	if facility_ids.is_empty():
		return
	var facility_index: int = posmod(int(customer.get("serial", 0)), facility_ids.size())
	session.customer_playback.queue_facility_visit(customer, str(facility_ids[facility_index]), now_s)


func _advance_facility_walkers(delta_s: float) -> void:
	var now_s: float = float(session.clock.total_minutes()) * 60.0
	var positions: Dictionary = MHClubPedestrian.building_positions(session)
	for pending_v: Variant in session.customer_playback.pending_facility_visits:
		var pending: Dictionary = pending_v
		var serial: int = int(pending.get("serial", -1))
		if serial < 0 or _facility_walkers.has(serial):
			continue
		var facility_id: String = str(pending.get("facility_instance_id", ""))
		if not positions.has(facility_id):
			continue
		var start: Vector3 = Vector3.ZERO
		var slot: int = int((pending.get("identity", {}) as Dictionary).get("favorite_hole_slot", -1))
		for hole_v: Variant in session.hole_definitions():
			var hole: Dictionary = hole_v
			if slot >= 0 and int(hole.get("slot_id", -1)) != slot:
				continue
			var green_v: Array = hole.get("green", [])
			if green_v.size() >= 2:
				start = Vector3(float(green_v[0]), 0.0, float(green_v[1]))
				break
		start = MHClubPedestrian.apply_ground_height(start, editor.grid)
		var node: Node3D = Node3D.new()
		node.name = "FacilityWalker_%d" % serial
		node.position = start
		var body: MeshInstance3D = MeshInstance3D.new()
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = 0.32
		capsule.height = 1.7
		capsule.radial_segments = 8
		capsule.rings = 2
		body.mesh = capsule
		body.position.y = 0.85
		body.material_override = _building_mat
		node.add_child(body)
		add_child(node)
		_facility_walkers[serial] = {"node": node, "route": MHClubPedestrian.route(start, positions[facility_id] as Vector3, serial),
			"segment": 1}
	var arrived: Array = []
	for serial_v: Variant in _facility_walkers.keys():
		var serial: int = int(serial_v)
		var walker: Dictionary = _facility_walkers[serial]
		var node: Node3D = walker["node"] as Node3D
		var step: Dictionary = MHClubPedestrian.advance(walker["route"] as Array, int(walker["segment"]), node.position, delta_s, editor.grid)
		node.position = step["position"] as Vector3
		walker["segment"] = int(step["segment"])
		if bool(step["done"]):
			session.customer_playback.begin_facility_visit(serial, now_s)
			arrived.append(serial)
	for serial_v: Variant in arrived:
		var serial: int = int(serial_v)
		var walker: Dictionary = _facility_walkers[serial]
		(walker["node"] as Node3D).queue_free()
		_facility_walkers.erase(serial)


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


func _placement_obstacles() -> Array:
	var out: Array = []
	# Render forest placement is deterministic integer-mm data; treat trunks/canopies as natural obstacles.
	var forest_nodes: Array[Node] = find_children("*", "MHForest", true, false)
	for n: Node in forest_nodes:
		var forest: MHForest = n as MHForest
		if forest.placement.is_empty():
			forest.build()
		for i: int in range(forest.placed_tree_count()):
			var o: int = i * MHTreePlacement.STRIDE
			out.append({"kind": "tree", "x_mm": forest.placement[o], "y_mm": forest.placement[o + 1], "radius_mm": 2200})
	return out
