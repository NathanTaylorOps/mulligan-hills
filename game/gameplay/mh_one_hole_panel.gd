class_name MHOneHolePanel
extends VBoxContainer
## Development controls for an exact player-edited short par 3. Not final phone UI or career golf.
var live: MHLiveConstruction
var length_yd: int = 60
var half_width_yd: int = 8
var water: bool = false
var _preview_draft: bool = false
var canonical_draft: Dictionary = {}
var follow_ball: bool = true
var aim_x: int = 0
var aim_y: int = 6000
var _info: Label
var _world: Node3D
var _ball: MeshInstance3D
var _path: Node3D
var _feedback: Label
var _scroll: MHScrollBox
var _toggle: MHTapButton
var craft_surface: int = MHCraftHole.Surface.FAIRWAY
var craft_mode: StringName = &"surface"
var _craft_stroke_open: bool = false
var _craft_last_tile: Vector2i = Vector2i(-1, -1)
var _craft_level_height: int = 0
## Header only (body hidden). Layout is recomputed by the scene on `layout_changed`.
var collapsed: bool = false
signal layout_changed()
var _aim: MeshInstance3D
const ORIGIN: Array = [480, 340]

func setup(scene: MHLiveConstruction) -> void:
	live = scene
	# No absolute position or size: the scene's frame (MHLiveLayout zones) sizes this panel. Header stays visible
	# when collapsed; everything else lives in a scroll box so a short free area never overlaps its neighbours.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var head: HBoxContainer = MHUIKit.hbox(8)
	add_child(head)
	var title: Label = MHUIKit.label("One-hole practice", &"", false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	_toggle = MHUIKit.button(live.shell.ctx, "Collapse", &"ChipButton", 112)
	_toggle.pressed.connect(toggle_collapsed)
	head.add_child(_toggle)
	_scroll = MHScrollBox.new()
	add_child(_scroll)
	var content: VBoxContainer = MHUIKit.vbox(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	content.add_child(MHUIKit.label("Development prototype: no prizes or XP."))
	_info = MHUIKit.label("")
	content.add_child(_info)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback = MHUIKit.label("Tap the course to aim. Play shot is a separate confirmation.")
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_feedback)
	var craft_tools: HFlowContainer = MHUIKit.flow(6)
	content.add_child(craft_tools)
	_surface_button(craft_tools, "Rough", MHCraftHole.Surface.ROUGH)
	_surface_button(craft_tools, "Fairway", MHCraftHole.Surface.FAIRWAY)
	_surface_button(craft_tools, "First cut", MHCraftHole.Surface.FIRST_CUT)
	_surface_button(craft_tools, "Deep rough", MHCraftHole.Surface.DEEP_ROUGH)
	_surface_button(craft_tools, "Green", MHCraftHole.Surface.GREEN)
	_surface_button(craft_tools, "Fringe", MHCraftHole.Surface.FRINGE)
	_surface_button(craft_tools, "Tee grass", MHCraftHole.Surface.TEE)
	_surface_button(craft_tools, "Bunker", MHCraftHole.Surface.BUNKER)
	_surface_button(craft_tools, "Waste", MHCraftHole.Surface.WASTE)
	_surface_button(craft_tools, "Water", MHCraftHole.Surface.WATER)
	_surface_button(craft_tools, "Out of bounds", MHCraftHole.Surface.OUT_OF_BOUNDS)
	_surface_button(craft_tools, "Path", MHCraftHole.Surface.PATH)
	_surface_button(craft_tools, "Dirt", MHCraftHole.Surface.DIRT)
	_button(craft_tools, "Raise", func() -> void: craft_mode = &"raise"; _describe())
	_button(craft_tools, "Lower", func() -> void: craft_mode = &"lower"; _describe())
	_button(craft_tools, "Smooth", func() -> void: craft_mode = &"smooth"; _describe())
	_button(craft_tools, "Level", func() -> void: craft_mode = &"level"; _describe())
	_button(craft_tools, "Place tee", func() -> void: craft_mode = &"tee"; _describe())
	_button(craft_tools, "Place pin", func() -> void: craft_mode = &"pin"; _describe())
	_button(craft_tools, "Undo craft", _craft_undo)
	_button(craft_tools, "Redo craft", _craft_redo)
	var design: HFlowContainer = MHUIKit.flow(6)
	content.add_child(design)
	# The old rectangular Length/Narrow/Side-water controls modified a parallel
	# prototype representation, not the authoritative MHCraftHole. Keeping them
	# visible made them look functional while they could not change the craft
	# course. Canonical craft is now the only authoring path.
	_button(design, "Finalize hole", _finalize)
	var shots: HFlowContainer = MHUIKit.flow(6)
	content.add_child(shots)
	_button(shots, "Aim at cup", _aim_cup)
	_button(shots, "Back to golfer", _back_to_golfer)
	_button(shots, "Course overview", _overview)
	_button(shots, "Play shot", _shoot)
	_button(shots, "New practice round", _restart)
	_button(shots, "Close", close_preview)
	_world = Node3D.new()
	live.add_child(_world)
	_world.hide()
	var layouts: Array = live.session.hole_definitions()
	if not layouts.is_empty():
		_sync_legacy_controls(layouts[0] as Dictionary)
	_describe()
	hide()

func set_collapsed(value: bool) -> void:
	collapsed = value
	if _scroll != null:
		_scroll.visible = not collapsed
	if _toggle != null:
		_toggle.text = "Expand" if collapsed else "Collapse"
	layout_changed.emit()

func toggle_collapsed() -> void:
	set_collapsed(not collapsed)

func close_preview() -> void:
	if live != null and live.aim_input != null:
		live.aim_input.cancel_all()
	hide()
	if _world != null:
		_world.hide()
	if live != null and live.chunks != null:
		live.chunks.show()


func open() -> void:
	set_collapsed(false)
	live.router.cancel_world_input()
	if live.aim_input != null:
		live.aim_input.taps.clear()
	live.shell.show_root(MHScreenIds.HUD)
	live.chunks.hide() # Flat exact-layout view; arbitrary brush terrain is not claimed as rated geometry.
	show()
	_world.show()
	_follow_camera()
	_draw()
	_describe()

func _button(parent: Control, title: String, action: Callable) -> void:
	var b: MHTapButton = MHUIKit.button(live.shell.ctx, title, &"ChipButton", 110)
	parent.add_child(b)
	b.pressed.connect(action)


func _surface_button(parent: Control, title: String, surface_id: int) -> void:
	_button(parent, title, func() -> void:
		craft_surface = surface_id
		craft_mode = &"surface"
		_describe())

func set_canonical_draft(layout: Dictionary) -> bool:
	var validation: Dictionary = MHRatingEngine.validate_input({"schema": 1, "engine": MHRatingEngine.RATING_VERSION, "hole": layout})
	if not bool(validation.get("ok", false)) or int(layout.get("slot_id", -1)) != 0:
		return false
	canonical_draft = layout.duplicate(true)
	_preview_draft = true
	if _world != null:
		_draw()
		_describe()
	return true

func clear_canonical_draft() -> void:
	canonical_draft.clear()

func _layout() -> Dictionary:
	if not canonical_draft.is_empty():
		return canonical_draft.duplicate(true)
	var features: Array = [{"t": "fairway", "rect": [-half_width_yd, 0, half_width_yd, length_yd]}]
	if water:
		features.append({"t": "water", "rect": [10, 20, 14, 30]})
	return {"slot_id": 0, "tee": [0, 0], "green": [0, length_yd, 5], "features": features}

func craft_at_tile(c: int, r: int) -> bool:
	if live == null or live.craft_hole == null or not live.craft_hole.in_bounds(c, r):
		return false
	var h: MHCraftHole = live.craft_hole
	if craft_mode == &"tee":
		h.tees.clear()
		h.add_tee(c, r)
	elif craft_mode == &"pin":
		if h.pins.size() >= MHCraftHole.MAX_PINS:
			h.pins.clear()
		h.add_pin(c, r)
	elif craft_mode == &"raise" or craft_mode == &"lower":
		h.begin_stroke()
		h.raise_disc(c, r, 1, 1 if craft_mode == &"raise" else -1)
		h.commit_stroke()
	else:
		h.begin_stroke()
		h.paint_disc(c, r, 1, craft_surface)
		h.commit_stroke()
	_refresh_canonical_craft()
	return true

func _refresh_canonical_craft() -> void:
	var problems: Array = MHCraftConvert.problems(live.craft_hole)
	if problems.is_empty():
		set_canonical_draft(live.canonical_craft_draft())
	else:
		canonical_draft.clear()
		_preview_draft = true
		var labels: PackedStringArray = PackedStringArray()
		for problem: Variant in problems:
			labels.append(str(problem))
		_info.text = "Craft hole needs: " + ", ".join(labels)
		_draw()

func _craft_undo() -> void:
	if live.craft_hole != null and live.craft_hole.undo():
		_refresh_canonical_craft()

func _craft_redo() -> void:
	if live.craft_hole != null and live.craft_hole.redo():
		_refresh_canonical_craft()

func _draft_changed() -> void:
	_preview_draft = true
	_draw()
	_describe()

func _finalize() -> void:
	if live.shell.modal_id() != "":
		return
	if not _preview_draft or live == null or live.craft_hole == null:
		_info.text = "This saved hole is in play mode. Full saved-hole redesign needs the layout-to-craft editor path; it will not be replaced by a fallback hole."
		return
	var problems: Array = MHCraftConvert.problems(live.craft_hole)
	if not problems.is_empty():
		var labels: PackedStringArray = PackedStringArray()
		for problem: Variant in problems:
			labels.append(str(problem))
		_info.text = "Cannot finalize yet: " + ", ".join(labels)
		return
	var h: Dictionary = live.canonical_craft_draft()
	if h.is_empty() or not set_canonical_draft(h):
		_info.text = "Cannot finalize: the craft hole did not produce a valid canonical layout."
		return
	live.router.cancel_world_input()
	if live.aim_input != null:
		live.aim_input.cancel_all()
	var encoded: MHSaveResult = MHCourseLayout.encode([h], live.document["course"] as Dictionary, [ORIGIN])
	if not encoded.is_ok():
		_info.text = encoded.message
		return
	var result: Dictionary = live.session.submit_course([h])
	if not bool(result["ok"]):
		_info.text = "Cannot finalize: " + str(result["reason"])
		return
	_preview_draft = false
	canonical_draft.clear()
	live.document["course"] = encoded.value
	live.document["min_reader_version"] = 3
	live.session.practice = null # A redesign cannot continue a round on a previous layout.
	_restart()
	live._request_save()
	_draw()
	_describe()


func _restart() -> void:
	if live.shell.modal_id() != "":
		return
	var layouts: Array = live.session.hole_definitions()
	if layouts.is_empty():
		_info.text = "Finalize your hole first."
		return
	_preview_draft = false
	canonical_draft.clear()
	var current: Dictionary = layouts[0]
	_sync_legacy_controls(current)
	live.session.practice = MHPracticeRound.create(layouts[0] as Dictionary,
		MHRatingEngine.seed_for(0, {"save_secret": live.session.save_secret, "rating_epoch": live.session.rating_epoch}))
	live._request_save()
	_aim_cup()
	_follow_camera()
	_draw()
	_describe()

func _sync_legacy_controls(current: Dictionary) -> void:
	# The old prototype controls are only a convenience for its rectangular fallback layout.
	# Canonical craft layouts may contain arbitrary feature shapes and relief, so never infer them unsafely.
	if current.has("relief") or not current.has("features"):
		return
	var features: Array = current["features"]
	if features.is_empty() or typeof(features[0]) != TYPE_DICTIONARY or not (features[0] as Dictionary).has("rect"):
		return
	var rect: Array = (features[0] as Dictionary)["rect"]
	var green: Array = current["green"]
	if rect.size() == 4 and green.size() >= 2:
		length_yd = int(green[1])
		half_width_yd = absi(int(rect[2]))
		water = features.size() > 1

func _aim_cup() -> void:
	if live.session.practice != null:
		aim_x = live.session.practice.hole.gx
		aim_y = live.session.practice.hole.gy
	_move_aim()

func _shoot() -> void:
	if live.shell.modal_id() != "":
		return
	if live.session.practice == null:
		_info.text = "Finalize, then start a practice round."
		return
	if _preview_draft:
		_info.text = "Finalize the draft before playing it. Your current round was preserved."
		return
	var result: Dictionary = live.session.practice.play(aim_x, aim_y)
	if not bool(result["ok"]):
		_info.text = "Round finished or aim is at the ball. Start another round or change aim."
		return
	live._request_save()
	_follow_camera()
	_draw()
	_describe()
	if int(result["penalty"]) > 0:
		_info.text += " | Penalty +1"
	elif bool(result["tree"]):
		_info.text += " | Tree hit"

func _describe() -> void:
	if live == null:
		return
	if _preview_draft and live.craft_hole != null:
		var craft: MHCraftHole = live.craft_hole
		var hole_length: int = MHCraftConvert.length_yd(craft, 0, 0)
		var price: int = 0 if not live.session.hole_definitions().is_empty() else live.session.economy.hole_cost_cents()
		var tool_name: String = _surface_name(craft_surface) if craft_mode == &"surface" else str(craft_mode).capitalize()
		_info.text = "Craft draft: %d yd tee-to-pin | Finalize $%d | Tool: %s" % [hole_length, price / 100, tool_name]
		var problems: Array = MHCraftConvert.problems(craft)
		if not problems.is_empty():
			var labels: PackedStringArray = PackedStringArray()
			for problem: Variant in problems:
				labels.append(str(problem))
			_info.text += " | Needs: " + ", ".join(labels)
	else:
		_info.text = "Finalized hole"
	var r: MHPracticeRound = live.session.practice
	if r != null:
		_info.text += " | %d strokes | %s" % [r.strokes, "Picked up" if r.picked_up else ("Holed" if r.finished else "Playing")]
	var scores: Array = live.session.hole_results()
	if not scores.is_empty():
		_info.text += " | Official hole score %d/100" % int(scores[0]["score"])


func _draw() -> void:
	_path = null
	for child: Node in _world.get_children():
		_world.remove_child(child)
		child.queue_free()
	_box(Vector3(64, -0.1, 64), Vector3(128, 0.1, 128), Color(0.27, 0.44, 0.21))
	var layouts: Array = live.session.hole_definitions()
	var drawing_craft: bool = live != null and live.craft_hole != null and (_preview_draft or layouts.is_empty())
	var h: Dictionary = _layout() if layouts.is_empty() or _preview_draft else layouts[0]
	if drawing_craft:
		# The craft mesh already owns every painted surface and marker. Do not draw
		# the legacy rectangle proxy over it; that hid invalid/intermediate edits
		# behind a stale fallback fairway.
		_draw_craft_terrain(live.craft_hole)
	else:
		for row: Variant in h["features"]:
			var feature: Dictionary = row
			if not feature.has("rect"):
				continue
			var rect: Array = feature["rect"]
			var cx: int = (int(rect[0]) + int(rect[2])) * 50
			var cy: int = (int(rect[1]) + int(rect[3])) * 50
			var a: Vector3 = _position(int(rect[0]) * 100, int(rect[1]) * 100, 0.02)
			var b: Vector3 = _position(int(rect[2]) * 100, int(rect[3]) * 100, 0.02)
			var centre: Vector3 = (a + b) / 2.0
			centre.y = _ground_height(cx, cy) + 0.02
			_box(centre, Vector3(absf(b.x - a.x), 0.03, absf(b.z - a.z)),
				Color(0.12, 0.4, 0.7) if str(feature["t"]) == "water" else Color(0.36, 0.64, 0.23))
		var g: Array = h["green"]
		var circle: CylinderMesh = CylinderMesh.new()
		circle.top_radius = float(g[2]) * 0.9144
		circle.bottom_radius = circle.top_radius
		circle.height = 0.03
		_mesh(circle, _position_on_ground(int(g[0]) * 100, int(g[1]) * 100, 0.06), Color(0.5, 0.78, 0.3))
		_box(_position_on_ground(int(g[0]) * 100, int(g[1]) * 100, 1.0), Vector3(0.12, 2, 0.12), Color.WHITE)
	_ball = _marker(Color.WHITE, 0.35)
	var r: MHPracticeRound = live.session.practice
	if r != null and not _preview_draft:
		_ball.position = _position_on_ground(r.x, r.y, 0.45)
	elif drawing_craft and not live.craft_hole.tees.is_empty():
		var tee_tile: Vector2i = live.craft_hole.tees[0] as Vector2i
		var tee_centre: Vector2i = live.craft_hole.tile_centre_yd(tee_tile.x, tee_tile.y)
		_ball.position = _position_on_ground(tee_centre.x * 100, tee_centre.y * 100, 0.45)
	else:
		var tee: Array = h["tee"]
		_ball.position = _position_on_ground(int(tee[0]) * 100, int(tee[1]) * 100, 0.45)
	_aim = _marker(Color(1, 0.8, 0.1), 0.55)
	_aim.visible = not drawing_craft
	_move_aim()

func _draw_craft_terrain(hole: MHCraftHole) -> void:
	# Height preview must follow the editable grid even while the draft is
	# temporarily invalid (for example while moving a pin off a green).
	var layout: Dictionary = _layout()
	var relief: Dictionary = MHCraftConvert.relief_for(hole)
	if relief.is_empty():
		layout.erase("relief")
	else:
		layout["relief"] = relief
	var relief_hole: MHRHole = MHRHole.from_def(layout)
	var builders: Dictionary = {}
	for surface_id: int in range(MHCraftHole.SURFACE_COUNT):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		builders[surface_id] = st
	for r: int in range(hole.rows):
		for c: int in range(hole.cols):
			_append_craft_tile(builders[hole.get_surface(c, r)] as SurfaceTool, relief_hole, hole, c, r)
	for surface_id: int in range(MHCraftHole.SURFACE_COUNT):
		var st: SurfaceTool = builders[surface_id] as SurfaceTool
		var mesh: ArrayMesh = st.commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var material: StandardMaterial3D = _craft_material(surface_id)
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		_world.add_child(instance)
	_draw_surface_edges(hole, relief_hole)
	for tee: Variant in hole.tees:
		var t: Vector2i = tee as Vector2i
		var tc: Vector2i = hole.tile_centre_yd(t.x, t.y)
		_marker_at(_position_on_ground(tc.x * 100, tc.y * 100, 0.35), Color(0.95, 0.95, 0.95), 0.28)
	for pin: Variant in hole.pins:
		var p: Vector2i = pin as Vector2i
		var pc: Vector2i = hole.tile_centre_yd(p.x, p.y)
		_box(_position_on_ground(pc.x * 100, pc.y * 100, 0.75), Vector3(0.08, 1.5, 0.08), Color.WHITE)
	for tree: Variant in hole.trees:
		_draw_craft_tree(tree as Vector2i)

func _append_craft_tile(st: SurfaceTool, relief_hole: MHRHole, hole: MHCraftHole, c: int, r: int) -> void:
	var x0: int = hole.tile_x0_yd(c) * 100
	var x1: int = (hole.tile_x0_yd(c) + MHCraftHole.TILE_YD) * 100
	var y0: int = hole.tile_y0_yd(r) * 100
	var y1: int = (hole.tile_y0_yd(r) + MHCraftHole.TILE_YD) * 100
	var lift: float = 0.015 if hole.get_surface(c, r) == MHCraftHole.Surface.WATER else 0.035
	for point: Vector2i in [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x1, y1),
			Vector2i(x0, y0), Vector2i(x1, y1), Vector2i(x0, y1)]:
		st.set_normal(_craft_normal(relief_hole, point.x, point.y))
		var z: float = float(relief_hole.z_at(point.x, point.y)) / 1000.0
		st.add_vertex(_position(point.x, point.y, z + lift))

