class_name MHOneHolePanel
extends VBoxContainer
## Course-design and practice overlay for the canonical player-built hole.
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
var _close: MHTapButton
var _title: Label
var _undo_button: MHTapButton
var _redo_button: MHTapButton
var _terrain_mode: StringName = &"raise"
var _marker_mode: StringName = &"tee"
var craft_radius: int = 1
var craft_step_mm: int = 250
var _navigation: HFlowContainer
var _details_button: MHTapButton
var _details_open: bool = false
var _brush_size_button: MHTapButton
var _strength_button: MHTapButton
var _surface_group_button: MHTapButton
var _surface_group: int = 0
var _surface_button_ids: Dictionary = {}
var _practice_content: VBoxContainer
var _pin_slot: int = 0
var _pin_slot_button: MHTapButton
var _remove_pin_button: MHTapButton
var _placement_tools: HBoxContainer
var _confirm_marker_button: MHTapButton
var _pending_marker: Vector2i = Vector2i(-1, -1)
var _marker_preview: MeshInstance3D
var _brush_tools: HBoxContainer
var _brush_hint: Label
var _brush_tile: Vector2i = Vector2i(-1, -1)
var _brush_preview: MeshInstance3D
var craft_surface: int = MHCraftHole.Surface.FAIRWAY
var craft_mode: StringName = &"surface"
var _craft_stroke_open: bool = false
var _craft_last_tile: Vector2i = Vector2i(-1, -1)
var _craft_level_height: int = 0
var _craft_tool_buttons: Dictionary = {}
var _craft_category_buttons: Dictionary = {}
var _craft_category: StringName = &"surfaces"
var _surface_icons: Dictionary = {}
var _category_row: HBoxContainer
var _history_row: HBoxContainer
var _craft_tools: HBoxContainer
var _terrain_tools: HBoxContainer
var _marker_tools: HBoxContainer
var _practice_tools: HFlowContainer
var _finalize_button: MHTapButton
var _validation_hint: Label
var _craft_preview_dirty: bool = false
## Header only (body hidden). Layout is recomputed by the scene on `layout_changed`.
var collapsed: bool = false
signal layout_changed()
var _aim: MeshInstance3D
var visual_quality: MHVisualQuality.Tier = MHVisualQuality.automatic()
var _visual_settings: Dictionary = {}
var mowing_design: MHMowingDesign = MHMowingDesign.new()
const ORIGIN: Array = [480, 340]

func setup(scene: MHLiveConstruction) -> void:
	live = scene
	_visual_settings = MHVisualQuality.settings(visual_quality)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	var head: HBoxContainer = MHUIKit.hbox(8)
	add_child(head)
	_title = MHUIKit.label("HOLE 1", &"", false)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	_details_button = _button(head, "Details", _toggle_details)
	_finalize_button = MHUIKit.button(live.shell.ctx, "Build hole", &"GreenButton", 122)
	_finalize_button.pressed.connect(_finalize)
	head.add_child(_finalize_button)
	_toggle = MHUIKit.button(live.shell.ctx, "−", &"ChipButton")
	_toggle.tooltip_text = "Hide tools"
	_toggle.pressed.connect(toggle_collapsed)
	head.add_child(_toggle)
	_close = MHUIKit.button(live.shell.ctx, "×", &"ChipButton")
	_close.tooltip_text = "Close course design"
	_close.pressed.connect(close_preview)
	head.add_child(_close)
	_validation_hint = MHUIKit.label("Design a playable hole to build it.", &"SmallLabel")
	add_child(_validation_hint)
	_navigation = MHUIKit.flow(6)
	add_child(_navigation)
	_category_row = MHUIKit.hbox(6)
	_navigation.add_child(_category_row)
	_category_button(_category_row, "Surfaces", &"surfaces")
	_category_button(_category_row, "Terrain", &"terrain")
	_category_button(_category_row, "Hole", &"markers")
	_history_row = MHUIKit.hbox(6)
	_navigation.add_child(_history_row)
	_undo_button = _button(_history_row, "Undo", _craft_undo)
	_redo_button = _button(_history_row, "Redo", _craft_redo)
	_undo_button.custom_minimum_size.x = maxf(80, live.shell.ctx.touch_min())
	_redo_button.custom_minimum_size.x = maxf(80, live.shell.ctx.touch_min())
	_undo_button.tooltip_text = "Undo last edit (Ctrl+Z)"
	_redo_button.tooltip_text = "Redo last edit (Ctrl+Y / Ctrl+Shift+Z)"
	_brush_tools = MHUIKit.hbox(6)
	_navigation.add_child(_brush_tools)
	_brush_size_button = _button(_brush_tools, "", _cycle_brush_radius)
	_strength_button = _button(_brush_tools, "", _cycle_strength)
	_surface_group_button = _button(_navigation, "", _cycle_surface_group)
	_placement_tools = MHUIKit.hbox(6)
	_navigation.add_child(_placement_tools)
	_confirm_marker_button = _button(_placement_tools, "Confirm", _confirm_marker)
	_confirm_marker_button.theme_type_variation = &"GreenButton"
	_button(_placement_tools, "Cancel", _cancel_marker_preview)
	_scroll = MHScrollBox.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var content: HBoxContainer = MHUIKit.hbox(8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(content)
	_craft_tools = MHUIKit.hbox(8)
	content.add_child(_craft_tools)
	for surface_id: int in range(MHCraftHole.SURFACE_COUNT):
		_surface_button(_craft_tools, _surface_name(surface_id), surface_id)
	_terrain_tools = MHUIKit.hbox(8)
	content.add_child(_terrain_tools)
	_mode_button(_terrain_tools, "Raise", &"raise")
	_mode_button(_terrain_tools, "Lower", &"lower")
	_mode_button(_terrain_tools, "Smooth", &"smooth")
	_mode_button(_terrain_tools, "Level", &"level")
	_marker_tools = MHUIKit.hbox(8)
	content.add_child(_marker_tools)
	_mode_button(_marker_tools, "Place tee", &"tee")
	_mode_button(_marker_tools, "Place pin", &"pin")
	_pin_slot_button = _button(_marker_tools, "Pin 1", _cycle_pin_slot)
	_pin_slot_button.tooltip_text = "Choose an existing pin to move, or the next empty slot. Pin 1 is used for current practice."
	_remove_pin_button = _button(_marker_tools, "Remove pin", _remove_pin)
	_button(_marker_tools, "Repair markers", _repair_hole_markers)
	_practice_content = MHUIKit.vbox(6)
	_practice_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_practice_content)
	_info = MHUIKit.label("")
	_practice_content.add_child(_info)
	_practice_tools = MHUIKit.flow(6)
	_practice_content.add_child(_practice_tools)
	_button(_practice_tools, "Aim at cup", _aim_cup)
	_button(_practice_tools, "Back to golfer", _back_to_golfer)
	_button(_practice_tools, "Course overview", _overview)
	_button(_practice_tools, "Play shot", _shoot)
	_button(_practice_tools, "New practice round", _restart)
	_feedback = MHUIKit.label("", &"SmallLabel", false)
	_feedback.clip_text = true
	_feedback.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_feedback)
	_brush_hint = MHUIKit.label("", &"SmallLabel", false)
	_brush_hint.clip_text = true
	_brush_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_brush_hint)
	_world = Node3D.new()
	live.add_child(_world)
	_world.hide()
	var layouts: Array = live.session.hole_definitions()
	if not layouts.is_empty():
		_sync_legacy_controls(layouts[0] as Dictionary)
	_sync_mode_controls()
	_describe()
	hide()


func desired_dock_height() -> float:
	# Scroll content does not impose its entire catalogue height on the dock.
	# Use rendered minimums for the header/toolbelt, plus one accessible card row.
	var wanted: float = 0.0
	var visible_rows: int = 0
	for child: Node in get_children():
		var control: Control = child as Control
		if control == null or not control.visible:
			continue
		visible_rows += 1
		if control == _scroll:
			wanted += maxf(86.0, live.shell.ctx.touch_min() + 20.0)
		else:
			wanted += control.get_combined_minimum_size().y
	return wanted + maxf(0, visible_rows - 1) * 6.0 + MHLiveLayout.PANEL_PAD_V * 2.0


func _toggle_details() -> void:
	_details_open = true if collapsed else not _details_open
	if collapsed:
		set_collapsed(false)
	_sync_mode_controls()
	layout_changed.emit()


