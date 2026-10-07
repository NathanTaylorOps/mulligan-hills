extends SceneTree
## Dependency-free vertical-slice smoke probe. Run with:
## godot --headless --path ".\game" --script res://tests/manual_verify_live_ui.gd
##
## Creates an isolated save path; never alters the player's ordinary live slot.
## This intentionally does not depend on gdUnit4 (which may be absent locally).

func _initialize() -> void:
	# Headless defaults can be square; exercise the Android-first landscape layout.
	root.size = Vector2i(1280, 720)
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
	# The palette may scroll, but navigation and history must stay reachable.
	var panel: MHOneHolePanel = live.one_hole
	if panel._scroll.is_ancestor_of(panel._category_row) or panel._scroll.is_ancestor_of(panel._history_row):
		_fail("Design navigation/history scroll away with the palette")
		return
	panel._select_category(&"terrain")
	panel._select_mode(&"smooth")
	panel._select_category(&"markers")
	panel._select_mode(&"pin")
	panel._select_category(&"terrain")
	if panel.craft_mode != &"smooth":
		_fail("Category switch forgot the selected terrain tool")
		return
	panel._select_category(&"markers")
	if panel.craft_mode != &"pin":
		_fail("Category switch forgot the selected marker tool")
		return
	panel.set_collapsed(true)
	if panel._category_row.visible or panel._history_row.visible or panel._scroll.visible:
		_fail("Hidden tools still occupy the collapsed panel")
		return
	if not panel._close.visible or not panel._finalize_button.visible:
		_fail("Collapsed design lost Close or Build")
		return
	panel.set_collapsed(false)
	panel._select_category(&"surfaces")
	# Switching categories during an unfinished stroke must restore the ground.
	var height_before: int = live.craft_hole.get_height_mm(tile.x, tile.y)
	var history_before: int = live.craft_hole.undo_count()
	if not live.craft_hole.begin_stroke():
		_fail("Could not start navigation cancellation regression")
		return
	panel._craft_stroke_open = true
	live.craft_hole.raise_disc(tile.x, tile.y, 0, 1)
	panel._select_category(&"terrain")
	if live.craft_hole.is_stroke_open() or panel._craft_stroke_open or live.craft_hole.get_height_mm(tile.x, tile.y) != height_before:
		_fail("Category switch did not roll back the unfinished stroke")
		return
	if live.craft_hole.undo_count() != history_before:
		_fail("Category switch added an unfinished edit to history")
		return
	panel._select_category(&"surfaces")
	await process_frame
	await process_frame
	live._relayout()
	var frame_rect: Rect2 = live._panel_frame.get_global_rect()
	for control: Control in [panel._close, panel._finalize_button, panel._category_row, panel._history_row]:
		if not frame_rect.encloses(control.get_global_rect()):
			_fail("Design navigation escaped its panel: " + str(control.get_global_rect()))
			return
	if panel._scroll.size.y < shell.ctx.touch_min():
		_fail("Design navigation left no usable material palette")
		return
	# Brush presets change the authoritative footprint, not just its highlight.
	panel._select_category(&"terrain")
	panel._select_mode(&"raise")
	panel._select_brush_radius(0)
	var neighbour_before: int = live.craft_hole.get_height_mm(tile.x + 2, tile.y)
	if not panel.craft_at_tile(tile.x, tile.y):
		_fail("Detail sculpt brush failed")
		return
	if live.craft_hole.get_height_mm(tile.x + 2, tile.y) != neighbour_before:
		_fail("Detail brush changed ground outside its footprint")
		return
	panel._craft_undo()
	panel._select_brush_radius(3)
	var outside_before: int = live.craft_hole.get_height_mm(tile.x + 4, tile.y)
	if not panel.craft_at_tile(tile.x, tile.y):
		_fail("Wide sculpt brush failed")
		return
	if live.craft_hole.get_height_mm(tile.x + 2, tile.y) != neighbour_before + 1000 or live.craft_hole.get_height_mm(tile.x + 4, tile.y) != outside_before:
		_fail("Wide brush does not match its canonical footprint")
		return
	panel._brush_tile = tile
	panel._refresh_brush_preview()
	if panel._brush_preview == null or panel._brush_preview.mesh == null or not panel._brush_preview.visible:
		_fail("Live brush highlight missing")
		return
	var vertices: PackedVector3Array = panel._brush_preview.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if vertices.size() != 29 * 6:
		_fail("Wide brush highlight disagrees with the 29-tile canonical disc")
		return
	panel._craft_undo()
	if live.craft_hole.get_height_mm(tile.x, tile.y) != height_before or live.craft_hole.get_height_mm(tile.x + 2, tile.y) != neighbour_before:
		_fail("Sculpt undo did not restore exact terrain")
		return
	panel._select_category(&"markers")
	if panel._brush_tools.visible or panel._brush_hint.visible or (panel._brush_preview != null and panel._brush_preview.visible):
		_fail("Marker tools retained a paint/sculpt brush")
		return
	panel._select_brush_radius(1)
	panel._select_category(&"surfaces")
	live.one_hole.craft_mode = &"surface"
	live.one_hole.craft_surface = MHCraftHole.Surface.PATH
	if not live.one_hole.craft_at_tile(tile.x, tile.y):
		_fail("Canonical craft refused a path edit")
		return
	if live.editor.splat.get_weight(sample_x, sample_y, MHSplatMap.Layer.PATH) != 255:
		_fail("Craft path did not reach shared terrain")
		return
	# A craft area may be valid RHI geometry but cross an unowned property
	# parcel. Build readiness must surface this BEFORE the player clicks Build.
	# Tile (0,5) falls on unowned parcel 4 in the starter property map.
	live.one_hole.craft_surface = MHCraftHole.Surface.WATER
	if not live.one_hole.craft_at_tile(0, 5):
		_fail("Could not paint test area crossing unowned land")
		return
	if not live.one_hole._validation_hint.text.contains("do not own"):
		_fail("Build readiness did not explain unowned land: " + live.one_hole._validation_hint.text)
		return
	live.one_hole._craft_undo()
	live.one_hole.craft_surface = MHCraftHole.Surface.PATH
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
	var radius_before_repair: int = MHCraftConvert.green_radius_yd(live.craft_hole)
	live.one_hole._repair_hole_markers()
	var radius_after_repair: int = MHCraftConvert.green_radius_yd(live.craft_hole)
	if radius_before_repair >= 5 and radius_after_repair != radius_before_repair:
		_fail("Repair expanded an already valid green from " + str(radius_before_repair) +
			" to " + str(radius_after_repair) + " yards")
		return
	var problems: Array = MHCraftConvert.problems(live.craft_hole)
	if not problems.is_empty():
		_fail("Marker repair did not make the hole playable: " + str(problems))
		return
	var craft_rating_hole: Dictionary = live.canonical_craft_draft()
	if craft_rating_hole.is_empty():
		_fail("Valid craft did not produce a rating layout")
		return
	var owned_check: MHSaveResult = MHCourseLayout.encode([craft_rating_hole],
		live.document["course"] as Dictionary, [MHOneHolePanel.ORIGIN])
	if not owned_check.is_ok():
		_fail("Repaired green crosses parcel boundary: " + owned_check.message +
			" | green radius=" + str(MHCraftConvert.green_radius_yd(live.craft_hole)) +
			" | green centre=" + str(craft_rating_hole.get("green", [])))
		return
	var parsed_hole: MHRHole = MHRHole.from_def(craft_rating_hole)
	if not parsed_hole.valid:
		_fail("Craft validator disagrees with rating geometry: " + str(parsed_hole.reasons) +
			" | green radius=" + str(parsed_hole.gr) + " yd | length=" + str(parsed_hole.L) + " yd")
		return
	live.one_hole._finalize()
	if live.session.hole_definitions().is_empty():
		var failed: Dictionary = MHRatingEngine.rate_hole(craft_rating_hole,
			{"save_secret": live.session.save_secret, "rating_epoch": live.session.rating_epoch})
		_fail("Build hole did not finalize: " + live.one_hole._info.text +
			" | " + live.one_hole._validation_hint.text +
			" | rating reasons=" + str(failed.get("reasons", [])) +
			" | rating valid=" + str(failed.get("valid", false)))
		return
	if live.session.practice == null:
		_fail("Finalization did not create a practice round")
		return
	if live.one_hole._category_row.visible or live.one_hole._history_row.visible or live.one_hole._finalize_button.visible:
		_fail("Craft-only menu still visible on finalized practice hole")
		return
	# Read the actual disk checkpoint, including its paired ledger and terrain.
	live.session.clock.pause()
	live.one_hole._shoot()
	if live.session.practice.strokes < 1:
		_fail("Practice did not play a shot before saving")
		return
	if not live.save_now():
		_fail("Could not save built hole/practice checkpoint")
		return
	var loaded: MHSaveResult = live.store.load_slot(0)
	if not loaded.is_ok():
		_fail("Could not reload saved checkpoint: " + loaded.message)
		return
	var saved: MHLoadedSave = loaded.value as MHLoadedSave
	var ledger: MHSaveResult = MHSessionSave.load_ledger(saved.data, live.ledger_dir)
	if not ledger.is_ok():
		_fail("Could not reload checkpoint ledger: " + ledger.message)
		return
	var restored: MHSaveResult = MHSessionSave.restore(saved.data, ledger.value as MHTokenLedger)
	var terrain: MHTerrainSave.LoadResult = MHTerrainSave.decode(saved.blob)
	if not restored.is_ok() or terrain.error != OK:
		_fail("Saved session/terrain did not restore")
		return
	var resumed: MHGameSession = restored.value as MHGameSession
	if resumed.hole_definitions() != live.session.hole_definitions() or resumed.practice == null or resumed.practice.to_dict() != live.session.practice.to_dict():
		_fail("Reload changed exact hole or practice state")
		return
	if not terrain.grid.equals(live.editor.grid) or terrain.splat.get_weight(sample_x, sample_y, MHSplatMap.Layer.PATH) != 255:
		_fail("Reload changed shared terrain")
		return
	print("LIVE_UI_PROBE PASS: landscape layout, navigation, brushes, sculpt-only grid, marker repair, build, practice and disk reload")
	quit(0)
