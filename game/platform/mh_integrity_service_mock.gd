class_name MHIntegrityServiceMock
extends MHIntegrityService
## Tests / desktop. Returns a fake token the server will (correctly) reject in production.

var supported: bool = true
var fail_next: bool = false
var request_count: int = 0
var last_request_hash: String = ""

func is_supported() -> bool:
	return supported

func prepare() -> void:
	prepared.emit(supported, "mock")

func request_token(request_hash: String) -> Dictionary:
	request_count += 1
	last_request_hash = request_hash
	if fail_next or not supported:
		fail_next = false
		return {"ok": false, "token": "", "error": "mock_failure"}
	return {"ok": true, "token": "MOCK_INTEGRITY_TOKEN", "error": ""}
