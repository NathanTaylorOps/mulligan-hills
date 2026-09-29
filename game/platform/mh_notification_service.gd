class_name MHNotificationService
extends Node
## INTERFACE for LOCAL notifications (e.g. "your course has finished a task"). No push, no server.
## The game must work fully when permission is denied.

signal permission_result(granted: bool)
signal notification_opened(id: int)

func is_supported() -> bool:
	return false

func has_permission() -> bool:
	return false

## Android 13+ needs the POST_NOTIFICATIONS runtime permission; iOS needs a system prompt. Ask in context, not at launch.
func request_permission() -> void:
	permission_result.emit(false)

## delay_seconds >= 1. Same id replaces an existing schedule.
func schedule(id: int, title: String, body: String, delay_seconds: int) -> void:
	pass

func cancel(id: int) -> void:
	pass

func cancel_all() -> void:
	pass
