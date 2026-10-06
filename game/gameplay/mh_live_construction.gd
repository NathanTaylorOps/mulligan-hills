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
var _hole_transition_walkers: Dictionary = {}
var _party_carts: Dictionary = {}
var _player_cart: MHPlayerCart
var _player_cart_debris: Node3D
var _cart_drive_input: MHCartDriveInput
var _cart_drive_active: bool = false
var _hud_layer: CanvasLayer
var _cart_camera: Camera3D
var _golfer_reactions: Array = []
var _visible_staff_root: Node3D
var _visible_staff_nodes: Dictionary = {}
var _maintenance_visuals: Dictionary = {}
var _last_condition_signature: int = -1
var _staff_work_effects: Dictionary = {}
const MAX_GOLFER_REACTIONS: int = 6
const GOLFER_REACTION_LIFETIME_S: float = 5.0

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
	_sync_course_condition_overlay()
	_placed_buildings_root = Node3D.new()
	_placed_buildings_root.name = "PlacedBuildings"
	add_child(_placed_buildings_root)
	_building_mat = MHArtMaterials.vertex_color()
	_visible_golfers = MHSliceGolfers.new()
	_visible_golfers.name = "VisibleGolfers"
	add_child(_visible_golfers)
	_visible_golfers.setup(_building_mat)
	_visible_golfers.terrain_grid = editor.grid
	_visible_staff_root = Node3D.new()
	_visible_staff_root.name = "VisibleStaff"
	add_child(_visible_staff_root)
	_sync_visible_staff()
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
	_hud_layer = layer
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
	var drive_cart: MHTapButton = MHUIKit.button(shell.ctx, "Drive cart", &"ChipButton", 120)
	drive_cart.pressed.connect(enter_cart_drive_mode)
	for b: MHTapButton in [save_button, back, play, drive_cart]:
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
	router.register_ui_region(&"live_drive_cart", _button_rect.bind(drive_cart))
	router.register_ui_region(&"live_save", _button_rect.bind(save_button))
	router.register_ui_region(&"live_back", _button_rect.bind(back))
	router.ui_tapped.connect(func(id: StringName) -> void:
		if id == &"live_save": save_button.pressed.emit()
		elif id == &"live_back": back.pressed.emit()
		elif id == &"live_practice": play.pressed.emit()
		elif id == &"live_drive_cart": drive_cart.pressed.emit()
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
	_advance_hole_transition_walkers(float(elapsed) / 1000000.0)
	_advance_facility_walkers(float(elapsed) / 1000000.0)
	_advance_golfer_reactions(float(elapsed) / 1000000.0)
	_sync_visible_staff()
	_sync_maintenance_visuals()
	_sync_course_condition_overlay()
	_show_new_grounds_events()
	_update_cart_drive_camera()
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
	for event_v: Variant in session.customer_playback.advance_all(now_s):
		var event: Dictionary = event_v
		var kind: String = str(event.get("kind", ""))
		if kind == "finished":
			var finished_customers: Array = event.get("customers", [event.get("customer", {})]) as Array
			for customer_v: Variant in finished_customers:
				var customer: Dictionary = session.apply_playback_pace_experience(customer_v as Dictionary)
				_show_golfer_reaction(customer)
				_queue_finished_customer_facility(customer, now_s)
			if not finished_customers.is_empty():
				var finished_customer: Dictionary = finished_customers[0] as Dictionary
				_remove_party_cart(int(finished_customer.get("party_id", finished_customer.get("serial", -1))))
		elif kind == "hole_transition":
			for customer_v: Variant in event.get("customers", [event.get("customer", {})]):
				_show_hole_reaction(customer_v as Dictionary)
			_begin_hole_transition(event)
		elif kind == "started" or kind == "hole_started":
			_render_customer_hole(event)
			if kind == "started":
				_show_arrival_identity(event)


func _begin_hole_transition(event: Dictionary) -> void:
	var customer: Dictionary = event.get("customer", {}) as Dictionary
	var party_id: int = int(customer.get("party_id", customer.get("serial", -1)))
	if party_id < 0 or _hole_transition_walkers.has(party_id):
		return
	var previous_slot: int = session.customer_playback.transition_from_hole(party_id)
	var next_slot: int = int(customer.get("hole_slot", -1))
	var from_pos: Vector3 = _hole_world_point(previous_slot, "green")
	var to_pos: Vector3 = _hole_world_point(next_slot, "tee")
	if from_pos == Vector3.INF or to_pos == Vector3.INF:
		var fallback_event: Dictionary = session.customer_playback.begin_next_hole(float(session.clock.total_minutes()) * 60.0, party_id)
		if not fallback_event.is_empty():
			_render_customer_hole(fallback_event)
		return
	_visible_golfers.remove_group(party_id)
	var start: Vector3 = MHClubPedestrian.apply_ground_height(from_pos, editor.grid)
	var customers: Array = event.get("customers", [customer]) as Array
	var star_cart: bool = _party_has_star(customers) and session.carts_allowed_now()
	var uses_cart: bool = _party_uses_cart(customers, party_id)
	_visible_golfers.spawn_walking_party(customers, start, to_pos)
	_visible_golfers.set_walking_party_hidden(party_id, uses_cart)
	if uses_cart:
		_ensure_party_cart(party_id, start, customers.size(), _star_cart_style(customers))
	var travel_route: Array = MHClubPedestrian.route(start, to_pos, party_id)
	if uses_cart:
		var cart_route: Array = MHCartRoute.route_to_ball(start, to_pos, party_id, editor.splat, editor.grid)
		if cart_route.size() >= 2:
			travel_route = cart_route
	_hole_transition_walkers[party_id] = {"position": start,
		"route": travel_route, "segment": 1, "uses_cart": uses_cart, "star_cart": star_cart}


func _advance_hole_transition_walkers(delta_s: float) -> void:
	if _hole_transition_walkers.is_empty():
		return
	var arrived: Array = []
	for party_v: Variant in _hole_transition_walkers.keys():
		var party_id: int = int(party_v)
		var walker: Dictionary = _hole_transition_walkers[party_id]
		var before: Vector3 = walker["position"] as Vector3
		var step: Dictionary = MHClubPedestrian.advance(walker["route"] as Array, int(walker["segment"]), before, delta_s, editor.grid)
		var position: Vector3 = step["position"] as Vector3
		walker["position"] = position
		walker["segment"] = int(step["segment"])
		_visible_golfers.update_walking_party(party_id, position, position - before)
		_update_party_cart(party_id, position, position - before, bool(walker.get("uses_cart", false)))
		if bool(step["done"]):
			arrived.append(party_id)
	for party_v: Variant in arrived:
		var party_id: int = int(party_v)
		var event: Dictionary = session.customer_playback.begin_next_hole(float(session.clock.total_minutes()) * 60.0, party_id)
		if event.is_empty():
			# The next tee is occupied. Keep the real party waiting visibly at the tee and retry next frame.
			continue
		_hole_transition_walkers.erase(party_id)
		_visible_golfers.remove_group(party_id)
		if not bool(walker.get("star_cart", false)):
			_remove_party_cart(party_id)
		else:
			_park_star_cart(party_id, int((event.get("customer", {}) as Dictionary).get("hole_slot", -1)))
		_render_customer_hole(event)


func enter_cart_drive_mode() -> bool:
	if not session.carts_allowed_now():
		_status.text = "Carts are not allowed during tournaments."
		return false
	if _player_cart == null or not is_instance_valid(_player_cart):
		if not respawn_player_cart():
			_status.text = "Build a clubhouse before using free-drive carts."
			return false
	if _cart_drive_input == null:
		_cart_drive_input = MHCartDriveInput.new()
		_hud_layer.add_child(_cart_drive_input)
		_cart_drive_input.drive_changed.connect(func(throttle: float, steer: float) -> void: drive_player_cart(throttle, steer))
		_cart_drive_input.exit_requested.connect(exit_cart_drive_mode)
		_cart_drive_input.respawn_requested.connect(func() -> void: respawn_player_cart())
	if _cart_camera == null:
		_cart_camera = Camera3D.new()
		add_child(_cart_camera)
	_cart_drive_input.show()
	_cart_drive_active = true
	_cart_camera.current = true
	router.accept_world_input = false
	_status.text = "Free drive: stay on paths or cause trouble."
	return true


func exit_cart_drive_mode() -> void:
	_cart_drive_active = false
	if _cart_drive_input != null:
		_cart_drive_input.hide()
	if _cart_camera != null:
		_cart_camera.current = false
	if controller != null and controller.rig != null:
		var main_camera: Camera3D = controller.rig.get_node_or_null("Camera3D") as Camera3D
		if main_camera != null:
			main_camera.current = true
	_status.text = "Returned to course management."


func _update_cart_drive_camera() -> void:
	if not _cart_drive_active or _cart_camera == null or _player_cart == null or not is_instance_valid(_player_cart):
		return
	var back: Vector3 = _player_cart.global_transform.basis.z.normalized() * 7.0
	var target: Vector3 = _player_cart.global_position + Vector3(0.0, 1.0, 0.0)
	_cart_camera.global_position = target + back + Vector3(0.0, 3.8, 0.0)
	_cart_camera.look_at(target, Vector3.UP)


func respawn_player_cart() -> bool:
	var spawn: Vector3 = MHCartRoute.clubhouse_spawn(session)
	if spawn == Vector3.INF:
		return false
	if _player_cart != null and is_instance_valid(_player_cart):
		_player_cart.queue_free()
	if _player_cart_debris != null and is_instance_valid(_player_cart_debris):
		_player_cart_debris.queue_free()
	_player_cart_debris = Node3D.new()
	_player_cart_debris.name = "PlayerCartDebris"
	add_child(_player_cart_debris)
	_player_cart = MHPlayerCart.new()
	_player_cart.name = "PlayerCart"
	_player_cart.splat = editor.splat
	_player_cart.grid = editor.grid
	_player_cart.debris_root = _player_cart_debris
	_add_player_cart_visual(_player_cart)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.25, 0.75, 2.0)
	collision.shape = shape
	collision.position.y = 0.5
	_player_cart.add_child(collision)
	add_child(_player_cart)
	_player_cart.global_position = MHClubPedestrian.apply_ground_height(spawn, editor.grid) + Vector3(0.0, 0.6, 0.0)
	_player_cart.sunk.connect(func() -> void: _status.text = "Cart sunk — respawn it at the clubhouse.")
	_player_cart.tipped.connect(func() -> void: _status.text = "Cart rolled over.")
	_player_cart.clubs_lost.connect(func(count: int) -> void: _status.text = "%d clubs fell off the cart." % count)
	_player_cart.green_violation.connect(_on_player_cart_green_violation)
	return true


