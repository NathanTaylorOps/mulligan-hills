class_name MHTerrainSave
extends RefCounted
## Compact versioned binary with checksum, optional zstd compression and crash-safe write.
##
## File layout (all little endian):
##   0  4  magic "MHTS"
##   4  2  format version (2 current; 1 still loads)
##   6  2  flags (1 = body is zstd compressed, 0 = stored uncompressed; used by golden fixtures)
##   8  4  body size as stored (compressed size when flags = 1)
##  12  4  uncompressed body size
##  16  4  CRC32 over bytes [0..15] followed by the stored body
##  20  .. body
## Uncompressed body, version 2 (splat = 11 layers, see MHSplatMap):
##   0  4 cells_x   4  4 cells_y   8  4 cell_size_mm   12 4 FNV-1a height hash   16 4 FNV-1a splat hash
##  20  2*n int16 heights (n = (cells_x+1)*(cells_y+1)), then 11*n splat bytes (texel-major, layer order
##  rough, fairway, first_cut, green, fringe, tee, bunker_sand, water, path, waste, dirt)
## Uncompressed body, version 1 (legacy, read only): 16 byte inner header (no splat hash), heights,
##  then 4*n splat bytes RGBA = fairway, rough, sand, green. Loaded by mapping to fairway, rough,
##  bunker_sand, green; every other layer is 0.
##
## Crash-safe write (write_atomic):
##   1. write "<path>.tmp", flush, close.
##   2. read "<path>.tmp" back, require byte equality and a full decode (size, CRC32, height hash, splat hash).
##      On mismatch delete the tmp and return an error; the main file is untouched.
##   3. if "<path>" exists and decodes cleanly, move it to "<path>.bak" (replacing an older .bak).
##      A main file that does not decode is NOT promoted to .bak, so a good .bak is never overwritten by garbage.
##   4. rename tmp to "<path>" (the destination does not exist at this point, so no overwrite semantics are needed).
## load_with_fallback tries "<path>", then a complete valid "<path>.tmp" (a verified save killed before rename),
## then "<path>.bak". FileAccess.flush() is not a guaranteed fsync (Godot has no fsync call that we know of),
## so power-loss durability is NOT proven; process-kill safety is what is designed for.
##
## Kill-during-save test hooks: set fault_point / fault_action (statics) or call fault_from_cmdline().
## See game/terrain/demo/save_probe.gd and docs/phase0/terrain.md.

const MAGIC_0: int = 0x4D # M
const MAGIC_1: int = 0x48 # H
const MAGIC_2: int = 0x54 # T
const MAGIC_3: int = 0x53 # S
const VERSION: int = 2
const VERSION_LEGACY: int = 1
const HEADER_SIZE: int = 20
const INNER_HEADER: int = 20
const INNER_HEADER_V1: int = 16
const FLAG_ZSTD: int = 1
const MAX_CELLS: int = 4096

enum FaultPoint { NONE = 0, MID_TEMP_WRITE = 1, AFTER_TEMP_WRITE = 2, AFTER_BAK_ROTATE = 3 }
enum FaultAction { RETURN_ERROR = 0, KILL_PROCESS = 1 }

static var fault_point: int = FaultPoint.NONE
static var fault_action: int = FaultAction.RETURN_ERROR
static var _crc_table: PackedInt32Array = PackedInt32Array()


class LoadResult extends RefCounted:
	var error: int = OK
	var message: String = ""
	var grid: MHHeightGrid = null
	var splat: MHSplatMap = null
	## Format version of the file that was read (1 or 2), 0 if none.
	var version: int = 0
	## load_with_fallback only: "main", "tmp" or "bak" (which file the data came from), "" on failure.
	var source: String = ""
	## load_with_fallback only: true when the main file was not the source.
	var recovered: bool = false


## Reads "--mh-fault=mid|after|bak" and "--mh-fault-kill" from user args (after "--" on the command line).
static func fault_from_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--mh-fault=mid":
			fault_point = FaultPoint.MID_TEMP_WRITE
		elif a == "--mh-fault=after":
			fault_point = FaultPoint.AFTER_TEMP_WRITE
		elif a == "--mh-fault=bak":
			fault_point = FaultPoint.AFTER_BAK_ROTATE
		elif a == "--mh-fault-kill":
			fault_action = FaultAction.KILL_PROCESS


static func crc32(data: PackedByteArray) -> int:
	if _crc_table.size() != 256:
		var t := PackedInt32Array()
		t.resize(256)
		for i in range(256):
			var c: int = i
			for _k in range(8):
				if (c & 1) != 0:
					c = 0xEDB88320 ^ (c >> 1)
				else:
					c = c >> 1
			t[i] = c
		_crc_table = t
	var crc: int = 0xFFFFFFFF
	for i in range(data.size()):
		crc = (_crc_table[(crc ^ data[i]) & 0xFF] & 0xFFFFFFFF) ^ (crc >> 8)
	return crc ^ 0xFFFFFFFF


