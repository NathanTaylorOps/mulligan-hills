extends SceneTree
## Dependency-free vertical-slice smoke probe. Run with:
## godot --headless --path ".\game" --script res://tests/manual_verify_live_ui.gd
##
## Creates an isolated save path; never alters the player's ordinary live slot.
## This intentionally does not depend on gdUnit4 (which may be absent locally).

func _initialize() -> void:
	call_deferred("_verify")


func _fail(reason: String) -> void:
	printerr("LIVE_UI_PROBE FAIL: " + reason)
	quit(1)


func _verify() -> void:
	# A fresh isolated slot for every run; an earlier successful probe must not
	# leave a finalized hole that makes this run a false failure.
	var probe_id: String = str(Time.get_ticks_usec())
	var live: MHLiveConstruction = MHLiveConstruction.new()
	live.store = MHSaveStore.new("user://manual_verify_live_ui/" + probe_id + "/saves")
	live.ledger_dir = "user://manual_verify_live_ui/" + probe_id + "/ledgers"
	root.add_child(live)
	await process_frame
	await process_frame
	if not live._active or live.shell == null or live.editor == null:
		_fail("Live Construction failed to initialize")
		return
	var viewport_size: Vector2 = root.get_visible_rect().size
	var shell: MHUIShell = live.shell
	var hud: MHHudScreen = shell._top_node() as MHHudScreen
	if hud == null:
		_fail("HUD not present")
		return
	live._relayout()
	var nav_rect: Rect2 = hud._nav_row.get_global_rect()
	var top_rect: Rect2 = hud._speed_row.get_global_rect()
	var free_rect: Rect2 = shell.overlay_free_rect()
	var actions_rect: Rect2 = live._actions.get_global_rect()
	print("LIVE_UI_PROBE viewport=", viewport_size,
		" shell=", shell.get_global_rect(),
		" host=", shell._host.get_global_rect(),
		" hud=", hud.get_global_rect(),
		" speed=", top_rect,
		" nav=", nav_rect,
		" free=", free_rect,
		" actions=", actions_rect)
	if shell.size.distance_to(viewport_size) > 2.0:
		_fail("UI shell does not fill the viewport")
		return
	if shell._host.size.x < viewport_size.x * 0.65 or shell._host.size.y < viewport_size.y * 0.65:
		_fail("Safe-area screen host is unexpectedly small")
		return
	if nav_rect.end.y < shell._host.get_global_rect().end.y - shell.ctx.touch_min() * 1.5:
		_fail("Bottom HUD navigation is floating above the bottom")
		return
	if free_rect.size.y < viewport_size.y * 0.25:
		_fail("HUD left no usable world space")
		return
	if live._actions.visible and actions_rect.intersects(hud._top_flow.get_global_rect(), false):
		_fail("Save/Build buttons overlap cash/time header")
		return

	# The normal editor must truly own strokes, not merely show an orange Edit label.
	shell.push_screen(MHScreenIds.EDITOR)
	await process_frame
	var editor_screen: MHEditorScreen = shell._top_node() as MHEditorScreen
	if editor_screen == null or not live.router.accept_world_input:
		_fail("Normal editor did not take world input")
		return
	if editor_screen.free_rect().size.y < viewport_size.y * 0.25:
		_fail("Normal editor toolbar leaves no editable world area")
		return
	var tile: Vector2i = Vector2i(8, 12)
	var centre: Vector2i = live.craft_hole.tile_centre_yd(tile.x, tile.y)
	var sample_x: int = MHRMath.rdiv(MHCourseLayout.world_mm(480, centre.x * 100), live.editor.grid.cell_size_mm)
	var sample_y: int = MHRMath.rdiv(MHCourseLayout.world_mm(340, centre.y * 100), live.editor.grid.cell_size_mm)
	live.editor.set_paint_brush(MHSplatMap.Layer.WATER, 1, 1000)
	if not live.editor.begin_stroke():
		_fail("Normal editor could not begin a stroke")
		return
	live.editor.apply_brush_at(sample_x, sample_y)
	live.editor.end_stroke()
	if live.craft_hole.get_surface(tile.x, tile.y) != MHCraftHole.Surface.WATER:
		_fail("Normal editor water did not reach canonical craft")
		return

	# Build/play must work on that same world and have an open, reachable panel.
	shell.pop_screen()
	live._open_craft_hole()
	await process_frame
	live._relayout()
	if not live.one_hole.visible or live._panel_frame.size.y < shell.ctx.touch_min() * 2.0:
		_fail("Build/play panel did not open with usable height")
		return
	if live.craft_hole.get_surface(tile.x, tile.y) != MHCraftHole.Surface.WATER:
		_fail("Build/play lost normal editor water")
		return
	live.one_hole.craft_mode = &"surface"
	live.one_hole.craft_surface = MHCraftHole.Surface.PATH
	if not live.one_hole.craft_at_tile(tile.x, tile.y):
		_fail("Canonical craft refused a path edit")
		return
	if live.editor.splat.get_weight(sample_x, sample_y, MHSplatMap.Layer.PATH) != 255:
		_fail("Craft path did not reach shared terrain")
		return
	if live.one_hole._is_sculpt_mode():
		_fail("Design grid would show while painting a surface")
		return
	live.one_hole._select_category(&"terrain")
	if not live.one_hole._is_sculpt_mode():
		_fail("Sculpt grid is missing in terrain mode")
		return
	live.one_hole._select_category(&"surfaces")
	# Regression: repainting the flag location as water must NOT silently switch
	# the unfinished hole to practice-only mode when Build/play is reopened.
	var pin_tile: Vector2i = live.craft_hole.pins[0] as Vector2i
	live.one_hole.craft_surface = MHCraftHole.Surface.WATER
	live.one_hole.craft_mode = &"surface"
	if not live.one_hole.craft_at_tile(pin_tile.x, pin_tile.y):
		_fail("Painting at the current pin failed")
		return
	live.one_hole.close_preview()
	live._open_craft_hole()
	if not live.one_hole._preview_draft or not live.one_hole._finalize_button.visible:
		_fail("Invalid draft reopened without edit/build controls")
		return
	live.one_hole._repair_hole_markers()
	var problems: Array = MHCraftConvert.problems(live.craft_hole)
	if not problems.is_empty():
		_fail("Marker repair did not make the hole playable: " + str(problems))
		return
	live.one_hole._finalize()
	if live.session.hole_definitions().is_empty():
		_fail("Build hole did not finalize: " + live.one_hole._info.text + " | " + live.one_hole._validation_hint.text)
		return
	if live.session.practice == null:
		_fail("Finalization did not create a practice round")
		return
	if live.one_hole._category_row.visible or live.one_hole._history_row.visible or live.one_hole._finalize_button.visible:
		_fail("Craft-only menu still visible on finalized practice hole")
		return
	print("LIVE_UI_PROBE PASS: HUD/layout, editors, sculpt-only grid, marker repair, hole finalization and practice")
	quit(0)