static func _add_player_cart_visual(cart: Node3D) -> void:
	var body: MeshInstance3D = MeshInstance3D.new()
	var body_mesh: BoxMesh = BoxMesh.new()
	body_mesh.size = Vector3(1.25, 0.55, 2.0)
	body.mesh = body_mesh
	body.position.y = 0.65
	cart.add_child(body)
	var roof: MeshInstance3D = MeshInstance3D.new()
	var roof_mesh: BoxMesh = BoxMesh.new()
	roof_mesh.size = Vector3(1.35, 0.10, 1.65)
	roof.mesh = roof_mesh
	roof.position = Vector3(0.0, 1.65, -0.05)
	cart.add_child(roof)
	for x: float in [-0.72, 0.72]:
		for z: float in [-0.68, 0.68]:
			var wheel: MeshInstance3D = MeshInstance3D.new()
			var wheel_mesh: CylinderMesh = CylinderMesh.new()
			wheel_mesh.top_radius = 0.28
			wheel_mesh.bottom_radius = 0.28
			wheel_mesh.height = 0.18
			wheel.mesh = wheel_mesh
			wheel.rotation_degrees.z = 90.0
			wheel.position = Vector3(x, 0.28, z)
			cart.add_child(wheel)
	var bag: MeshInstance3D = MeshInstance3D.new()
	var bag_mesh: CylinderMesh = CylinderMesh.new()
	bag_mesh.top_radius = 0.18
	bag_mesh.bottom_radius = 0.24
	bag_mesh.height = 0.9
	bag.mesh = bag_mesh
	bag.rotation_degrees.x = -18.0
	bag.position = Vector3(0.0, 1.05, 1.05)
	bag.name = "GolfBag"
	cart.add_child(bag)