func _cycle_brush_radius() -> void:
	var options: Array = [0, 1, 3]
	_select_brush_radius(int(options[(options.find(craft_radius) + 1) % options.size()]))


func _cycle_strength() -> void:
	var options: Array = [250, 500, 1000]
	_select_strength(int(options[(options.find(craft_step_mm) + 1) % options.size()]))


func _select_strength(step_mm: int) -> void:
	if step_mm not in [250, 500, 1000]:
		return
	_cancel_tool_gesture()
	craft_step_mm = step_mm
	_describe()


func _cycle_surface_group() -> void:
	_cancel_tool_gesture()
	_surface_group = (_surface_group + 1) % 3
	_scroll.scroll_horizontal = 0
	_refresh_surface_group()


func _surface_group_for(surface_id: int) -> int:
	if surface_id in [MHCraftHole.Surface.BUNKER, MHCraftHole.Surface.WASTE, MHCraftHole.Surface.WATER, MHCraftHole.Surface.OUT_OF_BOUNDS]:
		return 1
	if surface_id in [MHCraftHole.Surface.PATH, MHCraftHole.Surface.DIRT]:
		return 2
	return 0


func _refresh_surface_group() -> void:
	for key: Variant in _surface_button_ids.keys():
		var button: MHTapButton = _surface_button_ids[key] as MHTapButton
		button.visible = _surface_group_for(int(key)) == _surface_group
	if _surface_group_button != null:
		_surface_group_button.text = ["Turf  ›", "Hazards  ›", "Paths & dirt  ›"][_surface_group]
		_surface_group_button.tooltip_text = "Browse Turf, Hazards, or Paths & dirt. Swipe the material tray for more."


func _sync_mode_controls() -> void:
	if _navigation != null:
		_navigation.visible = _preview_draft and not collapsed
	if _validation_hint != null:
		_validation_hint.visible = not collapsed and _details_open
	if _details_button != null:
		_details_button.theme_type_variation = &"SelectedButton" if _details_open else &"ChipButton"
		if not _preview_draft:
			_details_button.text = "Details"
	if _practice_content != null:
		_practice_content.visible = not _preview_draft
	if _scroll != null:
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if _preview_draft else ScrollContainer.SCROLL_MODE_DISABLED
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _preview_draft else ScrollContainer.SCROLL_MODE_AUTO
	if _feedback != null:
		_feedback.visible = not collapsed and (not _preview_draft or _craft_category == &"markers")
	if _surface_group_button != null:
		_surface_group_button.visible = _craft_category == &"surfaces"
	if _strength_button != null:
		_strength_button.visible = craft_mode in [&"raise", &"lower"]
	if _category_row != null:
		_category_row.visible = _preview_draft and not collapsed
	if _history_row != null:
		_history_row.visible = _preview_draft and not collapsed
	if _craft_tools != null:
		_craft_tools.visible = _preview_draft and _craft_category == &"surfaces"
	if _terrain_tools != null:
		_terrain_tools.visible = _preview_draft and _craft_category == &"terrain"
	if _marker_tools != null:
		_marker_tools.visible = _preview_draft and _craft_category == &"markers"
	if _practice_tools != null:
		_practice_tools.visible = not _preview_draft
	if _finalize_button != null:
		_finalize_button.visible = _preview_draft
	if _brush_tools != null:
		_brush_tools.visible = _preview_draft and _craft_category != &"markers"
	if _brush_hint != null:
		_brush_hint.visible = _preview_draft and not collapsed and _craft_category != &"markers"
	_refresh_surface_group()
	_refresh_marker_controls()
	for key: Variant in _craft_category_buttons.keys():
		var tab: MHTapButton = _craft_category_buttons[key] as MHTapButton
		if tab != null:
			tab.theme_type_variation = &"SelectedButton" if StringName(key) == _craft_category else &"ChipButton"


func _process(_delta: float) -> void:
	if _craft_preview_dirty and _preview_draft and is_visible_in_tree():
		_craft_preview_dirty = false
		_draw()

func set_collapsed(value: bool) -> void:
	if value:
		_cancel_tool_gesture()
	collapsed = value
	if _scroll != null:
		_scroll.visible = not collapsed
	if _toggle != null:
		_toggle.text = "+" if collapsed else "−"
		_toggle.tooltip_text = "Show tools" if collapsed else "Hide tools"
	if _validation_hint != null:
		_validation_hint.visible = not collapsed
	_sync_mode_controls()
	layout_changed.emit()

func toggle_collapsed() -> void:
	set_collapsed(not collapsed)

func close_preview() -> void:
	_cancel_tool_gesture()
	hide()
	if _world != null:
		_world.hide()
	if live != null and live.chunks != null:
		live.chunks.show()


func open() -> void:
	set_collapsed(false)
	_sync_mode_controls()
	live.router.cancel_world_input()
	if live.aim_input != null:
		live.aim_input.taps.clear()
	live.shell.show_root(MHScreenIds.HUD)
	# The exact-hole editor is an overlay on the same persisted terrain used by the
	# normal editor. Keep the world chunks visible so landscaping outside the rated
	# hole footprint never appears to vanish when entering Build/play.
	live.chunks.show()
	show()
	_world.show()
	_follow_camera()
	_draw()
	_describe()

func _button(parent: Control, title: String, action: Callable) -> MHTapButton:
	var b: MHTapButton = MHUIKit.button(live.shell.ctx, title, &"ChipButton", 110)
	parent.add_child(b)
	b.pressed.connect(action)
	return b


func _category_button(parent: Control, title: String, category: StringName) -> void:
	var b: MHTapButton = _button(parent, title, _select_category.bind(category))
	b.add_theme_font_size_override("font_size", live.shell.ctx.scaled(MHTheme.FONT_SMALL))
	b.icon = _surface_thumbnail(MHCraftHole.Surface.FAIRWAY) if category == &"surfaces" else _mode_thumbnail(&"raise" if category == &"terrain" else &"pin")
	b.add_theme_constant_override("icon_max_width", 24)
	b.custom_minimum_size = Vector2(130, maxf(54, live.shell.ctx.touch_min()))
	_craft_category_buttons[category] = b


func _select_category(category: StringName) -> void:
	if category not in [&"surfaces", &"terrain", &"markers"]:
		return
	_cancel_tool_gesture()
	_craft_category = category
	if category == &"surfaces":
		craft_mode = &"surface"
	elif category == &"terrain":
		craft_mode = _terrain_mode
	else:
		craft_mode = _marker_mode
	if _scroll != null:
		_scroll.scroll_horizontal = 0
		_scroll.scroll_vertical = 0
	_sync_mode_controls()
	_refresh_tool_button_styles()
	_describe()
	if _preview_draft and _world != null:
		_draw()


func _surface_button(parent: Control, title: String, surface_id: int) -> void:
	var key: StringName = StringName("surface_" + str(surface_id))
	var b: MHTapButton = _button(parent, title, _select_surface.bind(surface_id))
	# A pictorial material palette: 48px terrain samples with subtle deterministic
	# patterning. Swap these generated previews for approved course art later without
	# changing the palette, selection, or terrain/saving code.
	b.icon = _surface_thumbnail(surface_id)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(160, maxf(78, live.shell.ctx.touch_min()))
	_craft_tool_buttons[key] = b
	_surface_button_ids[surface_id] = b
	_refresh_tool_button_styles()


func _surface_thumbnail(surface_id: int) -> Texture2D:
	if _surface_icons.has(surface_id):
		return _surface_icons[surface_id] as Texture2D
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var base: Color = _surface_color(surface_id)
	for py: int in range(48):
		for px: int in range(48):
			var grain: float = float((px * 13 + py * 7 + (px * py) % 17) % 13) / 12.0
			var bands: float = sin(float(px + py * 2) * 0.18) * 0.06
			var brightness: float = (grain - 0.5) * 0.14 + bands
			var pixel: Color = base.lightened(maxf(0.0, brightness)) if brightness >= 0.0 else base.darkened(-brightness)
			img.set_pixel(px, py, pixel)
	var texture: Texture2D = ImageTexture.create_from_image(img)
	_surface_icons[surface_id] = texture
	return texture


func _mode_button(parent: Control, title: String, mode: StringName) -> void:
	var b: MHTapButton = _button(parent, title, _select_mode.bind(mode))
	b.icon = _mode_thumbnail(mode)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(160, maxf(78, live.shell.ctx.touch_min()))
	_craft_tool_buttons[mode] = b
	_refresh_tool_button_styles()


