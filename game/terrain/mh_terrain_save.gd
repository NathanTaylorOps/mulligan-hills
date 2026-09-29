class_name MHTerrainSave
extends RefCounted
## Compact versioned binary with checksum, zstd compression and atomic write.
##
## File layout (all little endian):
##   0  4  magic "MHTS"
##   4  2  format version (1)
##   6  2  flags (1 = body is zstd compressed)
##   8  4  compressed body size
##  12  4  uncompressed body size
##  16  4  CRC32 over bytes [0..15] followed by the compressed body
##  20  .. compressed body
## Uncompressed body:
##   0  4 cells_x   4  4 cells_y   8  4 cell_size_mm   12 4 FNV-1a height hash
##  16  2*n int16 heights (n = (cells_x+1)*(cells_y+1)), then 4*n splat bytes RGBA
##
## Atomic write: write "<path>.tmp", flush, close, then rename over "<path>". If the process dies before
## the rename, "<path>" still holds the previous complete file. NOTE: FileAccess.flush() is not a
## guaranteed fsync, so power-loss durability is NOT proven; process-kill safety is what is designed for.
##
## Kill-during-save test hooks: set fault_point / fault_action (statics) or call fault_from_cmdline().
## See game/terrain/demo/save_probe.gd and docs/phase0/terrain.md.

const MAGIC_0: int = 0x4D # M
const MAGIC_1: int = 0x48 # H
const MAGIC_2: int = 0x54 # T
const MAGIC_3: int = 0x53 # S
const VERSION: int = 1
const HEADER_SIZE: int = 20
const INNER_HEADER: int = 16
const MAX_CELLS: int = 4096

enum FaultPoint { NONE = 0, MID_TEMP_WRITE = 1, AFTER_TEMP_WRITE = 2 }
enum FaultAction { RETURN_ERROR = 0, KILL_PROCESS = 1 }

static var fault_point: int = FaultPoint.NONE
static var fault_action: int = FaultAction.RETURN_ERROR
static var _crc_table: PackedInt32Array = PackedInt32Array()


class LoadResult extends RefCounted:
	var error: int = OK
	var message: String = ""
	var grid: MHHeightGrid = null
	var splat: MHSplatMap = null


## Reads "--mh-fault=mid|after" and "--mh-fault-kill" from user args (after "--" on the command line).
static func fault_from_cmdline() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--mh-fault=mid":
			fault_point = FaultPoint.MID_TEMP_WRITE
		elif a == "--mh-fault=after":
			fault_point = FaultPoint.AFTER_TEMP_WRITE
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


static func encode(grid: MHHeightGrid, splat: MHSplatMap) -> PackedByteArray:
	var n: int = grid.sample_count()
	assert(splat.bytes.size() == n * 4)
	var inner := PackedByteArray()
	inner.resize(INNER_HEADER + n * 2)
	inner.encode_u32(0, grid.cells_x)
	inner.encode_u32(4, grid.cells_y)
	inner.encode_u32(8, grid.cell_size_mm)
	inner.encode_u32(12, grid.hash_fnv1a())
	for i in range(n):
		inner.encode_s16(INNER_HEADER + i * 2, grid.heights[i])
	inner.append_array(splat.bytes)
	var comp: PackedByteArray = inner.compress(FileAccess.COMPRESSION_ZSTD)
	var head := PackedByteArray()
	head.resize(HEADER_SIZE)
	head.encode_u8(0, MAGIC_0)
	head.encode_u8(1, MAGIC_1)
	head.encode_u8(2, MAGIC_2)
	head.encode_u8(3, MAGIC_3)
	head.encode_u16(4, VERSION)
	head.encode_u16(6, 1)
	head.encode_u32(8, comp.size())
	head.encode_u32(12, inner.size())
	var covered := PackedByteArray()
	covered.append_array(head.slice(0, 16))
	covered.append_array(comp)
	head.encode_u32(16, crc32(covered))
	var out := PackedByteArray()
	out.append_array(head)
	out.append_array(comp)
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
	if version != VERSION:
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
	if flags != 1:
		return _fail(ERR_FILE_UNRECOGNIZED, "unknown flags")
	if inner_size < INNER_HEADER or inner_size > 268435456:
		return _fail(ERR_FILE_CORRUPT, "bad body size")
	var inner: PackedByteArray = data.slice(HEADER_SIZE).decompress(inner_size, FileAccess.COMPRESSION_ZSTD)
	if inner.size() != inner_size:
		return _fail(ERR_FILE_CORRUPT, "decompress failed")
	var cx: int = inner.decode_u32(0)
	var cy: int = inner.decode_u32(4)
	var cs: int = inner.decode_u32(8)
	var hash_stored: int = inner.decode_u32(12)
	if cx < 1 or cy < 1 or cx > MAX_CELLS or cy > MAX_CELLS or cs < 1:
		return _fail(ERR_FILE_CORRUPT, "bad dimensions")
	var n: int = (cx + 1) * (cy + 1)
	if inner_size != INNER_HEADER + n * 6:
		return _fail(ERR_FILE_CORRUPT, "body size does not match dimensions")
	var grid := MHHeightGrid.new(cx, cy, cs)
	for i in range(n):
		grid.heights[i] = inner.decode_s16(INNER_HEADER + i * 2)
	if grid.hash_fnv1a() != hash_stored:
		return _fail(ERR_FILE_CORRUPT, "height hash mismatch")
	var splat := MHSplatMap.new(cx + 1, cy + 1)
	splat.bytes = inner.slice(INNER_HEADER + n * 2)
	var r := LoadResult.new()
	r.grid = grid
	r.splat = splat
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
	var e_after: int = _do_fault(FaultPoint.AFTER_TEMP_WRITE, "after temp write, before rename")
	if e_after != OK:
		return e_after
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		return DirAccess.get_open_error()
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


## Deletes a leftover "<path>.tmp" (from an interrupted save). Never touches "<path>".
static func cleanup_stale_temp(path: String) -> void:
	var tmp: String = temp_path(path)
	if FileAccess.file_exists(tmp):
		var dir: DirAccess = DirAccess.open(path.get_base_dir())
		if dir != null:
			dir.remove(tmp.get_file())