static func encode(grid: MHHeightGrid, splat: MHSplatMap, compress: bool = true) -> PackedByteArray:
	var n: int = grid.sample_count()
	assert(splat.bytes.size() == n * MHSplatMap.LAYER_COUNT)
	var inner := PackedByteArray()
	inner.resize(INNER_HEADER + n * 2)
	inner.encode_u32(0, grid.cells_x)
	inner.encode_u32(4, grid.cells_y)
	inner.encode_u32(8, grid.cell_size_mm)
	inner.encode_u32(12, grid.hash_fnv1a())
	inner.encode_u32(16, splat.hash_fnv1a())
	for i in range(n):
		inner.encode_s16(INNER_HEADER + i * 2, grid.heights[i])
	inner.append_array(splat.bytes)
	return _wrap(VERSION, inner, compress)


## Writes a version 1 file (4 splat layers RGBA). Only for tests and migration fixtures.
static func encode_legacy_v1(grid: MHHeightGrid, rgba: PackedByteArray, compress: bool = true) -> PackedByteArray:
	var n: int = grid.sample_count()
	assert(rgba.size() == n * 4)
	var inner := PackedByteArray()
	inner.resize(INNER_HEADER_V1 + n * 2)
	inner.encode_u32(0, grid.cells_x)
	inner.encode_u32(4, grid.cells_y)
	inner.encode_u32(8, grid.cell_size_mm)
	inner.encode_u32(12, grid.hash_fnv1a())
	for i in range(n):
		inner.encode_s16(INNER_HEADER_V1 + i * 2, grid.heights[i])
	inner.append_array(rgba)
	return _wrap(VERSION_LEGACY, inner, compress)


static func _wrap(version: int, inner: PackedByteArray, compress: bool) -> PackedByteArray:
	var body: PackedByteArray = inner
	var flags: int = 0
	if compress:
		body = inner.compress(FileAccess.COMPRESSION_ZSTD)
		flags = FLAG_ZSTD
	var head := PackedByteArray()
	head.resize(HEADER_SIZE)
	head.encode_u8(0, MAGIC_0)
	head.encode_u8(1, MAGIC_1)
	head.encode_u8(2, MAGIC_2)
	head.encode_u8(3, MAGIC_3)
	head.encode_u16(4, version)
	head.encode_u16(6, flags)
	head.encode_u32(8, body.size())
	head.encode_u32(12, inner.size())
	var covered := PackedByteArray()
	covered.append_array(head.slice(0, 16))
	covered.append_array(body)
	head.encode_u32(16, crc32(covered))
	var out := PackedByteArray()
	out.append_array(head)
	out.append_array(body)
	return out


static func _fail(code: int, msg: String) -> LoadResult:
	var r := LoadResult.new()
	r.error = code
	r.message = msg
	return r


static func decode(data: PackedByteArray) -> LoadResult:
	if data.size() < HEADER_SIZE:
		return _fail(ERR_FILE_CORRUPT, "too short")
	if data[0] != MAGIC_0 or data[1] != MAGIC_1 or data[2] != MAGIC_2 or data[3] != MAGIC_3:
		return _fail(ERR_FILE_UNRECOGNIZED, "bad magic")
	var version: int = data.decode_u16(4)
	if version != VERSION and version != VERSION_LEGACY:
		return _fail(ERR_FILE_UNRECOGNIZED, "unsupported version %d" % version)
	var flags: int = data.decode_u16(6)
	var comp_size: int = data.decode_u32(8)
	var inner_size: int = data.decode_u32(12)
	var crc_stored: int = data.decode_u32(16)
	if comp_size != data.size() - HEADER_SIZE:
		return _fail(ERR_FILE_CORRUPT, "size mismatch (truncated or extended)")
	var covered := PackedByteArray()
	covered.append_array(data.slice(0, 16))
	covered.append_array(data.slice(HEADER_SIZE))
	if crc32(covered) != crc_stored:
		return _fail(ERR_FILE_CORRUPT, "checksum mismatch")
	if flags != FLAG_ZSTD and flags != 0:
		return _fail(ERR_FILE_UNRECOGNIZED, "unknown flags")
	var inner_header: int = INNER_HEADER if version == VERSION else INNER_HEADER_V1
	if inner_size < inner_header or inner_size > 268435456:
		return _fail(ERR_FILE_CORRUPT, "bad body size")
	var inner: PackedByteArray
	if flags == FLAG_ZSTD:
		inner = data.slice(HEADER_SIZE).decompress(inner_size, FileAccess.COMPRESSION_ZSTD)
	else:
		if comp_size != inner_size:
			return _fail(ERR_FILE_CORRUPT, "stored body size mismatch")
		inner = data.slice(HEADER_SIZE)
	if inner.size() != inner_size:
		return _fail(ERR_FILE_CORRUPT, "decompress failed")
	var cx: int = inner.decode_u32(0)
	var cy: int = inner.decode_u32(4)
	var cs: int = inner.decode_u32(8)
	var hash_stored: int = inner.decode_u32(12)
	if cx < 1 or cy < 1 or cx > MAX_CELLS or cy > MAX_CELLS or cs < 1:
		return _fail(ERR_FILE_CORRUPT, "bad dimensions")
	var n: int = (cx + 1) * (cy + 1)
	var splat_stride: int = MHSplatMap.LAYER_COUNT if version == VERSION else 4
	if inner_size != inner_header + n * (2 + splat_stride):
		return _fail(ERR_FILE_CORRUPT, "body size does not match dimensions")
	var grid := MHHeightGrid.new(cx, cy, cs)
	for i in range(n):
		grid.heights[i] = inner.decode_s16(inner_header + i * 2)
	if grid.hash_fnv1a() != hash_stored:
		return _fail(ERR_FILE_CORRUPT, "height hash mismatch")
	var splat_bytes: PackedByteArray = inner.slice(inner_header + n * 2)
	var splat: MHSplatMap
	if version == VERSION:
		splat = MHSplatMap.new(cx + 1, cy + 1)
		splat.bytes = splat_bytes
		if splat.hash_fnv1a() != inner.decode_u32(16):
			return _fail(ERR_FILE_CORRUPT, "splat hash mismatch")
	else:
		splat = MHSplatMap.from_legacy_rgba(cx + 1, cy + 1, splat_bytes)
	var r := LoadResult.new()
	r.grid = grid
	r.splat = splat
	r.version = version
	return r