func _mode_thumbnail(mode: StringName) -> Texture2D:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var background: Color = Color(0.15, 0.36, 0.19)
	var accent: Color = Color(0.62, 0.85, 0.43)
	for py: int in range(48):
		for px: int in range(48):
			var dx: float = float(px - 24)
			var dy: float = float(py - 24)
			var distance: float = sqrt(dx * dx + dy * dy)
			var color: Color = background
			match mode:
				&"raise":
					if float(py) > 30.0 - 0.57 * absf(dx):
						color = accent
				&"lower":
					if distance < 18.0:
						color = Color(0.06, 0.18, 0.11) if distance < 12.0 else accent
				&"smooth":
					if absi((px + roundi(4.0 * sin(float(py) * 0.3))) % 14 - 7) <= 2:
						color = accent
				&"level":
					if py >= 19 and py <= 28:
						color = accent
				&"tee":
					if distance <= 8.0:
						color = Color.WHITE
				&"pin":
					if absf(dx) <= 1.0 or (py >= 10 and py <= 22 and px > 24 and px < 38 - (py - 10) / 2):
						color = Color(0.95, 0.85, 0.50)
			img.set_pixel(px, py, color)
	return ImageTexture.create_from_image(img)


func _select_surface(surface_id: int) -> void:
	if surface_id < 0 or surface_id >= MHCraftHole.SURFACE_COUNT:
		return
	_cancel_tool_gesture()
	craft_surface = surface_id
	_surface_group = _surface_group_for(surface_id)
	_refresh_surface_group()
	craft_mode = &"surface"
	_refresh_tool_button_styles()
	_describe()
	if _preview_draft and _world != null:
		_draw()


func _select_mode(mode: StringName) -> void:
	if mode not in [&"raise", &"lower", &"smooth", &"level", &"tee", &"pin"]:
		return
	_cancel_tool_gesture()
	craft_mode = mode
	_sync_mode_controls()
	if mode in [&"raise", &"lower", &"smooth", &"level"]:
		_terrain_mode = mode
	elif mode in [&"tee", &"pin"]:
		_marker_mode = mode
	_refresh_tool_button_styles()
	_describe()
	if _preview_draft and _world != null:
		_draw()


func _cancel_tool_gesture() -> void:
	# A second finger can tap a tool while the first still owns a stroke.
	# Roll that gesture back before changing its meaning.
	if live != null and live.aim_input != null:
		live.aim_input.cancel_all()
	if _craft_stroke_open:
		craft_stroke_cancel()
	_cancel_marker_preview()
	clear_brush_preview()


func _select_brush_radius(radius: int) -> void:
	if radius not in [0, 1, 3]:
		return
	_cancel_tool_gesture()
	craft_radius = radius
	_describe()


func clear_brush_preview() -> void:
	_brush_tile = Vector2i(-1, -1)
	if _brush_preview != null and is_instance_valid(_brush_preview):
		_brush_preview.hide()
	_update_brush_hint()


func preview_brush_from_screen(pos: Vector2) -> void:
	if not _preview_draft or not is_visible_in_tree() or blocks_world_tap(pos) or craft_mode in [&"tee", &"pin"]:
		clear_brush_preview()
		return
	var tile: Vector2i = _craft_tile_from_screen(pos)
	if tile == _brush_tile:
		return
	_brush_tile = tile
	_refresh_brush_preview()


func _refresh_brush_preview() -> void:
	if _brush_tile.x < 0 or live == null or live.craft_hole == null or not _preview_draft:
		if _brush_preview != null and is_instance_valid(_brush_preview):
			_brush_preview.hide()
		return
	var hole: MHCraftHole = live.craft_hole
	if not hole.in_bounds(_brush_tile.x, _brush_tile.y):
		return
	var layout: Dictionary = _layout()
	var relief: Dictionary = MHCraftConvert.relief_for(hole)
	if relief.is_empty():
		layout.erase("relief")
	else:
		layout["relief"] = relief
	var relief_hole: MHRHole = MHRHole.from_def(layout)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Match the canonical disc's integer tile mask exactly. One batched mesh,
	# no per-tile nodes, and no grid added when painting a surface.
	for dr: int in range(-craft_radius, craft_radius + 1):
		for dc: int in range(-craft_radius, craft_radius + 1):
			if dc * dc + dr * dr > craft_radius * craft_radius:
				continue
			var c: int = _brush_tile.x + dc
			var r: int = _brush_tile.y + dr
			if not hole.in_bounds(c, r):
				continue
			var x0: int = hole.tile_x0_yd(c) * 100
			var y0: int = hole.tile_y0_yd(r) * 100
			var step: int = MHCraftHole.TILE_YD * 100
			for point: Vector2i in [Vector2i(x0, y0), Vector2i(x0 + step, y0), Vector2i(x0 + step, y0 + step),
					Vector2i(x0, y0), Vector2i(x0 + step, y0 + step), Vector2i(x0, y0 + step)]:
				st.add_vertex(_position(point.x, point.y, float(relief_hole.z_at(point.x, point.y)) / 1000.0 + 0.10))
	if _brush_preview == null or not is_instance_valid(_brush_preview):
		_brush_preview = MeshInstance3D.new()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.88, 0.35, 0.28)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_brush_preview.material_override = material
		_brush_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(_brush_preview)
	_brush_preview.mesh = st.commit()
	_brush_preview.show()
	_update_brush_hint()


func _update_brush_hint() -> void:
	if _brush_hint == null:
		return
	_brush_hint.text = "%d yd brush%s" % [(2 * craft_radius + 1) * MHCraftHole.TILE_YD,
		" • Level: %.2f m" % (float(_craft_level_height) / 1000.0) if craft_mode == &"level" and _craft_stroke_open else (" • Level samples the starting height" if craft_mode == &"level" else "")]
	if live != null and live.craft_hole != null and live.craft_hole.in_bounds(_brush_tile.x, _brush_tile.y):
		_brush_hint.text += " • Ground %.2f m" % (float(live.craft_hole.get_height_mm(_brush_tile.x, _brush_tile.y)) / 1000.0)


func _active_tool_key() -> StringName:
	return StringName("surface_" + str(craft_surface)) if craft_mode == &"surface" else craft_mode


func _refresh_tool_button_styles() -> void:
	var active: StringName = _active_tool_key()
	for key: Variant in _craft_tool_buttons.keys():
		var b: MHTapButton = _craft_tool_buttons[key] as MHTapButton
		if b != null:
			b.theme_type_variation = &"SelectedButton" if StringName(key) == active else &"ChipButton"

func set_canonical_draft(layout: Dictionary) -> bool:
	var validation: Dictionary = MHRatingEngine.validate_input({"schema": 1, "engine": MHRatingEngine.RATING_VERSION, "hole": layout})
	if not bool(validation.get("ok", false)) or int(layout.get("slot_id", -1)) != 0:
		return false
	canonical_draft = layout.duplicate(true)
	_preview_draft = true
	_sync_mode_controls()
	if _world != null:
		_draw()
		_describe()
	return true

func enter_craft_draft() -> void:
	# Editing must remain available even if the player paints water over the pin
	# or removes the last green. A temporarily invalid draft is not a finalized
	# practice hole; never fall back to practice-only UI in this state.
	_preview_draft = true
	canonical_draft.clear()
	if live != null and live.craft_hole != null:
		var draft: Dictionary = live.canonical_craft_draft()
		if not draft.is_empty():
			canonical_draft = draft.duplicate(true)
	_sync_mode_controls()
	_describe()


func clear_canonical_draft() -> void:
	canonical_draft.clear()

func _layout() -> Dictionary:
	if not canonical_draft.is_empty():
		return canonical_draft.duplicate(true)
	var features: Array = [{"t": "fairway", "rect": [-half_width_yd, 0, half_width_yd, length_yd]}]
	if water:
		features.append({"t": "water", "rect": [10, 20, 14, 30]})
	return {"slot_id": 0, "tee": [0, 0], "green": [0, length_yd, 5], "features": features}