func _on_player_cart_green_violation() -> void:
	if _player_cart == null or editor == null or editor.grid == null:
		return
	var cell_mm: int = editor.grid.cell_size_mm
	if cell_mm <= 0:
		return
	var cx: int = clampi(roundi(_player_cart.global_position.x * 1000.0) / cell_mm, 0, editor.grid.cells_x - 1)
	var cy: int = clampi(roundi(_player_cart.global_position.z * 1000.0) / cell_mm, 0, editor.grid.cells_y - 1)
	var result: Dictionary = session.damage_turf_at_cell(cx, cy, editor.grid.cells_x, editor.grid.cells_y)
	var damage: int = int(result.get("damage", 0))
	_status.text = "Green damaged (-%d condition). Grounds staff will need to repair it." % damage if damage > 0 else "You drove onto a green."


func drive_player_cart(throttle: float, steer: float) -> bool:
	if _player_cart == null or not is_instance_valid(_player_cart):
		return false
	_player_cart.drive(throttle, steer)
	return true


func _party_uses_cart(customers: Array, party_id: int) -> bool:
	if not session.carts_allowed_now():
		return false
	if _party_has_star(customers):
		return true
	if customers.size() < 2:
		return false
	if MHClubPedestrian.instance_ids_for_type(session, "cart_barn").is_empty():
		return false
	return posmod(party_id, 3) != 0


