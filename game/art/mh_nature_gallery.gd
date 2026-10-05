class_name MHNatureGallery
extends Node3D
## Art gallery scene (res://art/mh_nature_gallery.tscn): every nature kind, golfer and prop in a grid,
## all variants and LODs, with triangle counts, an orbit camera and a stress mode (240 trees in
## MultiMeshes) for a frame-rate look on a phone. Everything is built in code (DEC-062).
##
## Controls: drag to orbit, mouse wheel or the Zoom buttons to zoom. Buttons use MHTapButton +
## MHTouchBridge because emulate_mouse_from_touch is off (see MHTapButton).
##
## `build_content()` needs no scene tree, so tests can call it on a bare instance.
## STATUS: NOT YET RUN in Godot.

const CATEGORIES: Array = ["trees", "plants", "rocks", "golfers", "props", "stress"]
const LOD_LABELS: Array = ["LOD 0", "LOD 1", "LOD 2", "All LODs"]
const STRESS_TREES: int = 240
const GOLFER_LOOKS: int = 8
const SCENE_PATH: String = "res://art/mh_nature_gallery.tscn"
const LAUNCHER_PATH: String = "res://ui/mh_launcher.tscn"

var category: String = "trees"
## 0..2 fixed LOD, 3 shows every LOD in separate rows.
var lod_mode: int = 0
var paused: bool = false
var shadows_on: bool = true

## Filled by build_content(), for tests and the stats label.
var tri_total: int = 0
var instance_total: int = 0
var draw_node_total: int = 0
var extent: Vector2 = Vector2(10.0, 10.0)
var content_root: Node3D = null

var _material: StandardMaterial3D = null
var _figures: Array = []
var _sun: DirectionalLight3D = null
var _camera: Camera3D = null
var _yaw: float = -25.0
var _pitch: float = -30.0
var _dist: float = 30.0
var _target: Vector3 = Vector3(0.0, 1.0, 0.0)
var _stats_label: Label = null
var _fps_label: Label = null
var _fps_timer: float = 0.0
var _lod_button: Button = null
var _pause_button: Button = null
var _shadow_button: Button = null
var _category_buttons: Dictionary = {}


func _ready() -> void:
	_build_world()
	_build_ui()
	build_content()
	_frame_camera()


# ---------------------------------------------------------------- public API

func set_category(new_category: String) -> void:
	if not CATEGORIES.has(new_category):
		return
	category = new_category
	build_content()
	_frame_camera()
	_refresh_buttons()


func set_lod_mode(mode: int) -> void:
	lod_mode = clampi(mode, 0, LOD_LABELS.size() - 1)
	build_content()
	_frame_camera()
	_refresh_buttons()


## Rebuilds everything shown for the current category and LOD mode.
func build_content() -> void:
	_ensure_material()
	if content_root != null:
		if content_root.get_parent() == self:
			remove_child(content_root)
		content_root.free()
		content_root = null
	_figures.clear()
	tri_total = 0
	instance_total = 0
	draw_node_total = 0
	content_root = Node3D.new()
	content_root.name = "Content"
	add_child(content_root)
	match category:
		"trees":
			_build_nature_rows(MHNatureMeshes.TREE_KINDS, 8.0)
		"plants":
			_build_nature_rows(["bush", "flower_patch", "reeds", "cattails", "tall_grass"], 3.2)
		"rocks":
			_build_nature_rows(["rock", "rock_cluster"], 3.6)
		"golfers":
			_build_golfers()
		"props":
			_build_props()
		"stress":
			_build_stress()
	_apply_pause()
	_refresh_stats()


# ---------------------------------------------------------------- world and ui

func _ensure_material() -> void:
	if _material == null:
		_material = MHArtMaterials.vertex_color()


func _build_world() -> void:
	_ensure_material()
	var parts: Dictionary = MHSkySetup.apply(self, shadows_on)
	_sun = parts["sun"] as DirectionalLight3D
	var ground: MHMeshBuilder = MHMeshBuilder.new()
	ground.disc(Vector3.ZERO, 160.0, 24, MHPalette.GRASS, true)
	var ground_node: MeshInstance3D = MHArtMaterials.make_instance(ground.to_mesh(), _material, false)
	ground_node.name = "Ground"
	add_child(ground_node)
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.near = 0.2
	_camera.far = 500.0
	add_child(_camera)
	_camera.current = true


