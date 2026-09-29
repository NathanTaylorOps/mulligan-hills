class_name MHAnalyticsServiceMock
extends MHAnalyticsService
## Records events in memory. Also the safe default for desktop builds.

var events: Array = []  # of {"name": String, "params": Dictionary}
var properties: Dictionary = {}
var reset_calls: int = 0

func log_event(event_name: String, params: Dictionary = {}) -> void:
	if enabled:
		events.append({"name": event_name, "params": params.duplicate(true)})

func set_user_property(key: String, value: String) -> void:
	if enabled:
		properties[key] = value

func reset_identity() -> void:
	reset_calls += 1
	properties.clear()