static func _party_has_star(customers: Array) -> bool:
	for customer_v: Variant in customers:
		var customer: Dictionary = customer_v as Dictionary
		var identity: Dictionary = customer.get("identity", {}) as Dictionary
		var identity_type: String = str(identity.get("identity_type", "ordinary"))
		if identity_type == "celebrity" or identity_type == "pro":
			return true
	return false


func _ensure_party_cart(party_id: int, position: Vector3, riders: int = 2, style: String = "standard") -> void:
	if _party_carts.has(party_id):
		return
	var root: Node3D = Node3D.new()
	root.name = "PartyCart_%d" % party_id
	root.set_meta("cart_style", style)
	var profile: Dictionary = MHStarCartProfiles.profile_for(style)
	root.set_meta("cart_behavior", str(profile.get("behavior", "park_nearby")))
	var body: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = MHStarCartProfiles.body_size(profile)
	body.mesh = mesh
	body.position.y = 0.5
	root.add_child(body)
	var rider_count: int = mini(4, maxi(1, riders))
	for i: int in range(rider_count):
		var rider: MeshInstance3D = MeshInstance3D.new()
		var rider_mesh: CapsuleMesh = CapsuleMesh.new()
		rider_mesh.radius = 0.22
		rider_mesh.height = 0.85
		rider.mesh = rider_mesh
		rider.position = Vector3(-0.32 if i % 2 == 0 else 0.32, 1.05, -0.28 if i < 2 else 0.35)
		root.add_child(rider)
	add_child(root)
	root.position = position
	_party_carts[party_id] = root


static func _star_cart_style(customers: Array) -> String:
	for customer_v: Variant in customers:
		var identity: Dictionary = (customer_v as Dictionary).get("identity", {}) as Dictionary
		var identity_type: String = str(identity.get("identity_type", "ordinary"))
		if identity_type == "celebrity" or identity_type == "pro":
			return str(identity.get("cart_skin", identity.get("parody_id", identity_type)))
	return "standard"


func _park_star_cart(party_id: int, hole_slot: int) -> void:
	if not _party_carts.has(party_id):
		return
	var tee: Vector3 = _hole_world_point(hole_slot, "tee")
	if tee == Vector3.INF:
		return
	var cart: Node3D = _party_carts[party_id] as Node3D
	var profile: Dictionary = MHStarCartProfiles.profile_for(str(cart.get_meta("cart_style", "standard")))
	cart.position = MHClubPedestrian.apply_ground_height(tee + MHStarCartProfiles.park_offset(profile), editor.grid)
	var behavior: String = str(profile.get("behavior", "park_nearby"))
	if behavior == "park_nearby_upside_down":
		cart.rotation_degrees.z = 180.0
	else:
		cart.rotation_degrees.z = 0.0


func _update_party_cart(party_id: int, position: Vector3, direction: Vector3, enabled: bool) -> void:
	if not enabled:
		return
	_ensure_party_cart(party_id, position, 2)
	var cart: Node3D = _party_carts[party_id] as Node3D
	cart.position = position
	if direction.length_squared() > 0.001:
		cart.rotation.y = atan2(direction.x, direction.z)


func _remove_party_cart(party_id: int) -> void:
	if not _party_carts.has(party_id):
		return
	(_party_carts[party_id] as Node3D).queue_free()
	_party_carts.erase(party_id)