func _draw_surface_edges(hole: MHCraftHole, relief_hole: MHRHole) -> void:
	# Sparse borders only where high-value golf surfaces meet another surface.
	for r: int in range(hole.rows):
		for c: int in range(hole.cols):
			var s: int = hole.get_surface(c, r)
			if s != MHCraftHole.Surface.GREEN and s != MHCraftHole.Surface.BUNKER and s != MHCraftHole.Surface.WATER:
				continue
			var centre: Vector2i = hole.tile_centre_yd(c, r)
			for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nc: int = c + d.x
				var nr: int = r + d.y
				if hole.in_bounds(nc, nr) and hole.get_surface(nc, nr) == s:
					continue
				var half: int = MHCraftHole.TILE_YD * 50
				var ex: int = centre.x * 100 + d.x * half
				var ey: int = centre.y * 100 + d.y * half
				var length_m: float = float(MHCraftHole.TILE_YD) * 0.9144
				var size: Vector3 = Vector3(0.045, 0.035, length_m) if d.x != 0 else Vector3(length_m, 0.035, 0.045)
				var z: float = float(relief_hole.z_at(ex, ey)) / 1000.0 + 0.065
				_box(_position(ex, ey, z), size, _edge_color(s))

func _edge_color(surface_id: int) -> Color:
	match surface_id:
		MHCraftHole.Surface.GREEN: return Color(0.66, 0.86, 0.40)
		MHCraftHole.Surface.BUNKER: return Color(0.83, 0.76, 0.56)
		MHCraftHole.Surface.WATER: return Color(0.22, 0.55, 0.82)
		_: return Color.WHITE