static func _do_fault(point: int, label: String) -> int:
	if fault_point != point:
		return OK
	push_warning("MHTerrainSave: fault injected at " + label)
	if fault_action == FaultAction.KILL_PROCESS:
		OS.kill(OS.get_process_id())
	return ERR_CANT_CREATE


static func temp_path(path: String) -> String:
	return path + ".tmp"


static func save_to_file(path: String, grid: MHHeightGrid, splat: MHSplatMap) -> int:
	return write_atomic(path, encode(grid, splat))


static func bak_path(path: String) -> String:
	return path + ".bak"


static func _read_all(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return data


static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var dir: DirAccess = DirAccess.open(path.get_base_dir())
		if dir != null:
			dir.remove(path.get_file())


## Crash-safe write, see the header comment. Returns OK only when the new file is in place.
@warning_ignore("integer_division")
static func write_atomic(path: String, data: PackedByteArray) -> int:
	var tmp: String = temp_path(path)
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
	# Read back and verify before anything else is touched.
	var back: PackedByteArray = _read_all(tmp)
	if back != data or decode(back).error != OK:
		_remove_file(tmp)
		return ERR_FILE_CORRUPT
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
	var bak: String = bak_path(path)
	if FileAccess.file_exists(path):
		if decode(_read_all(path)).error == OK:
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
			# Corrupt main: keep the existing .bak, just drop the bad main.
			var derr: int = dir.remove(path.get_file())
			if derr != OK:
				return derr
	return dir.rename(tmp.get_file(), path.get_file())


static func load_from_file(path: String) -> LoadResult:
	if not FileAccess.file_exists(path):
		return _fail(ERR_FILE_NOT_FOUND, "no file")
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return _fail(FileAccess.get_open_error(), "open failed")
	var data: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return decode(data)


## Loads "<path>"; if it is missing or fails verification, tries a complete valid "<path>.tmp", then
## "<path>.bak". result.source says which file was used, result.recovered is true for tmp/bak.
## If everything fails the error of the main file is returned (ERR_FILE_NOT_FOUND if nothing exists at all).
static func load_with_fallback(path: String) -> LoadResult:
	var first: LoadResult = load_from_file(path)
	if first.error == OK:
		first.source = "main"
		return first
	var second: LoadResult = load_from_file(temp_path(path))
	if second.error == OK:
		second.source = "tmp"
		second.recovered = true
		push_warning("MHTerrainSave: main file unusable (" + first.message + "), recovered from .tmp")
		return second
	var third: LoadResult = load_from_file(bak_path(path))
	if third.error == OK:
		third.source = "bak"
		third.recovered = true
		push_warning("MHTerrainSave: main file unusable (" + first.message + "), recovered from .bak")
		return third
	return first


## Deletes a leftover "<path>.tmp" (from an interrupted save). Never touches "<path>".
static func cleanup_stale_temp(path: String) -> void:
	var tmp: String = temp_path(path)
	if FileAccess.file_exists(tmp):
		var dir: DirAccess = DirAccess.open(path.get_base_dir())
		if dir != null:
			dir.remove(tmp.get_file())