func _hole_world_point(slot: int, key: String) -> Vector3:
	for hole_v: Variant in session.hole_definitions():
		var hole: Dictionary = hole_v
		if int(hole.get("slot_id", -1)) != slot:
			continue
		var point: Array = hole.get(key, []) as Array
		if point.size() < 2:
			return Vector3.INF
		var mm: Vector2i = MHCourseLayout.world_point_mm(document.get("course", {}) as Dictionary,
			slot, int(point[0]) * 100, int(point[1]) * 100)
		if mm.x < 0:
			return Vector3.INF
		return MHClubPedestrian.apply_ground_height(Vector3(float(mm.x) / 1000.0, 0.0, float(mm.y) / 1000.0), editor.grid)
	return Vector3.INF


func _render_customer_hole(event: Dictionary) -> void:
	var customer: Dictionary = event.get("customer", {}) as Dictionary
	var customers: Array = event.get("customers", [customer]) as Array
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
	var course: Dictionary = document.get("course", {}) as Dictionary
	var tee_mm: Vector2i = MHCourseLayout.world_point_mm(course, slot, int(tee_v[0]) * 100, int(tee_v[1]) * 100)
	var green_mm: Vector2i = MHCourseLayout.world_point_mm(course, slot, int(green_v[0]) * 100, int(green_v[1]) * 100)
	if tee_mm.x < 0 or green_mm.x < 0:
		return
	var tee: Vector2 = Vector2(float(tee_mm.x) / 1000.0, float(tee_mm.y) / 1000.0)
	var green: Vector2 = Vector2(float(green_mm.x) / 1000.0, float(green_mm.y) / 1000.0)
	var origin_dm: Array = MHCourseLayout.origin_for_slot(course, slot)
	var world_origin: Vector2 = Vector2(float(origin_dm[0]) / 10.0, float(origin_dm[1]) / 10.0)
	_visible_golfers.spawn_authoritative_party(customers, tee, green, world_origin)
	_sync_star_cart_for_hole(customers, slot)


func _sync_star_cart_for_hole(customers: Array, hole_slot: int) -> void:
	if customers.is_empty() or not session.carts_allowed_now() or not _party_has_star(customers):
		return
	var customer: Dictionary = customers[0] as Dictionary
	var party_id: int = int(customer.get("party_id", customer.get("serial", -1)))
	if party_id < 0:
		return
	var tee: Vector3 = _hole_world_point(hole_slot, "tee")
	if tee == Vector3.INF:
		return
	_ensure_party_cart(party_id, tee, customers.size(), _star_cart_style(customers))
	_park_star_cart(party_id, hole_slot)


func _sync_visible_staff() -> void:
	if _visible_staff_root == null or session == null:
		return
	var used: Dictionary = {}
	for assignment_v: Variant in session.live_staff_assignments():
		var assignment: Dictionary = assignment_v as Dictionary
		var serial: int = int(assignment.get("serial", 0))
		var areas: Array = assignment.get("areas", []) as Array
		if serial <= 0 or areas.is_empty():
			continue
		var area_index: int = posmod((session.clock.total_minutes() / 60) + serial, areas.size())
		var slot: int = int(areas[area_index])
		var route: Array = _staff_work_route(slot, serial)
		if route.size() < 2:
			continue
		used[serial] = true
		var node: Node3D = _visible_staff_nodes.get(serial, null) as Node3D
		var equipment: Dictionary = assignment.get("equipment", {}) as Dictionary
		var visual_key: String = str(equipment.get("type", "walking")) + (":broken" if bool(equipment.get("broken", false)) else "")
		if node == null or str(node.get_meta("visual_key", "")) != visual_key:
			if node != null:
				node.queue_free()
			node = _make_staff_visual(assignment)
			node.set_meta("visual_key", visual_key)
			_visible_staff_root.add_child(node)
			_visible_staff_nodes[serial] = node
		var progress: float = fmod(float(session.clock.total_minutes() * 3 + serial * 11), 100.0) / 100.0
		var state: Dictionary = _route_state(route, progress)
		node.position = MHClubPedestrian.apply_ground_height(state["position"] as Vector3, editor.grid)
		var direction: Vector3 = state["direction"] as Vector3
		if direction.length_squared() > 0.001:
			node.rotation.y = atan2(direction.x, direction.z)
		_sync_staff_work_marker(node, assignment, progress)
	for serial_v: Variant in _visible_staff_nodes.keys():
		if not used.has(serial_v):
			(_visible_staff_nodes[serial_v] as Node3D).queue_free()
			_visible_staff_nodes.erase(serial_v)


