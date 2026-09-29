class_name MHGate0SaveHarness
extends RefCounted
## Kill-during-save harness (Gate 0 item 10) built on MHTerrainSave's atomic writer.
## Every save of generation g: log B, copy the current valid primary to "<primary>.bak" (atomic), write the
## new primary (atomic, tmp + rename), log D. The generation is stamped into two height samples so a load
## can tell which save it got. Recovery: primary if valid, else the .bak, else CORRUPT (or NONE if no files).

const CELLS_X: int = 600
const CELLS_Y: int = 400
const NOISE_SEED: int = 4242
const NOISE_AMPLITUDE_MM: int = 3000

var primary_path: String = "user://gate0_kill.mhts"
var log_path: String = "user://gate0_kill_log.txt"
var editor: MHTerrainEditor

## Fault injection for the buttons "kill mid write" / "kill after write". 0 none, 1 mid temp write,
## 2 after temp write before rename (MHTerrainSave.FaultPoint). fault_target: "primary" or "backup".
var fault_mode: int = 0
var fault_kill: bool = false
var fault_target: String = "primary"

var _cells_x: int
var _cells_y: int


func _init(p_primary: String = "user://gate0_kill.mhts", p_log: String = "user://gate0_kill_log.txt", p_cells_x: int = CELLS_X, p_cells_y: int = CELLS_Y) -> void:
	primary_path = p_primary
	log_path = p_log
	_cells_x = p_cells_x
	_cells_y = p_cells_y
	editor = MHGate0TerrainApi.make_editor(_cells_x, _cells_y)
	MHGate0TerrainApi.fill_noise(editor, NOISE_SEED, NOISE_AMPLITUDE_MM)


func backup_path() -> String:
	return primary_path + ".bak"


static func stamp_value(gen: int) -> int:
	return (gen % MHGate0KillLog.GEN_MOD) + 1


static func check_value(gen: int) -> int:
	return ((gen % MHGate0KillLog.GEN_MOD) * 7) % 30000


## Writes the generation into samples (0,0) and (1,0) of the grid.
static func stamp(p_editor: MHTerrainEditor, gen: int) -> void:
	MHGate0TerrainApi.set_height(p_editor.grid, 0, 0, stamp_value(gen))
	MHGate0TerrainApi.set_height(p_editor.grid, 1, 0, check_value(gen))


## Returns the generation stamped in `grid`, or -1 if the two stamp samples disagree.
static func read_stamp(grid: MHHeightGrid) -> int:
	var a: int = MHGate0TerrainApi.height_at(grid, 0, 0)
	var b: int = MHGate0TerrainApi.height_at(grid, 1, 0)
	var gen: int = a - 1
	if gen < 0 or gen >= MHGate0KillLog.GEN_MOD:
		return -1
	if check_value(gen) != b:
		return -1
	return gen


func append_log(line: String) -> void:
	var f: FileAccess = null
	if FileAccess.file_exists(log_path):
		f = FileAccess.open(log_path, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_line(line)
	f.flush()
	f.close()


func read_log_text() -> String:
	if not FileAccess.file_exists(log_path):
		return ""
	var f: FileAccess = FileAccess.open(log_path, FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t


func _read_bytes(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return b


## One full save of generation `gen`. Returns the error code of the primary write (OK = finished).
func save_generation(gen: int) -> int:
	append_log(MHGate0KillLog.begin_line(gen, Time.get_ticks_msec()))
	stamp(editor, gen)
	var new_bytes: PackedByteArray = MHGate0TerrainApi.encode(editor)
	var old_bytes: PackedByteArray = _read_bytes(primary_path)
	if old_bytes.size() > 0 and bool(MHGate0TerrainApi.decode_bytes(old_bytes)["ok"]):
		_arm(fault_target == "backup")
		var berr: int = MHGate0TerrainApi.write_atomic(backup_path(), old_bytes)
		MHGate0TerrainApi.clear_fault()
		if berr != OK:
			return berr
	_arm(fault_target != "backup")
	var err: int = MHGate0TerrainApi.write_atomic(primary_path, new_bytes)
	MHGate0TerrainApi.clear_fault()
	if err == OK:
		append_log(MHGate0KillLog.done_line(gen, Time.get_ticks_msec()))
	return err


func _arm(active: bool) -> void:
	if active and fault_mode != 0:
		MHGate0TerrainApi.set_fault(fault_mode, fault_kill)
	else:
		MHGate0TerrainApi.clear_fault()


## Next generation to save: one after the newest in the log (so a relaunch continues the count).
func next_generation() -> int:
	var p: Dictionary = MHGate0KillLog.parse(read_log_text())
	return maxi(int(p["last_begun"]), int(p["last_done"])) + 1


## Loads with recovery. Result: {outcome, gen, message, source, stale_tmp, judged_ok, log}
## outcome is OK, FALLBACK, CORRUPT or NONE. Logs a V line unless write_log is false.
func verify(write_log: bool = true) -> Dictionary:
	var stale: bool = FileAccess.file_exists(MHTerrainSave.temp_path(primary_path))
	var have_primary: bool = FileAccess.file_exists(primary_path)
	var have_bak: bool = FileAccess.file_exists(backup_path())
	var out: Dictionary = {"outcome": "NONE", "gen": -1, "message": "no save files yet", "source": "", "stale_tmp": stale}
	if have_primary or have_bak:
		var pr: Dictionary = MHGate0TerrainApi.load_file(primary_path) if have_primary else {"ok": false, "message": "primary missing", "grid": null}
		if bool(pr["ok"]):
			out["outcome"] = "OK"
			out["source"] = primary_path
			out["gen"] = read_stamp(pr["grid"] as MHHeightGrid)
			out["message"] = "primary valid"
		else:
			var br: Dictionary = MHGate0TerrainApi.load_file(backup_path()) if have_bak else {"ok": false, "message": "backup missing", "grid": null}
			if bool(br["ok"]):
				out["outcome"] = "FALLBACK"
				out["source"] = backup_path()
				out["gen"] = read_stamp(br["grid"] as MHHeightGrid)
				out["message"] = "primary unusable (%s), backup used" % str(pr["message"])
			else:
				out["outcome"] = "CORRUPT"
				out["message"] = "primary: %s; backup: %s" % [str(pr["message"]), str(br["message"])]
	MHGate0TerrainApi.cleanup_temp(primary_path)
	var parsed: Dictionary = MHGate0KillLog.parse(read_log_text())
	var oc: String = str(out["outcome"])
	var g: int = int(out["gen"])
	var ok: bool = MHGate0KillLog.judge(oc, g, parsed) and (g >= 0 or oc == "NONE" or oc == "CORRUPT")
	out["judged_ok"] = ok
	out["log"] = parsed
	if write_log:
		append_log(MHGate0KillLog.verify_line(oc, g, Time.get_ticks_msec()))
	return out


static func format_verify(d: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("RESULT: %s (%s)" % [d["outcome"], "log consistent" if bool(d["judged_ok"]) else "LOG MISMATCH or CORRUPT: this is a FAIL"])
	lines.append("generation found: %d" % int(d["gen"]))
	lines.append(str(d["message"]))
	lines.append("stale .tmp from an interrupted save present: %s (removed now)" % ("yes" if bool(d["stale_tmp"]) else "no"))
	var p: Dictionary = d["log"]
	lines.append("log says last finished save: %d, last started: %d" % [int(p["last_done"]), int(p["last_begun"])])
	return "\n".join(lines)