func _craft_normal(relief_hole: MHRHole, x: int, y: int) -> Vector3:
	var sample: int = MHCraftHole.TILE_YD * 100
	var left: float = float(relief_hole.z_at(x - sample, y)) / 1000.0
	var right: float = float(relief_hole.z_at(x + sample, y)) / 1000.0
	var down: float = float(relief_hole.z_at(x, y - sample)) / 1000.0
	var up: float = float(relief_hole.z_at(x, y + sample)) / 1000.0
	var run: float = float(sample) * 0.009144
	return Vector3(left - right, run * 2.0, down - up).normalized()

func _craft_material(surface_id: int) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _surface_color(surface_id)
	material.roughness = 0.92
	match surface_id:
		MHCraftHole.Surface.GREEN:
			material.roughness = 0.72
		MHCraftHole.Surface.BUNKER, MHCraftHole.Surface.WASTE:
			material.roughness = 1.0
		MHCraftHole.Surface.WATER:
			material.roughness = 0.18
			material.metallic = 0.08
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var water: Color = material.albedo_color
			water.a = 0.82
			material.albedo_color = water
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		MHCraftHole.Surface.PATH:
			material.roughness = 0.86
	return material

func _draw_craft_tree(point: Vector2i) -> void:
	var trunk_pos: Vector3 = _position_on_ground(point.x * 100, point.y * 100, 1.0)
	_box(trunk_pos, Vector3(0.35, 2.0, 0.35), Color(0.34, 0.23, 0.12))
	_marker_at(_position_on_ground(point.x * 100, point.y * 100, 2.4), Color(0.16, 0.38, 0.14), 1.25)

