class_name MHGate0TerrainCheck
extends RefCounted
## Gate 0 item 5 scripted check, headless-capable: N strokes, N undos (hash must equal the start),
## N redos (hash must equal the stroked hash), a cancelled stroke (no residue), save then load
## (hash must equal), all heights in int16. Uses integer math only; the plan comes from an LCG.

const DEFAULT_STROKES: int = 50
const SEED: int = 20260929


static func lcg_next(state: int) -> int:
	return (state * 1103515245 + 12345) & 0x7FFFFFFF


## Deterministic plan. Each entry: {mode, radius, strength, points: PackedInt32Array [x0,y0,x1,y1,...]}.
## Points stay inside 0..cells. Same seed and size give the same plan on every platform.
static func make_plan(cells_x: int, cells_y: int, stroke_count: int, seed_value: int) -> Array:
	var state: int = seed_value & 0x7FFFFFFF
	var plan: Array = []
	var modes: Array[int] = [MHBrush.Mode.RAISE, MHBrush.Mode.LOWER, MHBrush.Mode.SMOOTH, MHBrush.Mode.RAISE, MHBrush.Mode.FLATTEN]
	for s: int in range(stroke_count):
		var pts: PackedInt32Array = PackedInt32Array()
		state = lcg_next(state)
		var x: int = (state >> 8) % (cells_x + 1)
		state = lcg_next(state)
		var y: int = (state >> 8) % (cells_y + 1)
		var n_points: int = 6 + s % 5
		for _k: int in range(n_points):
			pts.append(x)
			pts.append(y)
			state = lcg_next(state)
			x = clampi(x + ((state >> 8) % 41) - 20, 0, cells_x)
			state = lcg_next(state)
			y = clampi(y + ((state >> 8) % 41) - 20, 0, cells_y)
		var mode: int = modes[s % modes.size()]
		var strength: int = 150 if (mode == MHBrush.Mode.RAISE or mode == MHBrush.Mode.LOWER) else 500
		plan.append({"mode": mode, "radius": 6 + s % 7, "strength": strength, "points": pts})
	return plan


## Applies one planned stroke through the editor. Returns cells changed (0 = nothing to undo).
@warning_ignore("integer_division")
static func apply_stroke(editor: MHTerrainEditor, stroke: Dictionary) -> int:
	editor.set_brush(int(stroke["mode"]), int(stroke["radius"]), int(stroke["strength"]))
	var pts: PackedInt32Array = stroke["points"]
	if not editor.begin_stroke():
		return 0
	var n: int = pts.size() / 2
	for i: int in range(n):
		var x: int = pts[i * 2]
		var y: int = pts[i * 2 + 1]
		if i == 0:
			editor.apply_brush_at(x, y)
		else:
			editor.apply_brush_segment(pts[(i - 1) * 2], pts[(i - 1) * 2 + 1], x, y)
	return editor.end_stroke()