## Direct committed edit used by tests and the marker confirmation action.
## Pointer marker input stages a preview first; it never calls this immediately.
func craft_at_tile(c: int, r: int) -> bool:
	if not _preview_draft or live == null or live.craft_hole == null or not live.craft_hole.in_bounds(c, r):
		return false
	var h: MHCraftHole = live.craft_hole
	if h.is_stroke_open():
		return false
	if not h.begin_stroke():
		return false
	var accepted: bool = true
	if craft_mode == &"tee":
		accepted = h.move_tee(c, r)
	elif craft_mode == &"pin":
		accepted = h.set_pin(_pin_slot, c, r)
	else:
		if craft_mode == &"level":
			_craft_level_height = h.get_height_mm(c, r)
		accepted = _apply_craft_stroke_tile(Vector2i(c, r))
	if not accepted:
		h.cancel_stroke()
		return false
	if h.commit_stroke():
		live.sync_craft_tiles_to_world(h.last_changed_tiles())
		live._request_save() # Marker-only changes have no dirty terrain cells.
	_refresh_canonical_craft()
	return true


func _cycle_pin_slot() -> void:
	_cancel_tool_gesture()
	var slots: int = mini(MHCraftHole.MAX_PINS, live.craft_hole.pins.size() + 1)
	_pin_slot = (_pin_slot + 1) % slots
	_select_mode(&"pin")


func _refresh_marker_controls() -> void:
	if _placement_tools == null or live == null or live.craft_hole == null:
		return
	var count: int = live.craft_hole.pins.size()
	_pin_slot = clampi(_pin_slot, 0, mini(count, MHCraftHole.MAX_PINS - 1))
	_pin_slot_button.text = ("Pin %d  ›" if _pin_slot < count else "Add pin %d  ›") % (_pin_slot + 1)
	_remove_pin_button.disabled = craft_mode != &"pin" or _pin_slot >= count
	_placement_tools.visible = _preview_draft and _pending_marker.x >= 0
	_confirm_marker_button.disabled = not _marker_problem(_pending_marker).is_empty()


func _marker_problem(tile: Vector2i) -> String:
	var h: MHCraftHole = live.craft_hole
	if not h.in_bounds(tile.x, tile.y):
		return "Choose a spot on the course."
	var surface: int = h.get_surface(tile.x, tile.y)
	if craft_mode == &"tee":
		return "Move the tee out of water or out-of-bounds land." if surface in [MHCraftHole.Surface.WATER, MHCraftHole.Surface.OUT_OF_BOUNDS] else ""
	if surface != MHCraftHole.Surface.GREEN:
		return "Place the pin on a putting green."
	for i: int in range(h.pins.size()):
		if i != _pin_slot and h.pins[i] == tile:
			return "Another pin already uses this spot."
	return ""


func stage_marker_at_tile(tile: Vector2i) -> bool:
	if not _preview_draft or craft_mode not in [&"tee", &"pin"] or not live.craft_hole.in_bounds(tile.x, tile.y):
		return false
	_pending_marker = tile
	_refresh_marker_controls()
	_refresh_marker_preview()
	var issue: String = _marker_problem(tile)
	_feedback.text = issue if not issue.is_empty() else "Preview only • Confirm to place, or tap another spot."
	var h: MHCraftHole = live.craft_hole
	var other: Vector2i = Vector2i(-1, -1)
	if craft_mode == &"tee" and not h.pins.is_empty():
		other = h.pins[mini(_pin_slot, h.pins.size() - 1)] as Vector2i
	elif craft_mode == &"pin" and not h.tees.is_empty():
		other = h.tees[0] as Vector2i
	if other.x >= 0:
		_feedback.text += " • %d yd" % roundi(Vector2(tile - other).length() * MHCraftHole.TILE_YD)
	_feedback.tooltip_text = _feedback.text
	layout_changed.emit()
	return true


func _refresh_marker_preview() -> void:
	if _pending_marker.x < 0 or _world == null:
		return
	var valid: bool = _marker_problem(_pending_marker).is_empty()
	var colour: Color = Color(1.0, 0.82, 0.25, 0.70) if valid else Color(0.95, 0.25, 0.20, 0.70)
	if _marker_preview == null or not is_instance_valid(_marker_preview):
		var marker: CylinderMesh = CylinderMesh.new()
		marker.top_radius = 0.8
		marker.bottom_radius = 0.8
		marker.height = 0.14
		_marker_preview = _mesh(marker, Vector3.ZERO, colour)
		var material: StandardMaterial3D = _marker_preview.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_marker_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = _marker_preview.material_override as StandardMaterial3D
	mat.albedo_color = colour
	var centre: Vector2i = live.craft_hole.tile_centre_yd(_pending_marker.x, _pending_marker.y)
	_marker_preview.position = _position_on_ground(centre.x * 100, centre.y * 100, 0.24)
	_marker_preview.show()


func _confirm_marker() -> void:
	if _pending_marker.x < 0 or not _marker_problem(_pending_marker).is_empty():
		return
	var tile: Vector2i = _pending_marker
	_cancel_marker_preview()
	craft_at_tile(tile.x, tile.y)


func _cancel_marker_preview() -> void:
	var had_preview: bool = _pending_marker.x >= 0
	_pending_marker = Vector2i(-1, -1)
	if _marker_preview != null and is_instance_valid(_marker_preview):
		_marker_preview.hide()
	_refresh_marker_controls()
	if _feedback != null and _preview_draft and _craft_category == &"markers":
		_feedback.text = "Tap to preview a tee or pin, then Confirm. Pin 1 is used for practice."
	if had_preview:
		_describe() # Remove a stale "confirm or cancel" Build warning.
	layout_changed.emit()


func _remove_pin() -> void:
	_cancel_tool_gesture()
	var h: MHCraftHole = live.craft_hole
	if craft_mode != &"pin" or _pin_slot >= h.pins.size() or not h.begin_stroke():
		return
	h.remove_pin(_pin_slot)
	if h.commit_stroke():
		live._request_save()
	_refresh_canonical_craft()


func _refresh_canonical_craft() -> void:
	var problems: Array = MHCraftConvert.problems(live.craft_hole)
	if problems.is_empty():
		set_canonical_draft(live.canonical_craft_draft())
	else:
		canonical_draft.clear()
		_preview_draft = true
		_sync_mode_controls()
		var labels: PackedStringArray = PackedStringArray()
		for problem: Variant in problems:
			labels.append(_problem_text(str(problem)))
		_info.text = "Hole needs: " + ", ".join(labels)
		_set_validation_message("TO BUILD: " + ", ".join(labels))
		_draw()
		_describe()


func _placement_problem_text(message: String) -> String:
	if message == "hole geometry must remain on owned land":
		return "part of this hole crosses land you do not own. Move or shrink the course feature, or buy the neighbouring parcel."
	return message


func _set_validation_message(message: String) -> void:
	if _validation_hint != null:
		_validation_hint.text = message
		_validation_hint.tooltip_text = message
	if _preview_draft and _finalize_button != null:
		var ready: bool = message.begins_with("READY TO BUILD")
		_finalize_button.text = "Build hole" if ready else "Review hole"
		_finalize_button.theme_type_variation = &"GreenButton" if ready else &"ChipButton"
		_finalize_button.tooltip_text = message
		_details_button.text = "Details" if ready else "Fix design"
		_details_button.tooltip_text = message


func _problem_text(code: String) -> String:
	match code:
		"no_tee": return "place a tee"
		"no_pin": return "place a flag"
		"no_green": return "paint a putting green"
		"green_too_small": return "enlarge green (minimum 5-yd rating radius)"
		"green_too_large": return "shrink green (maximum 30-yd rating radius)"
		"hole_too_short": return "move tee or flag farther apart (minimum 60 yd)"
		"hole_too_long": return "reduce hole length (maximum 1000 yd)"
		"pin_not_on_green": return "move flag onto green"
		"tee_in_hazard": return "move tee out of water / OB"
		"too_many_trees": return "remove some trees"
		"too_complex": return "simplify painted hazards"
		"too_large": return "reduce hole footprint"
		_: return code.replace("_", " ")


