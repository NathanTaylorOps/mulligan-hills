class_name MHEditorScreen
extends MHScreen
## Hole editor toolbar (overlay on the 3D view): raise, lower, smooth, level, paint, brush radius, surface picker
## (only while Paint is chosen), Undo and Redo (always visible), Done. It only reports the chosen brush:
## editor_tool {tool, brush_mode, radius, surface, surface_layer}, editor_undo, editor_redo.
## brush_mode is an MHBrush.Mode int (see MHEditorTools). One finger paints, two fingers move the camera: that
## lives in game/input/, not here. Pass button_rect_getters() to MHInputRouter.register_ui_region so a tap on a
## button never paints.

var _tool: StringName = MHEditorTools.RAISE
var _radius: int = MHEditorTools.RADIUS_DEFAULT
var _surface: String = "fairway"
var _tool_buttons: Dictionary = {}
var _surface_buttons: Dictionary = {}
var _surface_row: Control
var _radius_label: Label
var _undo: MHTapButton
var _redo: MHTapButton
var _done: MHTapButton
var _pause: MHTapButton
var _minus: MHTapButton
var _plus: MHTapButton
var _slot: Control


func _init() -> void:
	is_overlay = true


func screen_id() -> String:
	return MHScreenIds.EDITOR


func current_selection() -> Dictionary:
	return {
		"tool": _tool,
		"brush_mode": MHEditorTools.brush_mode(_tool),
		"radius": _radius,
		"surface": _surface,
		"surface_layer": MHEditorTools.surface_layer(_surface),
	}


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MHTheme.GUTTER)
	add_child(margin)
	var root: VBoxContainer = MHUIKit.vbox(8)
	# This overlay uses an expanding spacer as the authoritative world/free zone.
	# The VBox itself must fill the full MarginContainer or the spacer collapses,
	# causing live-construction controls and the one-hole panel to overlap the
	# editor toolbar at the top of the viewport.
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	var top: HFlowContainer = MHUIKit.flow(8)
	root.add_child(top)
	_done = MHUIKit.button(ctx, MHStrings.t("editor.done"), &"GreenButton", 110.0)
	_done.pressed.connect(request_back)
	_pause = MHUIKit.button(ctx, MHStrings.t("hud.pause"), &"ChipButton", 110.0)
	_pause.pressed.connect(send.bind(&"toggle_pause", {}))
	_undo = MHUIKit.button(ctx, MHStrings.t("editor.undo"), &"ChipButton", 110.0)
	_undo.pressed.connect(send.bind(&"editor_undo", {}))
	_redo = MHUIKit.button(ctx, MHStrings.t("editor.redo"), &"ChipButton", 110.0)
	_redo.pressed.connect(send.bind(&"editor_redo", {}))
	_minus = MHUIKit.button(ctx, MHStrings.t("ui.common.minus"), &"ChipButton")
	_minus.pressed.connect(_on_radius.bind(-2))
	_plus = MHUIKit.button(ctx, MHStrings.t("ui.common.plus"), &"ChipButton")
	_plus.pressed.connect(_on_radius.bind(2))
	var rad_chip: PanelContainer = MHUIKit.panel(&"HudChip")
	_radius_label = MHUIKit.label("", &"HudLabel", false)
	rad_chip.add_child(_radius_label)
	var items: Array = [_done, _pause, _undo, _redo, _minus, rad_chip, _plus]
	if ctx.left_handed():
		items.reverse()
	for it: Variant in items:
		top.add_child(it)

	_slot = MHUIKit.spacer()
	root.add_child(_slot)

	_surface_row = MHUIKit.flow(6)
	root.add_child(_surface_row)
	for sname: Variant in MHEditorTools.surface_names():
		var sn: String = str(sname)
		var sb: MHTapButton = MHUIKit.button(ctx, MHStrings.t(MHEditorTools.surface_label_key(sn)), &"ChipButton", 96.0)
		sb.pressed.connect(_on_surface.bind(sn))
		_surface_row.add_child(sb)
		_surface_buttons[sn] = sb

	var bar: HBoxContainer = MHUIKit.hbox(8)
	root.add_child(bar)
	var ids: Array = MHEditorTools.tool_ids()
	var ordered: Array = ids.duplicate()
	if ctx.left_handed():
		ordered.reverse()
	for tid: Variant in ordered:
		var t: StringName = tid
		var tb: MHTapButton = MHUIKit.button(ctx, MHStrings.t(MHEditorTools.label_key(t)), &"ChipButton", 96.0)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(_on_tool.bind(t))
		bar.add_child(tb)
		_tool_buttons[t] = tb


func free_rect() -> Rect2:
	if _slot == null or not is_instance_valid(_slot) or not _slot.is_visible_in_tree():
		return Rect2()
	return _slot.get_global_rect()


func refresh() -> void:
	if _undo == null:
		return
	_radius_label.text = MHStrings.t("editor.radius", {"cells": _radius})
	_pause.text = MHStrings.t("hud.resume" if view.is_paused() else "hud.pause")
	_undo.disabled = not view.can_undo()
	_redo.disabled = not view.can_redo()
	_minus.disabled = _radius <= MHEditorTools.RADIUS_MIN
	_plus.disabled = _radius >= MHEditorTools.RADIUS_MAX
	for k: Variant in _tool_buttons.keys():
		var b: MHTapButton = _tool_buttons[k]
		b.theme_type_variation = &"SelectedButton" if StringName(k) == _tool else &"ChipButton"
	_surface_row.visible = _tool == MHEditorTools.PAINT
	for k2: Variant in _surface_buttons.keys():
		var sb: MHTapButton = _surface_buttons[k2]
		sb.theme_type_variation = &"SelectedButton" if str(k2) == _surface else &"ChipButton"


func _announce() -> void:
	send(&"editor_tool", current_selection())
	refresh()


func _on_tool(t: StringName) -> void:
	_tool = t
	_announce()


func _on_radius(delta: int) -> void:
	_radius = MHEditorTools.clamp_radius(_radius + delta)
	_announce()


func _on_surface(sname: String) -> void:
	_surface = sname
	_tool = MHEditorTools.PAINT
	_announce()


func region_buttons() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in _tool_buttons.keys():
		out[StringName("editor_tool_" + str(k))] = _tool_buttons[k]
	for k2: Variant in _surface_buttons.keys():
		out[StringName("editor_surface_" + str(k2))] = _surface_buttons[k2]
	out[&"editor_done"] = _done
	out[&"editor_pause"] = _pause
	out[&"editor_undo"] = _undo
	out[&"editor_redo"] = _redo
	out[&"editor_minus"] = _minus
	out[&"editor_plus"] = _plus
	return out