## Runs the whole check. `on_step` (optional Callable(String)) is called with a progress note.
## Returns a Dictionary with hashes (as ints), booleans, timings in ms and `pass`.
@warning_ignore("integer_division")
static func run(editor: MHTerrainEditor, stroke_count: int, save_path: String, on_step: Callable = Callable()) -> Dictionary:
	var out: Dictionary = {"cells_x": editor.grid.cells_x, "cells_y": editor.grid.cells_y, "strokes_planned": stroke_count}
	var plan: Array = make_plan(editor.grid.cells_x, editor.grid.cells_y, stroke_count, SEED)
	var start_snap: MHHeightGrid = MHGate0TerrainApi.snapshot(editor)
	var h0: int = MHGate0TerrainApi.content_hash(editor)
	out["hash_initial"] = h0

	_note(on_step, "applying %d strokes" % stroke_count)
	var t0: int = Time.get_ticks_usec()
	var committed: int = 0
	for s: Variant in plan:
		var stroke: Dictionary = s
		if apply_stroke(editor, stroke) > 0:
			committed += 1
	out["ms_strokes"] = (Time.get_ticks_usec() - t0) / 1000
	var h1: int = MHGate0TerrainApi.content_hash(editor)
	out["strokes_committed"] = committed
	out["hash_stroked"] = h1
	out["changed_by_strokes"] = h1 != h0
	var stroked_snap: MHHeightGrid = MHGate0TerrainApi.snapshot(editor)

	_note(on_step, "undo x%d" % committed)
	t0 = Time.get_ticks_usec()
	var undone: int = 0
	while editor.undo():
		undone += 1
	out["ms_undo"] = (Time.get_ticks_usec() - t0) / 1000
	out["undone"] = undone
	var h2: int = MHGate0TerrainApi.content_hash(editor)
	out["hash_after_undo"] = h2
	out["undo_restores_initial"] = h2 == h0 and MHGate0TerrainApi.grid_equals(editor.grid, start_snap)

	_note(on_step, "redo x%d" % undone)
	t0 = Time.get_ticks_usec()
	var redone: int = 0
	while editor.redo():
		redone += 1
	out["ms_redo"] = (Time.get_ticks_usec() - t0) / 1000
	out["redone"] = redone
	var h3: int = MHGate0TerrainApi.content_hash(editor)
	out["hash_after_redo"] = h3
	out["redo_restores_stroked"] = h3 == h1 and MHGate0TerrainApi.grid_equals(editor.grid, stroked_snap)

	# Cancelled stroke leaves no residue (models a second finger landing mid-stroke).
	editor.set_brush(MHBrush.Mode.RAISE, 10, 400)
	var began: bool = editor.begin_stroke()
	editor.apply_brush_at(editor.grid.cells_x / 2, editor.grid.cells_y / 2)
	editor.apply_brush_at(editor.grid.cells_x / 2 + 5, editor.grid.cells_y / 2)
	editor.cancel_stroke()
	var h4: int = MHGate0TerrainApi.content_hash(editor)
	out["cancel_leaves_no_residue"] = began and h4 == h3 and MHGate0TerrainApi.grid_equals(editor.grid, stroked_snap) and not editor.is_stroke_open()

	out["heights_in_int16"] = MHGate0TerrainApi.heights_in_int16(editor.grid)

	_note(on_step, "save and load")
	t0 = Time.get_ticks_usec()
	var serr: int = MHGate0TerrainApi.save_file(save_path, editor)
	out["ms_save"] = (Time.get_ticks_usec() - t0) / 1000
	out["save_error"] = serr
	t0 = Time.get_ticks_usec()
	var loaded: Dictionary = MHGate0TerrainApi.load_file(save_path)
	out["ms_load"] = (Time.get_ticks_usec() - t0) / 1000
	out["load_ok"] = bool(loaded["ok"])
	out["load_message"] = str(loaded["message"])
	out["hash_loaded"] = int(loaded["hash"])
	var lg: Variant = loaded["grid"]
	out["save_load_identical"] = serr == OK and bool(loaded["ok"]) and int(loaded["hash"]) == h3 \
		and lg != null and MHGate0TerrainApi.grid_equals(editor.grid, lg as MHHeightGrid)

	out["pass"] = judge(out)
	return out


static func _note(cb: Callable, text: String) -> void:
	if cb.is_valid():
		cb.call(text)


## Pure: all criteria in a result dictionary hold.
static func judge(d: Dictionary) -> bool:
	return bool(d.get("changed_by_strokes", false)) \
		and int(d.get("strokes_committed", 0)) > 0 \
		and int(d.get("undone", -1)) == int(d.get("strokes_committed", -2)) \
		and int(d.get("redone", -1)) == int(d.get("strokes_committed", -2)) \
		and bool(d.get("undo_restores_initial", false)) \
		and bool(d.get("redo_restores_stroked", false)) \
		and bool(d.get("cancel_leaves_no_residue", false)) \
		and bool(d.get("heights_in_int16", false)) \
		and bool(d.get("save_load_identical", false))


static func format_result(d: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("grid %d x %d cells, %d strokes planned, %d committed" % [d["cells_x"], d["cells_y"], d["strokes_planned"], d["strokes_committed"]])
	lines.append("hash initial   %d" % int(d["hash_initial"]))
	lines.append("hash stroked   %d  (changed: %s)" % [int(d["hash_stroked"]), _yn(d["changed_by_strokes"])])
	lines.append("hash after undo %d  = initial: %s  (%d undone, %d ms)" % [int(d["hash_after_undo"]), _yn(d["undo_restores_initial"]), int(d["undone"]), int(d["ms_undo"])])
	lines.append("hash after redo %d  = stroked: %s  (%d redone, %d ms)" % [int(d["hash_after_redo"]), _yn(d["redo_restores_stroked"]), int(d["redone"]), int(d["ms_redo"])])
	lines.append("cancelled stroke leaves no residue: %s" % _yn(d["cancel_leaves_no_residue"]))
	lines.append("all heights inside int16: %s" % _yn(d["heights_in_int16"]))
	lines.append("save (%d ms, err %d) then load (%d ms, ok %s): hash %d identical: %s" % [int(d["ms_save"]), int(d["save_error"]), int(d["ms_load"]), _yn(d["load_ok"]), int(d["hash_loaded"]), _yn(d["save_load_identical"])])
	lines.append("strokes took %d ms total" % int(d["ms_strokes"]))
	lines.append("RESULT: %s" % ("PASS" if bool(d["pass"]) else "FAIL"))
	return "\n".join(lines)


static func _yn(v: Variant) -> String:
	return "yes" if bool(v) else "NO"