func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	layer.add_child(MHTouchBridge.new())
	var flow: HFlowContainer = HFlowContainer.new()
	flow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	flow.offset_left = 12.0
	flow.offset_top = 12.0
	flow.offset_right = -12.0
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	layer.add_child(flow)
	for c: Variant in CATEGORIES:
		var cat: String = str(c)
		var btn: MHTapButton = MHTapButton.make(cat.capitalize(), &"", 120.0, 56.0)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(set_category.bind(cat))
		flow.add_child(btn)
		_category_buttons[cat] = btn
	_lod_button = _add_button(flow, "LOD 0", _on_lod_pressed)
	_pause_button = _add_button(flow, "Pause", _on_pause_pressed)
	_shadow_button = _add_button(flow, "Shadows", _on_shadow_pressed)
	_add_button(flow, "Zoom +", _on_zoom_in)
	_add_button(flow, "Zoom -", _on_zoom_out)
	_add_button(flow, "Back", _on_back_pressed)
	_stats_label = Label.new()
	_stats_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stats_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_stats_label.offset_left = 12.0
	_stats_label.offset_bottom = -12.0
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_stats_label)
	_fps_label = Label.new()
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fps_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fps_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fps_label.offset_right = -12.0
	_fps_label.offset_bottom = -12.0
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_fps_label)
	_refresh_buttons()


func _add_button(parent: Node, text_value: String, handler: Callable) -> MHTapButton:
	var btn: MHTapButton = MHTapButton.make(text_value, &"", 120.0, 56.0)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(handler)
	parent.add_child(btn)
	return btn


func _refresh_buttons() -> void:
	if _lod_button != null:
		_lod_button.text = str(LOD_LABELS[lod_mode])
	if _pause_button != null:
		_pause_button.text = "Play" if paused else "Pause"
	if _shadow_button != null:
		_shadow_button.text = "Shadows on" if shadows_on else "Shadows off"
	for cat: Variant in _category_buttons.keys():
		var btn: Button = _category_buttons[cat] as Button
		btn.disabled = str(cat) == category


func _refresh_stats() -> void:
	if _stats_label == null:
		return
	_stats_label.text = "%s, %s: %d triangles, %d instances, %d nodes" % [category, str(LOD_LABELS[lod_mode]),
		tri_total, instance_total, draw_node_total]


func _on_lod_pressed() -> void:
	set_lod_mode((lod_mode + 1) % LOD_LABELS.size())


func _on_pause_pressed() -> void:
	paused = not paused
	_apply_pause()
	_refresh_buttons()


func _on_shadow_pressed() -> void:
	shadows_on = not shadows_on
	if _sun != null:
		_sun.shadow_enabled = shadows_on
	_refresh_buttons()


func _on_zoom_in() -> void:
	_dist = maxf(4.0, _dist * 0.8)
	_apply_camera()


func _on_zoom_out() -> void:
	_dist = minf(300.0, _dist * 1.25)
	_apply_camera()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(LAUNCHER_PATH)


func _apply_pause() -> void:
	for f: Variant in _figures:
		var fig: MHGolferFigure = f as MHGolferFigure
		if fig != null:
			fig.auto_advance = not paused


# ---------------------------------------------------------------- camera

func _frame_camera() -> void:
	_target = Vector3(0.0, 1.0, 0.0)
	_dist = clampf(maxf(extent.x, extent.y) * 0.85 + 8.0, 10.0, 260.0)
	_pitch = -30.0
	_apply_camera()