func _repair_hole_markers() -> void:
	# Explicit user action: never silently erase an intentional water/OB hazard.
	if live == null or live.craft_hole == null or not _preview_draft:
		return
	_cancel_tool_gesture()
	var hole: MHCraftHole = live.craft_hole
	if hole.is_stroke_open():
		hole.cancel_stroke()
	if not hole.begin_stroke():
		return
	if hole.tees.is_empty():
		hole.add_tee(hole.cols / 2 - 1, 0)
	if hole.pins.is_empty():
		hole.add_pin(hole.cols / 2 - 1, mini(hole.rows - 2, 30))
	# Repaint a displaced flag tile first. Do not enlarge an existing,
	# rateable green: a three-tile repair brush previously inflated a six-yard
	# green to seven yards and pushed it across the unowned north parcel edge.
	for point: Variant in hole.pins:
		var pin: Vector2i = point as Vector2i
		hole.paint_tile(pin.x, pin.y, MHCraftHole.Surface.GREEN)
	# Older checkpoints may genuinely have tiny greens (RC006). Only then
	# extend the putting surface to reach the minimum rated area. This action
	# is explicitly chosen by the player, never run automatically.
	if MHCraftConvert.green_radius_yd(hole) < 5:
		for point: Variant in hole.pins:
			var pin: Vector2i = point as Vector2i
			hole.paint_disc(pin.x, pin.y, 3, MHCraftHole.Surface.GREEN)
	for point: Variant in hole.tees:
		var tee: Vector2i = point as Vector2i
		hole.paint_disc(tee.x, tee.y, 0, MHCraftHole.Surface.TEE)
	if hole.commit_stroke():
		live.sync_craft_tiles_to_world(hole.last_changed_tiles())
		live._request_save()
	_refresh_canonical_craft()
	# _refresh_canonical_craft/_describe checks readiness and may report a
	# different outstanding constraint (e.g. land ownership). Keep that result
	# visible instead of overwriting it with an unconditional success message.


func _craft_undo() -> void:
	_cancel_tool_gesture()
	if live.craft_hole != null and live.craft_hole.undo():
		live.sync_craft_tiles_to_world(live.craft_hole.last_changed_tiles())
		live._request_save()
		_refresh_canonical_craft()

func _craft_redo() -> void:
	_cancel_tool_gesture()
	if live.craft_hole != null and live.craft_hole.redo():
		live.sync_craft_tiles_to_world(live.craft_hole.last_changed_tiles())
		live._request_save()
		_refresh_canonical_craft()

func _draft_changed() -> void:
	_preview_draft = true
	_draw()
	_describe()

func _finalize() -> void:
	if live == null or live.shell.modal_id() != "":
		return
	if not _preview_draft or live.craft_hole == null:
		_set_validation_message("Already built. Use practice controls to play.")
		return
	_details_open = true
	_sync_mode_controls()
	if _pending_marker.x >= 0:
		_set_validation_message("Confirm or cancel the marker preview before building.")
		return
	if _craft_stroke_open:
		_cancel_tool_gesture()
	var problems: Array = MHCraftConvert.problems(live.craft_hole)
	if not problems.is_empty():
		var labels: PackedStringArray = PackedStringArray()
		for problem: Variant in problems:
			labels.append(_problem_text(str(problem)))
		var reason: String = ", ".join(labels)
		_info.text = "Cannot build: " + reason
		_set_validation_message("NOT READY: " + reason + ". Open Hole tools to place or repair markers.")
		return
	var h: Dictionary = live.canonical_craft_draft()
	var rating_check: Dictionary = MHRatingEngine.validate_input({
		"schema": 1, "engine": MHRatingEngine.RATING_VERSION, "hole": h})
	if h.is_empty() or not bool(rating_check.get("ok", false)) or not set_canonical_draft(h):
		var code: String = str(rating_check.get("code", "no layout"))
		_info.text = "Cannot build: check the tee, green and hole boundaries."
		_set_validation_message("TO BUILD: check the tee, green and hole boundaries.")
		push_warning("Course build validation: " + code)
		return
	live.router.cancel_world_input()
	if live.aim_input != null:
		live.aim_input.cancel_all()
	var encoded: MHSaveResult = MHCourseLayout.encode([h], live.document["course"] as Dictionary, [ORIGIN])
	if not encoded.is_ok():
		var explanation: String = _placement_problem_text(encoded.message)
		_info.text = "Cannot build: " + explanation
		_set_validation_message("TO BUILD: " + explanation)
		return
	var result: Dictionary = live.session.submit_course([h])
	if not bool(result["ok"]):
		var explanation: String = str(result["reason"])
		var rating_reasons: Array = result.get("rating_reasons", []) as Array
		if not rating_reasons.is_empty():
			var detail: PackedStringArray = PackedStringArray()
			for reason: Variant in rating_reasons:
				detail.append(str(reason))
			explanation += " (" + ", ".join(detail) + ")"
		_info.text = "Cannot build: " + explanation
		_set_validation_message("NOT READY: " + explanation)
		return
	_preview_draft = false
	canonical_draft.clear()
	_sync_mode_controls()
	live.document["course"] = encoded.value
	live.document["min_reader_version"] = 3
	live.session.practice = null # A redesign cannot continue a round on a previous layout.
	_restart()
	live._request_save()
	_draw()
	_describe()
	_set_validation_message("HOLE BUILT. Practice is ready to play.")


func _restart() -> void:
	if live.shell.modal_id() != "":
		return
	var layouts: Array = live.session.hole_definitions()
	if layouts.is_empty():
		_info.text = "Finalize your hole first."
		return
	_preview_draft = false
	canonical_draft.clear()
	_sync_mode_controls()
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
	_refresh_marker_controls()
	if _brush_size_button != null:
		_brush_size_button.text = "Brush: " + ("Detail" if craft_radius == 0 else ("Small" if craft_radius == 1 else "Wide"))
		_brush_size_button.tooltip_text = "Cycle Detail, Small and Wide brush footprints"
	if _strength_button != null:
		_strength_button.text = "Step: %.2f m" % (float(craft_step_mm) / 1000.0)
		_strength_button.tooltip_text = "Cycle Fine (0.25 m), Medium (0.50 m), Coarse (1.00 m)"
	_update_brush_hint()
	if live.craft_hole != null:
		if _undo_button != null:
			_undo_button.disabled = not live.craft_hole.can_undo()
		if _redo_button != null:
			_redo_button.disabled = not live.craft_hole.can_redo()
	if _preview_draft and live.craft_hole != null:
		var craft: MHCraftHole = live.craft_hole
		var hole_length: int = MHCraftConvert.length_yd(craft, 0, 0)
		var price: int = 0 if not live.session.hole_definitions().is_empty() else live.session.economy.hole_cost_cents()
		var tool_name: String = _surface_name(craft_surface) if craft_mode == &"surface" else str(craft_mode).capitalize()
		_title.text = "HOLE 1 • %d yd • %s" % [hole_length, tool_name]
		_title.tooltip_text = _title.text
		_info.text = "%d yd  |  %s  |  Build: $%d" % [hole_length, tool_name, price / 100]
		var problems: Array = MHCraftConvert.problems(craft)
		if problems.is_empty():
			# Craft/rating geometry can be valid while its world-space origin is
			# outside owned parcels. Do not advertise READY until the exact save
			# boundary has also confirmed land ownership.
			var layout: Dictionary = live.canonical_craft_draft()
			var placed: MHSaveResult = MHCourseLayout.encode(
				[layout], live.document["course"] as Dictionary, [ORIGIN])
			if placed.is_ok():
				_set_validation_message("READY TO BUILD  •  Tee, green, flag and land valid  •  $%d" % [price / 100])
			else:
				_set_validation_message("TO BUILD: " + _placement_problem_text(placed.message))
		else:
			var labels: PackedStringArray = PackedStringArray()
			for problem: Variant in problems:
				labels.append(_problem_text(str(problem)))
			_set_validation_message("TO BUILD: " + ", ".join(labels))
	else:
		_title.text = "HOLE 1 • PRACTICE"
		_info.text = "HOLE BUILT • PRACTICE MODE"
		_set_validation_message("PLAY MODE  •  Tap the course to aim, then Play shot.")
	var practice: MHPracticeRound = live.session.practice
	if practice != null:
		_info.text += " | %d strokes | %s" % [practice.strokes,
			"Picked up" if practice.picked_up else ("Holed" if practice.finished else "Playing")]
	var scores: Array = live.session.hole_results()
	if not scores.is_empty():
		_info.text += " | Official hole score %d/100" % int(scores[0]["score"])