func _surface_name(surface_id: int) -> String:
	match surface_id:
		MHCraftHole.Surface.ROUGH: return "Rough"
		MHCraftHole.Surface.FAIRWAY: return "Fairway"
		MHCraftHole.Surface.FIRST_CUT: return "First cut"
		MHCraftHole.Surface.DEEP_ROUGH: return "Deep rough"
		MHCraftHole.Surface.GREEN: return "Green"
		MHCraftHole.Surface.FRINGE: return "Fringe"
		MHCraftHole.Surface.TEE: return "Tee grass"
		MHCraftHole.Surface.BUNKER: return "Bunker"
		MHCraftHole.Surface.WASTE: return "Waste"
		MHCraftHole.Surface.WATER: return "Water"
		MHCraftHole.Surface.OUT_OF_BOUNDS: return "Out of bounds"
		MHCraftHole.Surface.PATH: return "Path"
		MHCraftHole.Surface.DIRT: return "Dirt"
		_: return "Surface"


func _surface_color(surface_id: int) -> Color:
	match surface_id:
		MHCraftHole.Surface.FAIRWAY: return Color(0.36, 0.64, 0.23)
		MHCraftHole.Surface.FIRST_CUT: return Color(0.31, 0.55, 0.21)
		MHCraftHole.Surface.DEEP_ROUGH: return Color(0.18, 0.36, 0.14)
		MHCraftHole.Surface.GREEN: return Color(0.5, 0.78, 0.3)
		MHCraftHole.Surface.FRINGE: return Color(0.42, 0.68, 0.26)
		MHCraftHole.Surface.TEE: return Color(0.46, 0.72, 0.29)
		MHCraftHole.Surface.BUNKER: return Color(0.72, 0.66, 0.48)
		MHCraftHole.Surface.WASTE: return Color(0.57, 0.49, 0.35)
		MHCraftHole.Surface.WATER: return Color(0.12, 0.4, 0.7)
		MHCraftHole.Surface.OUT_OF_BOUNDS: return Color(0.24, 0.20, 0.18)
		MHCraftHole.Surface.PATH: return Color(0.42, 0.40, 0.36)
		MHCraftHole.Surface.DIRT: return Color(0.45, 0.32, 0.20)
		_: return Color(0.27, 0.44, 0.21)