func _apply_camera() -> void:
	if _camera == null or not _camera.is_inside_tree():
		return
	var yaw: float = deg_to_rad(_yaw)
	var pitch: float = deg_to_rad(_pitch)
	var offset: Vector3 = Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * _dist
	_camera.position = _target + offset
	_camera.look_at(_target, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		_orbit(sd.relative)
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_orbit(mm.relative)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_on_zoom_in()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_on_zoom_out()


func _orbit(rel: Vector2) -> void:
	_yaw -= rel.x * 0.35
	_pitch = clampf(_pitch - rel.y * 0.25, -85.0, -5.0)
	_apply_camera()


func _process(delta: float) -> void:
	_fps_timer += delta
	if _fps_timer >= 0.5 and _fps_label != null:
		_fps_timer = 0.0
		_fps_label.text = "%d fps" % int(Engine.get_frames_per_second())


# ---------------------------------------------------------------- content helpers

func _lods_to_show(lod_count: int) -> Array:
	var out: Array = []
	if lod_mode >= 3:
		for i in range(lod_count):
			out.append(i)
	else:
		out.append(mini(lod_mode, lod_count - 1))
	return out


func _add_mesh(mesh: ArrayMesh, pos: Vector3) -> void:
	var mi: MeshInstance3D = MHArtMaterials.make_instance(mesh, _material, true)
	mi.position = pos
	content_root.add_child(mi)
	tri_total += MHMeshBuilder.mesh_tri_count(mesh)
	instance_total += 1
	draw_node_total += 1


func _add_label(text_value: String, pos: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = text_value
	label.font_size = 40
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 10
	label.position = pos + Vector3(0.0, 0.15, 0.0)
	content_root.add_child(label)


func _set_extent(width: float, depth: float) -> void:
	extent = Vector2(width, depth)


func _build_nature_rows(kinds: Array, spacing: float) -> void:
	var lods: Array = _lods_to_show(MHNatureMeshes.LOD_COUNT)
	var rows: int = kinds.size() * lods.size()
	var cols: int = MHNatureMeshes.VARIANTS
	var row: int = 0
	for k: Variant in kinds:
		var kind: String = str(k)
		for l: Variant in lods:
			var lod: int = int(l)
			var z: float = (float(row) - float(rows - 1) * 0.5) * spacing
			var row_tris: int = 0
			for v in range(cols):
				var mesh: ArrayMesh = MHNatureMeshes.build(kind, lod, v)
				row_tris = maxi(row_tris, MHMeshBuilder.mesh_tri_count(mesh))
				_add_mesh(mesh, Vector3((float(v) - float(cols - 1) * 0.5) * spacing, 0.0, z))
			_add_label("%s LOD%d  max %d tris (budget %d)" % [kind, lod, row_tris, MHNatureMeshes.budget(kind, lod)],
				Vector3(-(float(cols) * 0.5 + 1.2) * spacing, 0.0, z))
			row += 1
	_set_extent(float(cols + 3) * spacing, float(rows) * spacing)


func _build_props() -> void:
	var spacing: float = 4.0
	var lods: Array = _lods_to_show(MHPropMeshes.LOD_COUNT)
	var rows: int = MHPropMeshes.KINDS.size() * lods.size()
	var cols: int = MHPropMeshes.VARIANTS
	var row: int = 0
	for k: Variant in MHPropMeshes.KINDS:
		var kind: String = str(k)
		for l: Variant in lods:
			var lod: int = int(l)
			var z: float = (float(row) - float(rows - 1) * 0.5) * spacing
			var row_tris: int = 0
			for v in range(cols):
				var mesh: ArrayMesh = MHPropMeshes.build(kind, lod, v)
				row_tris = maxi(row_tris, MHMeshBuilder.mesh_tri_count(mesh))
				var x: float = (float(v) - float(cols - 1) * 0.5) * spacing
				if kind == MHPropMeshes.KIND_FENCE:
					x -= MHPropMeshes.FENCE_LENGTH * 0.5
				_add_mesh(mesh, Vector3(x, 0.0, z))
			_add_label("%s LOD%d  max %d tris (budget %d)" % [kind, lod, row_tris, MHPropMeshes.budget(kind, lod)],
				Vector3(-(float(cols) * 0.5 + 1.2) * spacing, 0.0, z))
			row += 1
	_set_extent(float(cols + 3) * spacing, float(rows) * spacing)


func _build_golfers() -> void:
	var spacing: float = 2.6
	var lods: Array = _lods_to_show(MHGolferMeshes.LOD_COUNT)
	var fig_lod: int = int(lods[0])
	var clips: Array = MHGolferPoses.CLIPS
	# Row 0: animated joint-tree figures (one MeshInstance3D per joint).
	for i in range(GOLFER_LOOKS):
		var look: MHGolferLook = MHGolferLook.from_seed(i + 1)
		var fig: MHGolferFigure = MHGolferFigure.new()
		fig.setup(look, fig_lod, _material)
		var clip: String = str(clips[i % clips.size()])
		var x: float = (float(i) - float(GOLFER_LOOKS - 1) * 0.5) * spacing
		fig.position = Vector3(x, 0.0, -4.0)
		content_root.add_child(fig)
		fig.play(clip)
		fig.clip_finished.connect(_replay.bind(fig))
		_figures.append(fig)
		draw_node_total += _mesh_node_count(fig)
		instance_total += 1
		var tris: int = MHGolferMeshes.total_tri_count(look, fig_lod)
		tri_total += tris
		if clip == MHGolferPoses.CLIP_SWING:
			_add_mesh(MHPropMeshes.build("golf_ball", 0, 0), fig.position + Vector3(0.02, 0.0, MHGolferPoses.BALL_SWING.z))
		elif clip == MHGolferPoses.CLIP_PUTT:
			_add_mesh(MHPropMeshes.build("golf_ball", 0, 0), fig.position + Vector3(0.02, 0.0, MHGolferPoses.BALL_PUTT.z))
	_add_label("animated, %s, one node per joint (idle, walk, swing, putt)" % str(LOD_LABELS[fig_lod]),
		Vector3(0.0, 0.0, -6.0))
	# Further rows: the same looks baked into ONE mesh each at the swing address pose.
	var pose: Dictionary = MHGolferPoses.sample(MHGolferPoses.CLIP_SWING, 0.0)
	var row: int = 0
	for l: Variant in lods:
		var lod: int = int(l)
		var z: float = 3.0 + float(row) * 4.0
		var row_tris: int = 0
		for i in range(GOLFER_LOOKS):
			var look2: MHGolferLook = MHGolferLook.from_seed(i + 1)
			var mesh: ArrayMesh = MHGolferMeshes.build_posed(look2, lod, pose)
			row_tris = maxi(row_tris, MHMeshBuilder.mesh_tri_count(mesh))
			_add_mesh(mesh, Vector3((float(i) - float(GOLFER_LOOKS - 1) * 0.5) * spacing, 0.0, z))
		_add_label("baked, one mesh each, LOD%d  max %d tris (budget %d)" % [lod, row_tris, MHGolferMeshes.budget(lod)],
			Vector3(0.0, 0.0, z + 1.8))
		row += 1
	_set_extent(float(GOLFER_LOOKS) * spacing, 14.0 + float(row) * 4.0)


func _mesh_node_count(root: Node) -> int:
	return root.find_children("*", "MeshInstance3D", true, false).size()


func _replay(clip_name: String, fig: MHGolferFigure) -> void:
	if is_instance_valid(fig):
		fig.play(clip_name)


## 240 trees in MultiMeshes, LOD chosen by distance from the centre (or fixed by the LOD button).
## Deterministic layout (MHArtRng), so two runs show the same forest.
func _build_stress() -> void:
	var rng: MHArtRng = MHArtRng.new(4242)
	var buckets: Dictionary = {}
	var cols: int = 16
	@warning_ignore("integer_division")
	var rows: int = STRESS_TREES / cols
	var spacing: float = 11.0
	for i in range(STRESS_TREES):
		var gx: int = i % cols
		@warning_ignore("integer_division")
		var gz: int = i / cols
		var px: float = (float(gx) - float(cols - 1) * 0.5) * spacing + rng.range_f(-3.0, 3.0)
		var pz: float = (float(gz) - float(rows - 1) * 0.5) * spacing + rng.range_f(-3.0, 3.0)
		var kind: String = str(MHNatureMeshes.TREE_KINDS[(gx * 3 + gz) % MHNatureMeshes.TREE_KINDS.size()])
		var variant: int = rng.range_int(MHNatureMeshes.VARIANTS)
		var dist: float = Vector2(px, pz).length()
		var lod: int = 0
		if lod_mode >= 3:
			if dist > 60.0:
				lod = 2
			elif dist > 30.0:
				lod = 1
		else:
			lod = mini(lod_mode, MHNatureMeshes.LOD_COUNT - 1)
		var s: float = rng.range_f(0.85, 1.2)
		var rot_basis: Basis = Basis(Vector3.UP, rng.range_f(0.0, TAU)).scaled(Vector3(s, s, s))
		var key: String = "%s|%d|%d" % [kind, lod, variant]
		if not buckets.has(key):
			buckets[key] = []
		(buckets[key] as Array).append(Transform3D(rot_basis, Vector3(px, 0.0, pz)))
	var keys: Array = buckets.keys()
	keys.sort()
	for k: Variant in keys:
		var parts: PackedStringArray = str(k).split("|")
		var mesh: ArrayMesh = MHNatureMeshes.build(parts[0], int(parts[1]), int(parts[2]))
		var transforms: Array = buckets[k] as Array
		var node: MultiMeshInstance3D = MHArtMaterials.make_multimesh(mesh, _material, transforms)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		content_root.add_child(node)
		tri_total += MHMeshBuilder.mesh_tri_count(mesh) * transforms.size()
		instance_total += transforms.size()
		draw_node_total += 1
	_set_extent(float(cols) * spacing, float(rows) * spacing)
