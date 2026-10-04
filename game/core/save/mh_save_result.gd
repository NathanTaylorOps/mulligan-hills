class_name MHSaveResult
extends RefCounted
## Result of a save-system operation: a code, a human readable message and an optional value.
## Named MHSaveResult (not MHResult) so it cannot clash with the platform layer's own result type.

enum Code {
	OK = 0,
	NOT_FOUND = 1,
	IO_ERROR = 2,
	PARSE_ERROR = 3,
	BAD_SCHEMA = 4,
	CHECKSUM_MISMATCH = 5,
	NEEDS_APP_UPDATE = 6,
	MIGRATION_FAILED = 7,
	BLOB_MISSING = 8,
	BLOB_CORRUPT = 9,
	PAIR_MISMATCH = 10,
	VERIFY_FAILED = 11,
	INVALID_ARGUMENT = 12,
	SLOT_OCCUPIED = 13,
}

var code: int = Code.OK
var message: String = ""
var value: Variant = null


static func success(v: Variant = null) -> MHSaveResult:
	var r := MHSaveResult.new()
	r.code = Code.OK
	r.value = v
	return r


static func failure(c: int, msg: String) -> MHSaveResult:
	var r := MHSaveResult.new()
	r.code = c
	r.message = msg
	return r


func is_ok() -> bool:
	return code == Code.OK