func _marker_at(pos: Vector3, color: Color, radius: float) -> MeshInstance3D:
	var marker: MeshInstance3D = _marker(color, radius)
	marker.position = pos
	return marker

func _move_aim() -> void:
	if _aim != null:
		_aim.position = _position_on_ground(aim_x, aim_y, 0.7)
	_refresh_path()

func _ground_height(cx: int, cy: int) -> float:
	var layouts: Array = live.session.hole_definitions() if live != null else []
	var h: Dictionary = _layout() if _preview_draft or layouts.is_empty() else layouts[0]
	if _preview_draft and live != null and live.craft_hole != null:
		# Keep markers and picking visually attached to the editable height grid even
		# while a temporary validation problem has cleared canonical_draft.
		var relief: Dictionary = MHCraftConvert.relief_for(live.craft_hole)
		if relief.is_empty():
			h.erase("relief")
		else:
			h["relief"] = relief
	if h.has("relief"):
		var hole: MHRHole = MHRHole.from_def(h)
		return float(hole.z_at(cx, cy)) / 1000.0
	return 0.0

func _position_on_ground(cx: int, cy: int, offset: float) -> Vector3:
	return _position(cx, cy, _ground_height(cx, cy) + offset)

func _position(cx: int, cy: int, height: float) -> Vector3:
	return Vector3(float(MHCourseLayout.world_mm(int(ORIGIN[0]), cx)) / 1000.0, height,
		float(MHCourseLayout.world_mm(int(ORIGIN[1]), cy)) / 1000.0)