func _sync_staff_work_marker(node: Node3D, assignment: Dictionary, progress: float) -> void:
	var existing: Label3D = node.get_node_or_null("WorkState") as Label3D
	var equipment: Dictionary = assignment.get("equipment", {}) as Dictionary
	var broken: bool = bool(equipment.get("broken", false))
	var active: bool = fmod(progress * 100.0, 20.0) < 7.0
	if not active:
		if existing != null:
			existing.visible = false
		return
	if existing == null:
		existing = Label3D.new()
		existing.name = "WorkState"
		existing.font_size = 15
		existing.outline_size = 4
		existing.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		existing.position = Vector3(0.0, 2.15, 0.0)
		node.add_child(existing)
	existing.visible = true
	if not equipment.is_empty() and not broken:
		existing.text = "Mowing" if str(equipment.get("kind", "")) == "grounds" else "Working"
	elif broken:
		existing.text = "Manual work"
	else:
		existing.text = "Grounds work"


func _staff_work_route(slot: int, serial: int) -> Array:
	var tee: Vector3 = _hole_world_point(slot, "tee")
	var green: Vector3 = _hole_world_point(slot, "green")
	if tee == Vector3.INF or green == Vector3.INF:
		return []
	var forward: Vector3 = green - tee
	forward.y = 0.0
	if forward.length_squared() < 0.01:
		return [tee, green]
	var side: Vector3 = Vector3(-forward.z, 0.0, forward.x).normalized()
	var offset: float = 3.0 + float(posmod(serial, 3)) * 1.5
	return [tee, tee.lerp(green, 0.28) + side * offset, tee.lerp(green, 0.55) - side * offset,
		tee.lerp(green, 0.82) + side * offset * 0.6, green]


static func _route_state(route: Array, progress: float) -> Dictionary:
	if route.size() < 2:
		return {"position": Vector3.ZERO, "direction": Vector3.ZERO}
	var p: float = clampf(progress, 0.0, 0.999999) * float(route.size() - 1)
	var segment: int = mini(route.size() - 2, int(floor(p)))
	var t: float = p - float(segment)
	var a: Vector3 = route[segment] as Vector3
	var b: Vector3 = route[segment + 1] as Vector3
	return {"position": a.lerp(b, t), "direction": b - a}


func _show_new_grounds_events() -> void:
	for incident_v: Variant in session.take_grounds_events():
		var incident: Dictionary = incident_v as Dictionary
		var parcel: int = int(incident.get("parcel", -1))
		var positive: bool = bool(incident.get("positive", false))
		var handled: bool = bool(incident.get("handled", false))
		var kind: String = str(incident.get("kind", "grounds issue")).replace("_", " ")
		if positive:
			_status.text = "Course wildlife: %s spotted on area %d." % [kind.capitalize(), parcel + 1]
		elif handled:
			_status.text = "%s on area %d — grounds team contained it." % [kind.capitalize(), parcel + 1]
		else:
			_status.text = "%s on area %d — maintenance attention needed." % [kind.capitalize(), parcel + 1]


func _sync_course_condition_overlay() -> void:
	if chunks == null or session == null:
		return
	var state: Dictionary = session.live_course_condition()
	var condition: Array = state.get("condition", []) as Array
	var pest: Array = state.get("pest", []) as Array
	var signature: int = hash([condition, pest])
	if signature == _last_condition_signature:
		return
	_last_condition_signature = signature
	chunks.set_condition_overlay(condition, pest)