func _draw() -> void:
	_path = null
	_brush_preview = null
	_marker_preview = null
	for child: Node in _world.get_children():
		_world.remove_child(child)
		child.queue_free()
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
			if str(feature.get("t", "")) == "tree" and feature.has("at"):
				for point: Variant in feature["at"] as Array:
					var at: Array = point as Array
					_draw_craft_tree(Vector2i(int(at[0]), int(at[1])))
				continue
			if not feature.has("rect"):
				continue
			var rect: Array = feature["rect"]
			var cx: int = (int(rect[0]) + int(rect[2])) * 50
			var cy: int = (int(rect[1]) + int(rect[3])) * 50
			var a: Vector3 = _position(int(rect[0]) * 100, int(rect[1]) * 100, 0.02)
			var b: Vector3 = _position(int(rect[2]) * 100, int(rect[3]) * 100, 0.02)
			var centre: Vector3 = (a + b) / 2.0
			centre.y = _ground_height(cx, cy) + 0.02
			_box(centre, Vector3(absf(b.x - a.x), 0.03, absf(b.z - a.z)), _feature_color(str(feature["t"])))
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
	mowing_design = MHMowingDesign.from_dict(hole.mowing)
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
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(_visual_settings.get("shadows", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(instance)
	if bool(_visual_settings.get("edge_accents", true)):
		_draw_surface_edges(hole, relief_hole)
	if bool(_visual_settings.get("mowing", true)):
		_draw_mowing_accents(hole, relief_hole)
	if bool(_visual_settings.get("terrain_detail", true)):
		_draw_hazard_depth(hole, relief_hole)
	_draw_environment_dressing(hole)
	if _preview_draft and _is_sculpt_mode():
		_draw_craft_grid(hole, relief_hole)
	for tee: Variant in hole.tees:
		var t: Vector2i = tee as Vector2i
		var tc: Vector2i = hole.tile_centre_yd(t.x, t.y)
		_draw_tee_furniture(tc)
	for pin: Variant in hole.pins:
		var p: Vector2i = pin as Vector2i
		var pc: Vector2i = hole.tile_centre_yd(p.x, p.y)
		_draw_flag(pc)
	for tree: Variant in hole.trees:
		_draw_craft_tree(tree as Vector2i)
	_refresh_brush_preview()
	_refresh_marker_preview()

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

func _is_sculpt_mode() -> bool:
	return craft_mode == &"raise" or craft_mode == &"lower" or craft_mode == &"smooth" or craft_mode == &"level"

func _draw_hazard_depth(hole: MHCraftHole, relief_hole: MHRHole) -> void:
	# Dark inset rims give bunkers and ponds readable depth at normal camera zoom.
	# Only exposed perimeter edges are emitted, in one batched mesh per hazard type.
	for hazard: int in [MHCraftHole.Surface.BUNKER, MHCraftHole.Surface.WATER]:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var added: bool = false
		for r: int in range(hole.rows):
			for c: int in range(hole.cols):
				if hole.get_surface(c, r) != hazard:
					continue
				var centre: Vector2i = hole.tile_centre_yd(c, r)
				var half: int = MHCraftHole.TILE_YD * 50
				for d: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nc: int = c + d.x
					var nr: int = r + d.y
					if hole.in_bounds(nc, nr) and hole.get_surface(nc, nr) == hazard:
						continue
					var ex: int = centre.x * 100 + d.x * half
					var ey: int = centre.y * 100 + d.y * half
					var tangent: Vector2i = Vector2i(-d.y, d.x)
					var a: Vector2i = Vector2i(ex, ey) + tangent * half
					var b: Vector2i = Vector2i(ex, ey) - tangent * half
					# Deterministic micro-offsets break the perfectly straight visual inset
					# without moving the authoritative hazard boundary.
					var wobble_seed: int = absi(c * 92821 + r * 68917 + d.x * 313 + d.y * 911 + hazard * 37)
					var inset_amount: int = 14 + (wobble_seed % 11)
					var tangent_shift: int = (wobble_seed % 13) - 6
					var inset: Vector2i = Vector2i(ex, ey) - d * inset_amount + tangent * tangent_shift
					var depth: float = 0.13 if hazard == MHCraftHole.Surface.BUNKER else 0.09
					for p: Vector2i in [a, b, inset]:
						var z: float = float(relief_hole.z_at(p.x, p.y)) / 1000.0
						st.add_vertex(_position(p.x, p.y, z + 0.045 - (depth if p == inset else 0.0)))
					added = true
		if not added:
			continue
		var mesh: ArrayMesh = st.commit()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.50, 0.40, 0.25) if hazard == MHCraftHole.Surface.BUNKER else Color(0.055, 0.20, 0.30)
		material.roughness = 1.0 if hazard == MHCraftHole.Surface.BUNKER else 0.30
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(instance)


func _draw_mowing_accents(hole: MHCraftHole, relief_hole: MHRHole) -> void:
	# Sample the configurable design at tile centres and emit one translucent
	# batch. Fairways and greens can use independent patterns and widths.
	var tee: Vector2i = hole.tees[0] as Vector2i if not hole.tees.is_empty() else Vector2i(hole.cols / 2, 0)
	var pin: Vector2i = hole.pins[0] as Vector2i if not hole.pins.is_empty() else Vector2i(hole.cols / 2, hole.rows - 1)
	var delta: Vector2 = Vector2(float(pin.x - tee.x), float(pin.y - tee.y))
	var along_angle: float = atan2(delta.y, delta.x)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added: bool = false
	for r: int in range(hole.rows):
		for c: int in range(hole.cols):
			var surface: int = hole.get_surface(c, r)
			if surface not in [MHCraftHole.Surface.FAIRWAY, MHCraftHole.Surface.GREEN, MHCraftHole.Surface.TEE]:
				continue
			var centre_yd: Vector2i = hole.tile_centre_yd(c, r)
			if not mowing_design.highlighted(surface, float(centre_yd.x), float(centre_yd.y), along_angle):
				continue
			var x0: int = hole.tile_x0_yd(c) * 100
			var x1: int = (hole.tile_x0_yd(c) + MHCraftHole.TILE_YD) * 100
			var y0: int = hole.tile_y0_yd(r) * 100
			var y1: int = (hole.tile_y0_yd(r) + MHCraftHole.TILE_YD) * 100
			for point: Vector2i in [Vector2i(x0, y0), Vector2i(x1, y0), Vector2i(x1, y1),
					Vector2i(x0, y0), Vector2i(x1, y1), Vector2i(x0, y1)]:
				st.set_normal(_craft_normal(relief_hole, point.x, point.y))
				var z: float = float(relief_hole.z_at(point.x, point.y)) / 1000.0
				st.add_vertex(_position(point.x, point.y, z + 0.052))
			added = true
	if not added:
		return
	var mesh: ArrayMesh = st.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.82, 0.95, 0.55, mowing_design.intensity)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.78
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(instance)


func set_mowing_pattern(surface: int, pattern: MHMowingDesign.Pattern) -> void:
	mowing_design.set_surface_pattern(surface, pattern)
	if live != null and live.craft_hole != null:
		live.craft_hole.mowing = mowing_design.to_dict()
		live._request_save()
	if _world != null and is_inside_tree():
		_draw()


func set_mowing_direction(degrees: int) -> void:
	mowing_design.direction_deg = posmod(degrees, 180)
	if live != null and live.craft_hole != null:
		live.craft_hole.mowing = mowing_design.to_dict()
		live._request_save()
	if _world != null and is_inside_tree():
		_draw()


func _draw_craft_grid(hole: MHCraftHole, relief_hole: MHRHole) -> void:
	# One lightweight line mesh makes the editable 2-yard tiles legible without
	# creating hundreds of Control/Mesh nodes or baking grid lines into gameplay.
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	for c: int in range(hole.cols + 1):
		var x: int = hole.tile_x0_yd(0) * 100 + c * MHCraftHole.TILE_YD * 100
		for r: int in range(hole.rows):
			var y0: int = hole.tile_y0_yd(r) * 100
			var y1: int = (hole.tile_y0_yd(r) + MHCraftHole.TILE_YD) * 100
			var z0: float = float(relief_hole.z_at(x, y0)) / 1000.0 + 0.085
			var z1: float = float(relief_hole.z_at(x, y1)) / 1000.0 + 0.085
			st.add_vertex(_position(x, y0, z0))
			st.add_vertex(_position(x, y1, z1))
	for r: int in range(hole.rows + 1):
		var y: int = r * MHCraftHole.TILE_YD * 100
		for c: int in range(hole.cols):
			var x0: int = hole.tile_x0_yd(c) * 100
			var x1: int = (hole.tile_x0_yd(c) + MHCraftHole.TILE_YD) * 100
			var z0: float = float(relief_hole.z_at(x0, y)) / 1000.0 + 0.085
			var z1: float = float(relief_hole.z_at(x1, y)) / 1000.0 + 0.085
			st.add_vertex(_position(x0, y, z0))
			st.add_vertex(_position(x1, y, z1))
	var mesh: ArrayMesh = st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.06, 0.10, 0.06, 0.26)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	_world.add_child(instance)


