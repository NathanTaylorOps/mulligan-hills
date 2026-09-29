class_name MHNotificationServiceMock
extends MHNotificationService

var permission: bool = false
var grant_on_request: bool = true
var scheduled: Dictionary = {}  # id -> {"title","body","delay"}

func is_supported() -> bool:
	return true

func has_permission() -> bool:
	return permission

func request_permission() -> void:
	permission = grant_on_request
	permission_result.emit(permission)

func schedule(id: int, title: String, body: String, delay_seconds: int) -> void:
	if not permission or delay_seconds < 1:
		return
	scheduled[id] = {"title": title, "body": body, "delay": delay_seconds}

func cancel(id: int) -> void:
	scheduled.erase(id)

func cancel_all() -> void:
	scheduled.clear()
