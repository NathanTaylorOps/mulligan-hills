class_name MHGate0TerrainApi
extends RefCounted
## The ONLY place in game/gate0 that touches the terrain workstream's API (MHHeightGrid, MHTerrainEditor,
## MHTerrainSave, MHTerrainChunks, MHDirtyTracker). The terrain owner is still changing splat layers
## and save robustness, so if their signatures move, fix this file only.


static func make_editor(cells_x: int, cells_y: int) -> MHTerrainEditor:
	var grid: MHHeightGrid = MHHeightGrid.new(cells_x, cells_y, 1000)
	return MHTerrainEditor.new(grid)


## Builds and attaches the chunked terrain renderer under `parent`.
static func make_chunks(parent: Node, editor: MHTerrainEditor) -> MHTerrainChunks:
	var chunks: MHTerrainChunks = MHTerrainChunks.new()
	parent.add_child(chunks)
	chunks.setup(editor.grid, editor.splat, 32)
	return chunks


## Upload dirty chunks once per frame. Returns the number of chunks uploaded.
static func flush(chunks: MHTerrainChunks, editor: MHTerrainEditor) -> int:
	if chunks == null:
		return 0
	chunks.flush(editor.dirty)
	return chunks.last_flush_chunks


static func mark_all_dirty(editor: MHTerrainEditor) -> void:
	editor.mark_all_dirty()


static func content_hash(editor: MHTerrainEditor) -> int:
	return editor.grid.hash_fnv1a()


static func snapshot(editor: MHTerrainEditor) -> MHHeightGrid:
	return editor.grid.duplicate_grid()


static func grid_equals(a: MHHeightGrid, b: MHHeightGrid) -> bool:
	return a != null and a.equals(b)


static func undo_count(editor: MHTerrainEditor) -> int:
	return editor.undo_stack.undo_count()


static func redo_count(editor: MHTerrainEditor) -> int:
	return editor.undo_stack.redo_count()


static func heights_in_int16(grid: MHHeightGrid) -> bool:
	for i: int in range(grid.heights.size()):
		var h: int = grid.heights[i]
		if h < MHHeightGrid.MIN_H_MM or h > MHHeightGrid.MAX_H_MM:
			return false
	return true


static func height_at(grid: MHHeightGrid, x: int, y: int) -> int:
	return grid.get_h_clamped(x, y)


static func set_height(grid: MHHeightGrid, x: int, y: int, mm: int) -> void:
	grid.set_h(x, y, mm)


## Result: {ok: bool, error: int, message: String, hash: int, grid: MHHeightGrid}.
static func load_file(path: String) -> Dictionary:
	var r: MHTerrainSave.LoadResult = MHTerrainSave.load_from_file(path)
	var out: Dictionary = {"ok": r.error == OK, "error": r.error, "message": r.message, "hash": 0, "grid": null}
	if r.error == OK and r.grid != null:
		out["hash"] = r.grid.hash_fnv1a()
		out["grid"] = r.grid
	return out


## Decode already-read bytes (used to validate a file without going through a path).
static func decode_bytes(data: PackedByteArray) -> Dictionary:
	var r: MHTerrainSave.LoadResult = MHTerrainSave.decode(data)
	var out: Dictionary = {"ok": r.error == OK, "error": r.error, "message": r.message, "hash": 0, "grid": null}
	if r.error == OK and r.grid != null:
		out["hash"] = r.grid.hash_fnv1a()
		out["grid"] = r.grid
	return out


static func encode(editor: MHTerrainEditor) -> PackedByteArray:
	return MHTerrainSave.encode(editor.grid, editor.splat)


static func save_file(path: String, editor: MHTerrainEditor) -> int:
	return MHTerrainSave.save_to_file(path, editor.grid, editor.splat)


## Atomic byte write (tmp + rename), used for the .bak copy.
static func write_atomic(path: String, data: PackedByteArray) -> int:
	return MHTerrainSave.write_atomic(path, data)


static func cleanup_temp(path: String) -> void:
	MHTerrainSave.cleanup_stale_temp(path)


## Kill/fault hooks. mode: 0 none, 1 mid temp write, 2 after temp write before rename. kill: true = OS.kill.
static func set_fault(mode: int, kill: bool) -> void:
	MHTerrainSave.fault_point = mode
	MHTerrainSave.fault_action = MHTerrainSave.FaultAction.KILL_PROCESS if kill else MHTerrainSave.FaultAction.RETURN_ERROR


static func clear_fault() -> void:
	set_fault(0, false)


static func fill_noise(editor: MHTerrainEditor, seed_value: int, amplitude_mm: int) -> void:
	editor.grid.fill_lcg_noise(seed_value, amplitude_mm)