func _draw_surface_edges(hole: MHCraftHole, relief_hole: MHRHole) -> void:
	# Batch accent ribbons by surface. This replaces hundreds of tiny BoxMesh nodes
	# with at most five drawables while preserving the same readable boundaries.
	var builders: Dictionary = {}
	var added: Dictionary = {}
	for surface: int in [MHCraftHole.Surface.GREEN, MHCraftHole.Surface.FRINGE,
			MHCraftHole.Surface.TEE, MHCraftHole.Surface.BUNKER, MHCraftHole.Surface.WATER]:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		builders[surface] = st
		added[surface] = false
	var half: int = MHCraftHole.TILE_YD * 50
	var ribbon_half: int = 4
	for r: int in range(hole.rows):
		for c: int in range(hole.cols):
			var surface: int = hole.get_surface(c, r)
			if not builders.has(surface):
				continue
			var centre: Vector2i = hole.tile_centre_yd(c, r)
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nc: int = c + d.x
				var nr: int = r + d.y
				if hole.in_bounds(nc, nr) and hole.get_surface(nc, nr) == surface:
					continue
				var edge: Vector2i = centre * 100 + d * half
				var tangent: Vector2i = Vector2i(-d.y, d.x)
				var p0: Vector2i = edge - tangent * half - d * ribbon_half
				var p1: Vector2i = edge + tangent * half - d * ribbon_half
				var p2: Vector2i = edge + tangent * half + d * ribbon_half
				var p3: Vector2i = edge - tangent * half + d * ribbon_half
				var st: SurfaceTool = builders[surface] as SurfaceTool
				for p: Vector2i in [p0, p1, p2, p0, p2, p3]:
					st.set_normal(_craft_normal(relief_hole, p.x, p.y))
					var z: float = float(relief_hole.z_at(p.x, p.y)) / 1000.0
					st.add_vertex(_position(p.x, p.y, z + 0.066))
				added[surface] = true
	for key: Variant in builders.keys():
		var surface: int = int(key)
		if not bool(added[surface]):
			continue
		var mesh: ArrayMesh = (builders[surface] as SurfaceTool).commit()
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = _edge_color(surface)
		material.roughness = 0.86
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(instance)

