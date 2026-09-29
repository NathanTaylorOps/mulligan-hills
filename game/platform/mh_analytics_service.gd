class_name MHAnalyticsService
extends Node
## INTERFACE for analytics/crash events. Vendor undecided in Phase 0 (no Firebase adapter written).
## Rules: no personal data in event params; honour consent; reset_identity() on account deletion.

var enabled: bool = false  # opt-in until a consent screen exists

func set_enabled(value: bool) -> void:
	enabled = value

func log_event(event_name: String, params: Dictionary = {}) -> void:
	pass

func set_user_property(key: String, value: String) -> void:
	pass

## ACCOUNT DELETION hook: drop any analytics user id / properties.
func reset_identity() -> void:
	pass