func _marker(color: Color, radius: float) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	return _mesh(sphere, Vector3.ZERO, color)

func _box(pos: Vector3, size_value: Vector3, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = size_value
	_mesh(box, pos, color)

func _mesh(mesh_value: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.mesh = mesh_value
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	m.material_override = mat
	m.position = pos
	_world.add_child(m)
	return m


## The save codec supports more shapes than this small authoring/view prototype does.
static func supported(course: Dictionary) -> bool:
	# This development view still supports one hole at its fixed world origin, but
	# it must not reject canonical geometry merely because it contains relief or a
	# richer set of rating rectangles. MHCourseLayout + MHRatingEngine are the
	# authority for whether the saved hole is valid; the panel is only a viewer/
	# authoring surface.
	var decoded: MHSaveResult = MHCourseLayout.decode(course)
	if not decoded.is_ok():
		return false
	var rows: Array = course.get("holes", []) as Array
	if rows.is_empty():
		return true
	if rows.size() != 1 or typeof(rows[0]) != TYPE_DICTIONARY:
		return false
	var row: Dictionary = rows[0] as Dictionary
	if row.get("origin_dm", []) != ORIGIN or typeof(row.get("layout", null)) != TYPE_DICTIONARY:
		return false
	var h: Dictionary = row["layout"] as Dictionary
	if int(h.get("slot_id", -1)) != 0:
		return false
	var validation: Dictionary = MHRatingEngine.validate_input({
		"schema": 1,
		"engine": MHRatingEngine.RATING_VERSION,
		"hole": h,
	})
	return bool(validation.get("ok", false))


func blocks_world_tap(pos: Vector2) -> bool:
	# A visible panel that has not been laid out yet (zero size) still counts as 1x1 so it never leaks a tap.
	var own: Rect2 = get_global_rect()
	own.size = own.size.max(Vector2.ONE)
	if own.has_point(pos) or live.shell.modal_id() != "":
		return true
	for getter: Variant in live.shell.region_rects().values():
		var rect: Rect2 = (getter as Callable).call()
		if rect.has_point(pos):
			return true
	for n: Node in get_tree().get_nodes_in_group(MHTapButton.GROUP):
		var b: Button = n as Button
		if b != null and not is_ancestor_of(b) and b.is_visible_in_tree() and b.get_global_rect().has_point(pos):
			return true
	return false

func _screen_ground_hit(pos: Vector2, layout: Dictionary) -> Dictionary:
	var camera: Camera3D = live.controller.camera
	var origin: Vector3 = camera.project_ray_origin(pos)
	var direction: Vector3 = camera.project_ray_normal(pos)
	if direction.y >= -0.00001:
		return {"ok": false}
	if not layout.has("relief"):
		var flat_distance: float = -origin.y / direction.y
		if flat_distance <= 0.0:
			return {"ok": false}
		return {"ok": true, "hit": origin + direction * flat_distance}
	var relief_hole: MHRHole = MHRHole.from_def(layout)
	# Bracket the full craft elevation range, then intersect the ray with the
	# authoritative bilinear heightfield. This keeps screen picking aligned with
	# visible hills instead of pretending every edit happens on y=0.
	var low_t: float = 0.0
	var low_plane: float = -40.0 # Below the rating schema minimum relief (-32.768 m).
	var high_t: float = (low_plane - origin.y) / direction.y
	if high_t <= 0.0:
		return {"ok": false}
	for _i: int in range(20):
		var mid_t: float = (low_t + high_t) * 0.5
		var point: Vector3 = origin + direction * mid_t
		var local_x_mm: int = roundi(point.x * 1000.0) - int(ORIGIN[0]) * 100
		var local_y_mm: int = roundi(point.z * 1000.0) - int(ORIGIN[1]) * 100
		var x_cy: int = MHRMath.rdiv(local_x_mm * 1000, 9144)
		var y_cy: int = MHRMath.rdiv(local_y_mm * 1000, 9144)
		var ground: float = float(relief_hole.z_at(x_cy, y_cy)) / 1000.0
		if point.y > ground:
			low_t = mid_t
		else:
			high_t = mid_t
	return {"ok": true, "hit": origin + direction * high_t}


func _craft_tile_from_screen(pos: Vector2) -> Vector2i:
	if live == null or live.craft_hole == null:
		return Vector2i(-1, -1)
	var layout: Dictionary = _layout()
	var relief: Dictionary = MHCraftConvert.relief_for(live.craft_hole)
	if relief.is_empty():
		layout.erase("relief")
	else:
		layout["relief"] = relief
	var result: Dictionary = _screen_ground_hit(pos, layout)
	if not bool(result.get("ok", false)):
		return Vector2i(-1, -1)
	var hit: Vector3 = result["hit"] as Vector3
	var local_x_mm: int = roundi(hit.x * 1000.0) - int(ORIGIN[0]) * 100
	var local_y_mm: int = roundi(hit.z * 1000.0) - int(ORIGIN[1]) * 100
	var x_yd: int = MHRMath.rdiv(local_x_mm * 1000, 9144)
	var y_yd: int = MHRMath.rdiv(local_y_mm * 1000, 9144)
	return live.craft_hole.tile_at_yd(x_yd, y_yd)


func craft_from_screen(pos: Vector2) -> bool:
	var tile: Vector2i = _craft_tile_from_screen(pos)
	if tile.x < 0:
		return false
	return craft_at_tile(tile.x, tile.y)


func _apply_craft_stroke_tile(tile: Vector2i) -> bool:
	if live == null or live.craft_hole == null or not live.craft_hole.in_bounds(tile.x, tile.y):
		return false
	var h: MHCraftHole = live.craft_hole
	if craft_mode == &"raise" or craft_mode == &"lower":
		h.raise_disc(tile.x, tile.y, 1, 1 if craft_mode == &"raise" else -1)
	elif craft_mode == &"smooth":
		h.smooth_disc(tile.x, tile.y, 1)
	elif craft_mode == &"level":
		h.level_disc(tile.x, tile.y, 1, _craft_level_height)
	elif craft_mode == &"surface":
		h.paint_disc(tile.x, tile.y, 1, craft_surface)
	else:
		return false
	return true


func craft_stroke_begin_from_screen(pos: Vector2) -> bool:
	var tile: Vector2i = _craft_tile_from_screen(pos)
	if tile.x < 0:
		return false
	if craft_mode == &"tee" or craft_mode == &"pin":
		return craft_at_tile(tile.x, tile.y)
	if live.craft_hole.is_stroke_open():
		live.craft_hole.cancel_stroke()
	if not live.craft_hole.begin_stroke():
		return false
	_craft_stroke_open = true
	_craft_last_tile = tile
	if craft_mode == &"level":
		_craft_level_height = live.craft_hole.get_height(tile.x, tile.y)
	_apply_craft_stroke_tile(tile)
	return true


func craft_stroke_move_from_screen(pos: Vector2) -> bool:
	if not _craft_stroke_open or live == null or live.craft_hole == null:
		return false
	var tile: Vector2i = _craft_tile_from_screen(pos)
	if tile.x < 0 or tile == _craft_last_tile:
		return false
	var start: Vector2i = _craft_last_tile
	var steps: int = maxi(absi(tile.x - start.x), absi(tile.y - start.y))
	for i: int in range(1, steps + 1):
		var c: int = start.x + roundi(float(tile.x - start.x) * float(i) / float(steps))
		var r: int = start.y + roundi(float(tile.y - start.y) * float(i) / float(steps))
		_apply_craft_stroke_tile(Vector2i(c, r))
	_craft_last_tile = tile
	return true


func craft_stroke_end() -> bool:
	if not _craft_stroke_open or live == null or live.craft_hole == null:
		return false
	_craft_stroke_open = false
	_craft_last_tile = Vector2i(-1, -1)
	var changed: bool = live.craft_hole.commit_stroke()
	if changed:
		_refresh_canonical_craft()
	return changed


func craft_stroke_cancel() -> void:
	if live != null and live.craft_hole != null and live.craft_hole.is_stroke_open():
		live.craft_hole.cancel_stroke()
	_craft_stroke_open = false
	_craft_last_tile = Vector2i(-1, -1)

func aim_from_screen(pos: Vector2) -> bool:
	var layouts: Array = live.session.hole_definitions()
	var layout: Dictionary = _layout() if layouts.is_empty() or _preview_draft else layouts[0]
	var result: Dictionary = _screen_ground_hit(pos, layout)
	if not bool(result.get("ok", false)):
		return false
	var hit: Vector3 = result["hit"] as Vector3
	if hit.x < 0.0 or hit.x >= 128.0 or hit.z < 0.0 or hit.z >= 128.0:
		return false
	# Only the input/render boundary uses float coordinates; gameplay aim remains integer centiyards.
	aim_x = MHRMath.rdiv((roundi(hit.x * 1000.0) - int(ORIGIN[0]) * 100) * 1000, 9144)
	aim_y = MHRMath.rdiv((roundi(hit.z * 1000.0) - int(ORIGIN[1]) * 100) * 1000, 9144)
	_move_aim()
	return true

func _refresh_path() -> void:
	if _world == null or _aim == null:
		return
	if _path != null and is_instance_valid(_path):
		_world.remove_child(_path)
		_path.queue_free()
	_path = Node3D.new()
	_world.add_child(_path)
	var r: MHPracticeRound = live.session.practice
	if _preview_draft:
		_feedback.text = "Edit hole: choose a tool, then click or drag on the course. Desktop: right-drag rotate, middle-drag pan, wheel zoom. Touch: one finger edits; two fingers move the camera."
		return
	if r == null:
		_feedback.text = "Finalize the hole to begin practice."
		return
	var preview: Dictionary = r.aim_preview(aim_x, aim_y)
	if not bool(preview.get("ok", false)):
		return
	if r.finished:
		_feedback.text = "Round finished. Start another practice round."
		return
	var a: Vector3 = _position_on_ground(r.x, r.y, 0.18)
	var b: Vector3 = _position_on_ground(aim_x, aim_y, 0.18)
	_path_line(a, b, Color(1, 0.8, 0.1))
	var landing: Vector3 = _position_on_ground(int(preview["landing_x"]), int(preview["landing_y"]), 0.22)
	var radius: float = maxf(0.5, float(preview["spread_cy"]) * 0.009144)
	for i: int in range(16):
		var t0: float = float(i) * TAU / 16.0
		var t1: float = float(i + 1) * TAU / 16.0
		_path_line(landing + Vector3(cos(t0) * radius, 0, sin(t0) * radius),
			landing + Vector3(cos(t1) * radius, 0, sin(t1) * radius), Color(1, 0.8, 0.1))
	_feedback.text = "%d yd target | %s. Ring is rough shot spread, not a guaranteed landing." % [int(preview["distance_cy"]) / 100,
		"Within reach" if bool(preview["reachable"]) else "Beyond reach: shot stops short"]
	var target_lie: int = int(preview["landing_lie"])
	if target_lie == MHRHole.LIE_WATER:
		_feedback.text += " Water on intended landing."
	elif target_lie == MHRHole.LIE_OB:
		_feedback.text += " Intended landing out of bounds."
	elif target_lie == MHRHole.LIE_BUNKER:
		_feedback.text += " Intended landing in sand."

func _path_line(a: Vector3, b: Vector3, color: Color) -> void:
	var length_value: float = a.distance_to(b)
	if length_value < 0.001:
		return
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.1, 0.035, length_value)
	var line: MeshInstance3D = MeshInstance3D.new()
	line.mesh = box
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	line.material_override = material
	line.position = (a + b) / 2.0
	line.rotation.y = atan2(b.x - a.x, b.z - a.z)
	_path.add_child(line)


func _back_to_golfer() -> void:
	if live.shell.modal_id() != "":
		return
	follow_ball = true
	if live.aim_input != null:
		live.aim_input.taps.clear()
	_follow_camera()

func _overview() -> void:
	if live.shell.modal_id() != "":
		return
	follow_ball = false
	if live.aim_input != null:
		live.aim_input.taps.clear()
	live.controller.focus_target(Vector3(64, -20, 64), 150.0)

func _follow_camera() -> void:
	if not follow_ball:
		return
	var r: MHPracticeRound = live.session.practice
	var point: Vector3 = _position(r.x if r != null else 0, r.y if r != null else 0, -20.0)
	# Downward framing bias keeps the ball above the prototype's lower controls; device tuning pending.
	live.controller.focus_target(point, 100.0)
