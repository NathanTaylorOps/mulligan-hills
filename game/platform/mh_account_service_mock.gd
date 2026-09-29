class_name MHAccountServiceMock
extends MHAccountService

var signed_in: bool = true
var delete_calls: int = 0

func is_signed_in() -> bool:
	return signed_in

func request_account_deletion() -> void:
	delete_calls += 1
	signed_in = false
	account_deleted.emit(true, "mock")