func _edge_color(surface_id: int) -> Color:
	match surface_id:
		MHCraftHole.Surface.GREEN: return Color(0.70, 0.90, 0.42)
		MHCraftHole.Surface.FRINGE: return Color(0.50, 0.76, 0.30)
		MHCraftHole.Surface.TEE: return Color(0.58, 0.82, 0.34)
		MHCraftHole.Surface.BUNKER: return Color(0.88, 0.80, 0.58)
		MHCraftHole.Surface.WATER: return Color(0.25, 0.62, 0.88)
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
	# Mobile-first readability: keep materials cheap, but separate turf cuts by
	# roughness/specular response so fairway, fringe and green remain legible when
	# their colours compress on a small display. Hazards get a stronger material
	# identity without textures or extra draw passes.
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _surface_color(surface_id)
	material.roughness = 0.92
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	match surface_id:
		MHCraftHole.Surface.GREEN:
			material.roughness = 0.58
			material.metallic_specular = 0.22
		MHCraftHole.Surface.FRINGE:
			material.roughness = 0.68
			material.metallic_specular = 0.16
		MHCraftHole.Surface.FAIRWAY, MHCraftHole.Surface.TEE:
			material.roughness = 0.76
			material.metallic_specular = 0.12
		MHCraftHole.Surface.BUNKER, MHCraftHole.Surface.WASTE:
			material.roughness = 1.0
			material.metallic_specular = 0.04
		MHCraftHole.Surface.PATH, MHCraftHole.Surface.DIRT:
			material.roughness = 0.88
		MHCraftHole.Surface.WATER:
			material.roughness = 0.12 if bool(_visual_settings.get("water_detail", true)) else 0.24
			material.metallic = 0.08
			material.metallic_specular = 0.52 if bool(_visual_settings.get("water_detail", true)) else 0.22
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var water: Color = material.albedo_color
			water.a = 0.86
			material.albedo_color = water
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _draw_environment_dressing(hole: MHCraftHole) -> void:
	# Reuse the procedural art library rather than growing a second prop system.
	# Placement is deterministic and only occupies rough/out-of-play tiles, so the
	# richer scene never changes collision, rating or authored playing surfaces.
	var density: float = float(_visual_settings.get("decor_density", 0.65))
	if density < 0.3:
		return
	var lod: int = 0 if density >= 0.8 else 1
	var nature_mat: StandardMaterial3D = StandardMaterial3D.new()
	nature_mat.vertex_color_use_as_albedo = true
	nature_mat.roughness = 0.92
	var step: int = 7 if density >= 0.8 else 10
	for r: int in range(2, hole.rows - 2, step):
		for c: int in range(2, hole.cols - 2, step):
			var surface: int = hole.get_surface(c, r)
			if surface != MHCraftHole.Surface.ROUGH:
				continue
			var seed_value: int = c * 73856093 ^ r * 19349663
			var kind: String = "bush"
			if seed_value % 5 == 0:
				kind = "rock_cluster"
			elif seed_value % 3 == 0:
				kind = "flower_patch"
			var centre: Vector2i = hole.tile_centre_yd(c, r)
			var variant: int = absi(seed_value) % MHNatureMeshes.VARIANTS
			var mesh: ArrayMesh = MHNatureMeshes.build(kind, lod, variant)
			var instance: MeshInstance3D = MeshInstance3D.new()
			instance.mesh = mesh
			instance.material_override = nature_mat
			instance.position = _position_on_ground(centre.x * 100, centre.y * 100, 0.02)
			instance.rotation.y = float(absi(seed_value) % 628) / 100.0
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(_visual_settings.get("shadows", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(instance)
	# Water margins get sparse reeds. They are intentionally sampled rather than
	# tracing every shoreline tile, keeping both visual noise and node count down.
	if bool(_visual_settings.get("water_detail", true)):
		for r: int in range(1, hole.rows - 1, 3):
			for c: int in range(1, hole.cols - 1, 3):
				if hole.get_surface(c, r) != MHCraftHole.Surface.WATER:
					continue
				var near_land: bool = false
				for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if hole.get_surface(c + d.x, r + d.y) != MHCraftHole.Surface.WATER:
						near_land = true
				if not near_land:
					continue
				var wc: Vector2i = hole.tile_centre_yd(c, r)
				var reed: MeshInstance3D = MeshInstance3D.new()
				reed.mesh = MHNatureMeshes.build("reeds", lod, (c + r) % MHNatureMeshes.VARIANTS)
				reed.material_override = nature_mat
				reed.position = _position_on_ground(wc.x * 100, wc.y * 100, 0.04)
				reed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_world.add_child(reed)


func _draw_prop(kind: String, point: Vector2i, variant: int = 0, yaw: float = 0.0) -> void:
	var lod: int = 0 if float(_visual_settings.get("decor_density", 0.65)) >= 0.8 else 1
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.88
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = MHPropMeshes.build(kind, lod, variant)
	instance.material_override = material
	instance.position = _position_on_ground(point.x * 100, point.y * 100, 0.025)
	instance.rotation.y = yaw
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(_visual_settings.get("shadows", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(instance)


func _draw_tee_furniture(point: Vector2i) -> void:
	_draw_prop("tee_marker", point + Vector2i(-1, 0), 0)
	_draw_prop("tee_marker", point + Vector2i(1, 0), 0)
	if float(_visual_settings.get("decor_density", 0.65)) >= 0.6:
		_draw_prop("sign", point + Vector2i(2, -1), 0, 0.25)


func _draw_flag(point: Vector2i) -> void:
	_draw_prop("flag", point, 0)


func _draw_craft_tree(point: Vector2i) -> void:
	var density: float = float(_visual_settings.get("decor_density", 0.65))
	var lod: int = 0 if density >= 0.8 else (1 if density >= 0.45 else 2)
	var variant: int = absi(point.x * 31 + point.y * 17) % MHNatureMeshes.VARIANTS
	var species: String = ["oak", "pine", "birch"][absi(point.x * 7 + point.y * 11) % 3]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.94
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = MHNatureMeshes.build(species, lod, variant)
	instance.material_override = material
	instance.position = _position_on_ground(point.x * 100, point.y * 100, 0.0)
	instance.rotation.y = float(absi(point.x * 13 + point.y * 29) % 628) / 100.0
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if bool(_visual_settings.get("shadows", true)) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(instance)

func set_visual_quality(tier: MHVisualQuality.Tier) -> void:
	visual_quality = tier
	_visual_settings = MHVisualQuality.settings(tier)
	if _world != null and is_inside_tree():
		_draw()


func visual_quality_name() -> String:
	return MHVisualQuality.name_for(visual_quality)


func _feature_color(feature_type: String) -> Color:
	match feature_type:
		"fairway": return Color(0.36, 0.64, 0.23)
		"deep_rough": return Color(0.18, 0.36, 0.14)
		"bunker": return Color(0.72, 0.66, 0.48)
		"water": return Color(0.12, 0.4, 0.7)
		"ob": return Color(0.24, 0.20, 0.18)
		_: return Color(0.27, 0.44, 0.21)


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
	# Deliberately compressed, warm golf-course palette: distinct enough to read
	# at phone scale without the neon mini-golf look. Lighting/material response
	# provides the second cue instead of relying on colour alone.
	match surface_id:
		MHCraftHole.Surface.FAIRWAY: return Color(0.34, 0.62, 0.25)
		MHCraftHole.Surface.FIRST_CUT: return Color(0.29, 0.52, 0.22)
		MHCraftHole.Surface.DEEP_ROUGH: return Color(0.16, 0.32, 0.15)
		MHCraftHole.Surface.GREEN: return Color(0.47, 0.76, 0.32)
		MHCraftHole.Surface.FRINGE: return Color(0.39, 0.66, 0.27)
		MHCraftHole.Surface.TEE: return Color(0.43, 0.70, 0.30)
		MHCraftHole.Surface.BUNKER: return Color(0.76, 0.68, 0.49)
		MHCraftHole.Surface.WASTE: return Color(0.55, 0.46, 0.34)
		MHCraftHole.Surface.WATER: return Color(0.10, 0.38, 0.66)
		MHCraftHole.Surface.OUT_OF_BOUNDS: return Color(0.20, 0.18, 0.16)
		MHCraftHole.Surface.PATH: return Color(0.44, 0.42, 0.37)
		MHCraftHole.Surface.DIRT: return Color(0.43, 0.30, 0.19)
		_: return Color(0.24, 0.42, 0.20)

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
	# Course decoding/rating validation owns canonical correctness. This view adds
	# only rendering constraints: its area renderer is rectangle based, while
	# relief and positioned tree features are fully supported.
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
	if not bool(validation.get("ok", false)):
		return false
	for row_feature: Variant in h.get("features", []):
		var feature: Dictionary = row_feature as Dictionary
		var t: String = str(feature.get("t", ""))
		if ["fairway", "deep_rough", "bunker", "water", "ob"].has(t) and not feature.has("rect"):
			return false
	return true


func blocks_world_tap(pos: Vector2) -> bool:
	# A visible panel that has not been laid out yet (zero size) still counts as 1x1 so it never leaks a tap.
	var own: Rect2 = live._panel_frame.get_global_rect() if live._panel_frame != null else get_global_rect()
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
	# Height along a camera ray is not monotonic relative to rolling terrain: a
	# ray can touch a raised crest, pass back above a valley, then hit flat ground
	# farther away. First walk the ray from the camera to find the *first* sign
	# change, then bisect only that bracket. A whole-range binary search can skip
	# the crest and select the later intersection.
	var low_plane: float = -40.0 # Below the rating schema minimum relief (-32.768 m).
	var max_t: float = (low_plane - origin.y) / direction.y
	if max_t <= 0.0:
		return {"ok": false}
	var steps: int = 128
	var above_t: float = 0.0
	var hit_t: float = -1.0
	for i: int in range(1, steps + 1):
		var sample_t: float = max_t * float(i) / float(steps)
		var sample: Vector3 = origin + direction * sample_t
		var local_x_mm: int = roundi(sample.x * 1000.0) - int(ORIGIN[0]) * 100
		var local_y_mm: int = roundi(sample.z * 1000.0) - int(ORIGIN[1]) * 100
		var x_cy: int = MHRMath.rdiv(local_x_mm * 1000, 9144)
		var y_cy: int = MHRMath.rdiv(local_y_mm * 1000, 9144)
		var ground: float = float(relief_hole.z_at(x_cy, y_cy)) / 1000.0
		if sample.y <= ground:
			hit_t = sample_t
			break
		above_t = sample_t
	if hit_t < 0.0:
		return {"ok": false}
	for _i: int in range(20):
		var mid_t: float = (above_t + hit_t) * 0.5
		var point: Vector3 = origin + direction * mid_t
		var local_x_mm: int = roundi(point.x * 1000.0) - int(ORIGIN[0]) * 100
		var local_y_mm: int = roundi(point.z * 1000.0) - int(ORIGIN[1]) * 100
		var x_cy: int = MHRMath.rdiv(local_x_mm * 1000, 9144)
		var y_cy: int = MHRMath.rdiv(local_y_mm * 1000, 9144)
		var ground: float = float(relief_hole.z_at(x_cy, y_cy)) / 1000.0
		if point.y > ground:
			above_t = mid_t
		else:
			hit_t = mid_t
	return {"ok": true, "hit": origin + direction * hit_t}


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
	# Reverse MHCourseLayout.world_mm() into centiyards. The previous code
	# produced centiyards but passed them to tile_at_yd(), a factor-of-100 error
	# that sent almost every visible click outside the craft grid.
	var x_cy: int = MHRMath.rdiv(local_x_mm * 1000, 9144)
	var y_cy: int = MHRMath.rdiv(local_y_mm * 1000, 9144)
	return live.craft_hole.tile_at_cy(x_cy, y_cy)


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
		h.raise_disc_mm(tile.x, tile.y, craft_radius, craft_step_mm if craft_mode == &"raise" else -craft_step_mm)
	elif craft_mode == &"smooth":
		h.smooth_disc(tile.x, tile.y, craft_radius)
	elif craft_mode == &"level":
		h.level_disc_mm(tile.x, tile.y, craft_radius, _craft_level_height)
	elif craft_mode == &"surface":
		h.paint_disc(tile.x, tile.y, craft_radius, craft_surface)
	else:
		return false
	return true


func craft_stroke_begin_from_screen(pos: Vector2) -> bool:
	var tile: Vector2i = _craft_tile_from_screen(pos)
	if tile.x < 0:
		return false
	if craft_mode == &"tee" or craft_mode == &"pin":
		return stage_marker_at_tile(tile)
	if live.craft_hole.is_stroke_open():
		live.craft_hole.cancel_stroke()
	if not live.craft_hole.begin_stroke():
		return false
	_craft_stroke_open = true
	_craft_last_tile = tile
	_brush_tile = tile
	if craft_mode == &"level":
		_craft_level_height = live.craft_hole.get_height_mm(tile.x, tile.y)
	_apply_craft_stroke_tile(tile)
	_craft_preview_dirty = true
	return true


func craft_stroke_move_from_screen(pos: Vector2) -> bool:
	if craft_mode in [&"tee", &"pin"]:
		return stage_marker_at_tile(_craft_tile_from_screen(pos))
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
	_brush_tile = tile
	_craft_preview_dirty = true
	return true


func craft_stroke_end() -> bool:
	if not _craft_stroke_open or live == null or live.craft_hole == null:
		return false
	_craft_stroke_open = false
	_craft_last_tile = Vector2i(-1, -1)
	var changed: bool = live.craft_hole.commit_stroke()
	_craft_preview_dirty = false
	clear_brush_preview()
	if changed:
		live.sync_craft_tiles_to_world(live.craft_hole.last_changed_tiles())
		live._request_save()
		_refresh_canonical_craft()
	return changed


func craft_stroke_cancel() -> void:
	_cancel_marker_preview()
	clear_brush_preview()
	if live != null and live.craft_hole != null and live.craft_hole.is_stroke_open():
		live.craft_hole.cancel_stroke()
	_craft_stroke_open = false
	_craft_last_tile = Vector2i(-1, -1)
	_craft_preview_dirty = false
	if _preview_draft and _world != null:
		_draw()

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
		if _craft_category == &"markers":
			_feedback.text = "Tap to preview a tee or pin, then Confirm. Pin 1 is used for practice."
		elif _craft_category == &"terrain":
			_feedback.text = "Drag to shape the ground. Two fingers move the camera."
		else:
			_feedback.text = "Drag to paint the ground. Two fingers move the camera."
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