func _sync_maintenance_visuals() -> void:
	if _visible_staff_root == null or session == null:
		return
	var maintenance_ids: Array = MHClubPedestrian.instance_ids_for_type(session, "maintenance")
	if maintenance_ids.is_empty():
		_clear_maintenance_visuals()
		return
	var workshop: Vector3 = session.building_instance_position(str(maintenance_ids[0]))
	if workshop == Vector3.INF:
		_clear_maintenance_visuals()
		return
	var state: Dictionary = session.live_maintenance_state()
	var used: Dictionary = {}
	for employee_v: Variant in state.get("specialists", []):
		var employee: Dictionary = employee_v as Dictionary
		var serial: int = int(employee.get("serial", 0))
		var key: String = "staff:%d" % serial
		used[key] = true
		var node: Node3D = _maintenance_visuals.get(key, null) as Node3D
		if node == null:
			node = _make_staff_visual(employee)
			_visible_staff_root.add_child(node)
			_maintenance_visuals[key] = node
		var angle: float = float(posmod(session.clock.total_minutes() + serial * 19, 360)) * PI / 180.0
		var radius: float = 2.0 + float(posmod(serial, 3))
		node.position = MHClubPedestrian.apply_ground_height(workshop + Vector3(cos(angle), 0.0, sin(angle)) * radius, editor.grid)
	for unit_v: Variant in state.get("broken_equipment", []):
		var unit: Dictionary = unit_v as Dictionary
		var serial: int = int(unit.get("serial", 0))
		var key: String = "machine:%d" % serial
		used[key] = true
		var machine: Node3D = _maintenance_visuals.get(key, null) as Node3D
		var repair_active: bool = int(state.get("technician_work_pm", 0)) > 0 and int(state.get("maintenance_tier", 0)) >= 2
		var status_key: String = "repairing" if repair_active else "waiting"
		if machine == null or str(machine.get_meta("status_key", "")) != status_key:
			if machine != null:
				machine.queue_free()
			machine = _make_broken_machine_visual(unit, repair_active)
			machine.set_meta("status_key", status_key)
			_visible_staff_root.add_child(machine)
			_maintenance_visuals[key] = machine
		var index: int = posmod(serial, 5)
		machine.position = MHClubPedestrian.apply_ground_height(workshop + Vector3(float(index - 2) * 1.7, 0.0, 3.2), editor.grid)
	for key_v: Variant in _maintenance_visuals.keys():
		if not used.has(key_v):
			(_maintenance_visuals[key_v] as Node3D).queue_free()
			_maintenance_visuals.erase(key_v)


func _clear_maintenance_visuals() -> void:
	for node_v: Variant in _maintenance_visuals.values():
		(node_v as Node3D).queue_free()
	_maintenance_visuals.clear()


func _make_broken_machine_visual(unit: Dictionary, repair_active: bool) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "BrokenMachine_%d" % int(unit.get("serial", 0))
	var machine: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(1.3, 0.55, 1.8)
	machine.mesh = mesh
	machine.position.y = 0.35
	root.add_child(machine)
	var status: Label3D = Label3D.new()
	status.text = "Repairing" if repair_active else "Awaiting technician"
	status.font_size = 18
	status.outline_size = 5
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.position = Vector3(0.0, 1.6, 0.0)
	root.add_child(status)
	return root


