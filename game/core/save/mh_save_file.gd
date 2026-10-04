class_name MHSaveFile
extends RefCounted
## Generic crash-safe file helpers for the save system (same algorithm as MHTerrainSave.write_atomic,
## but format-agnostic: the caller passes a validator).
##
## write_atomic(path, data, validator):
##   1. write "<path>.tmp", flush, close.
##   2. read the tmp back: require byte equality and validator(bytes) == true. Otherwise delete tmp, return error;
##      the main file is untouched.
##   3. if "<path>" exists and validator accepts it, move it to "<path>.bak" (replacing an older .bak).
##      A main file that fails the validator is NOT promoted to .bak, so a good .bak is never overwritten by garbage.
##   4. rename tmp to "<path>".
## FileAccess.flush() is not a guaranteed fsync. Process-kill safety is designed for; power-loss durability is not proven.
##
## Fault injection (tests and the Gate 0 kill harness): set fault_point (and optionally fault_action) statics.

enum FaultPoint { NONE = 0, MID_TEMP_WRITE = 1, AFTER_TEMP_WRITE = 2, AFTER_BAK_ROTATE = 3 }
enum FaultAction { RETURN_ERROR = 0, KILL_PROCESS = 1 }

static var fault_point: int = FaultPoint.NONE
static var fault_action: int = FaultAction.RETURN_ERROR


static func tmp_path(path: String) -> String:
	return path + ".tmp"


static func bak_path(path: String) -> String:
	return path + ".bak"


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func read_all(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return data


static func remove(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	return dir.remove(path.get_file()) == OK


## Plain, non-atomic write. Only for tests that need to plant damaged files.
static func write_plain(path: String, data: PackedByteArray) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(data)
	f.flush()
	var err: int = f.get_error()
	f.close()
	return err


static func ensure_dir(dir_path: String) -> int:
	if DirAccess.dir_exists_absolute(dir_path):
		return OK
	return DirAccess.make_dir_recursive_absolute(dir_path)


static func _do_fault(point: int, label: String) -> int:
	if fault_point != point:
		return OK
	push_warning("MHSaveFile: fault injected at " + label)
	if fault_action == FaultAction.KILL_PROCESS:
		OS.kill(OS.get_process_id())
	return ERR_CANT_CREATE


@warning_ignore("integer_division")
static func write_atomic(path: String, data: PackedByteArray, validator: Callable = Callable()) -> int:
	var tmp: String = tmp_path(path)
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	if fault_point == FaultPoint.MID_TEMP_WRITE:
		f.store_buffer(data.slice(0, data.size() / 2))
		f.flush()
		var e_mid: int = _do_fault(FaultPoint.MID_TEMP_WRITE, "mid temp write")
		f.close()
		return e_mid
	f.store_buffer(data)
	f.flush()
	var werr: int = f.get_error()
	f.close()
	if werr != OK:
		return werr
	var e_after: int = _do_fault(FaultPoint.AFTER_TEMP_WRITE, "after temp write, before verify and rename")
	if e_after != OK:
		return e_after
	var back: PackedByteArray = read_all(tmp)
	if back != data or not _accepts(validator, back):
		remove(tmp)
		return ERR_FILE_CORRUPT
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	var bak: String = bak_path(path)
	if FileAccess.file_exists(path):
		if _accepts(validator, read_all(path)):
			if FileAccess.file_exists(bak):
				var rerr: int = dir.remove(bak.get_file())
				if rerr != OK:
					return rerr
			var merr: int = dir.rename(path.get_file(), bak.get_file())
			if merr != OK:
				return merr
			var e_bak: int = _do_fault(FaultPoint.AFTER_BAK_ROTATE, "after main moved to .bak, before tmp rename")
			if e_bak != OK:
				return e_bak
		else:
			var derr: int = dir.remove(path.get_file())
			if derr != OK:
				return derr
	return dir.rename(tmp.get_file(), path.get_file())


static func _accepts(validator: Callable, data: PackedByteArray) -> bool:
	if not validator.is_valid():
		return data.size() > 0
	return bool(validator.call(data))