func _make_staff_visual(assignment: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Staff_%d" % int(assignment.get("serial", 0))
	var worker: MeshInstance3D = MeshInstance3D.new()
	var body: CapsuleMesh = CapsuleMesh.new()
	body.radius = 0.32
	body.height = 1.65
	worker.mesh = body
	worker.position.y = 0.82
	root.add_child(worker)
	var equipment: Dictionary = assignment.get("equipment", {}) as Dictionary
	if not equipment.is_empty() and not bool(equipment.get("broken", false)):
		var machine: MeshInstance3D = MeshInstance3D.new()
		var machine_mesh: BoxMesh = BoxMesh.new()
		machine_mesh.size = Vector3(1.3, 0.55, 1.8)
		machine.mesh = machine_mesh
		machine.position = Vector3(0.0, 0.35, -0.9)
		root.add_child(machine)
	return root


func _show_arrival_identity(event: Dictionary) -> void:
	var customer: Dictionary = event.get("customer", {}) as Dictionary
	var identity: Dictionary = customer.get("identity", {}) as Dictionary
	var text: String = _arrival_identity_text(identity)
	if text.is_empty():
		return
	var position: Vector3 = _hole_world_point(int(customer.get("hole_slot", -1)), "tee")
	if position != Vector3.INF:
		_spawn_reaction_label(text, position)


static func _arrival_identity_text(identity: Dictionary) -> String:
	var name: String = str(identity.get("name", ""))
	if name.is_empty():
		return ""
	if bool(identity.get("member", false)):
		return "%s • Member" % name
	var visits: int = int(identity.get("visits", 0))
	if visits >= 5:
		return "%s • Club regular" % name
	if visits >= 2:
		return "%s • Returning golfer" % name
	return ""


func _show_hole_reaction(customer: Dictionary) -> void:
	var round: Dictionary = customer.get("round", {}) as Dictionary
	var rating: Dictionary = customer.get("rating", {}) as Dictionary
	var text: String = _hole_reaction_text(round, int(rating.get("par", 3)))
	if text.is_empty():
		return
	var position: Vector3 = _hole_world_point(int(customer.get("hole_slot", -1)), "green")
	if position == Vector3.INF:
		return
	_spawn_reaction_label(text, position)


static func _hole_reaction_text(round: Dictionary, par: int) -> String:
	var strokes: int = int(round.get("strokes", par))
	if strokes <= par - 2:
		return "What a hole!"
	if strokes == par - 1:
		return "Birdie!"
	if strokes >= par + 3:
		return "Forget that one..."
	return ""


func _spawn_reaction_label(text: String, position: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 24
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = position + Vector3(0.0, 2.4, 0.0)
	add_child(label)
	_golfer_reactions.append({"node": label, "remaining": GOLFER_REACTION_LIFETIME_S})
	while _golfer_reactions.size() > MAX_GOLFER_REACTIONS:
		var oldest: Dictionary = _golfer_reactions.pop_front() as Dictionary
		(oldest["node"] as Label3D).queue_free()


func _show_golfer_reaction(customer: Dictionary) -> void:
	var slot: int = int(customer.get("hole_slot", -1))
	var position: Vector3 = _hole_world_point(slot, "green")
	if position == Vector3.INF:
		return
	var text: String = _reaction_text(customer)
	if text.is_empty():
		return
	_spawn_reaction_label(text, position)


static func _reaction_text(customer: Dictionary) -> String:
	var identity: Dictionary = customer.get("identity", {}) as Dictionary
	var name: String = str(identity.get("name", "Golfer")).get_slice(" ", 0)
	var pace_penalty: int = int(customer.get("pace_penalty", 0))
	if pace_penalty >= 6:
		return "%s: That was slow..." % name
	var pref_bonus: int = int(customer.get("preference_bonus", 0))
	var pref: int = int(customer.get("preference", identity.get("preference", MHGolferPreference.CASUAL)))
	if pref_bonus >= 6:
		return "%s: %s" % [name, _preference_praise(pref)]
	if pref_bonus <= -6:
		return "%s: %s" % [name, _preference_complaint(pref)]
	var sat: int = int(customer.get("satisfaction", 50))
	if sat >= 85:
		return "%s: What a round!" % name
	if sat <= 30:
		return "%s: Rough day out there." % name
	if pace_penalty > 0:
		return "%s: Bit of a wait." % name
	return ""


static func _preference_praise(kind: int) -> String:
	match kind:
		MHGolferPreference.STRATEGIST: return "Loved the choices out there."
		MHGolferPreference.THRILL_SEEKER: return "Now that was exciting!"
		MHGolferPreference.PURIST: return "That's proper golf."
	return "Beautiful, fair course."


static func _preference_complaint(kind: int) -> String:
	match kind:
		MHGolferPreference.STRATEGIST: return "Not enough interesting choices."
		MHGolferPreference.THRILL_SEEKER: return "Could use more excitement."
		MHGolferPreference.PURIST: return "That didn't feel quite fair."
	return "That course was a bit rough."


func _advance_golfer_reactions(delta_s: float) -> void:
	for i: int in range(_golfer_reactions.size() - 1, -1, -1):
		var reaction: Dictionary = _golfer_reactions[i] as Dictionary
		reaction["remaining"] = float(reaction["remaining"]) - delta_s
		if float(reaction["remaining"]) <= 0.0:
			(reaction["node"] as Label3D).queue_free()
			_golfer_reactions.remove_at(i)


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
		var slot: int = int(pending.get("hole_slot", -1))
		for hole_v: Variant in session.hole_definitions():
			var hole: Dictionary = hole_v
			if slot >= 0 and int(hole.get("slot_id", -1)) != slot:
				continue
			var green_v: Array = hole.get("green", [])
			if green_v.size() >= 2:
				var green_mm: Vector2i = MHCourseLayout.world_point_mm(document.get("course", {}) as Dictionary,
					int(hole.get("slot_id", -1)), int(green_v[0]) * 100, int(green_v[1]) * 100)
				if green_mm.x >= 0:
					start = Vector3(float(green_mm.x) / 1000.0, 0.0, float(green_mm.y) / 1000.0)
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
