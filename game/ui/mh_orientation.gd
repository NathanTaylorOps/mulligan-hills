class_name MHOrientation
extends RefCounted
## Screen orientation policy: the ONE place that decides what orientation game scenes use.
##
## Decision (not yet confirmed by Nathan): game scenes (live construction) are locked to SENSOR_LANDSCAPE, which
## allows both landscape directions but never portrait. The launcher and everything else keep the project-wide
## setting (display/window/handheld/orientation, currently 6 = sensor, any direction).
## To change the policy edit DEFAULT_GAME below, or add to project.godot:
##   [mulligan]
##   ui/game_orientation=6        ; 6 = free rotation again
## Values are DisplayServer.ScreenOrientation: 0 landscape, 1 portrait, 2 reverse landscape, 3 reverse portrait,
## 4 sensor landscape, 5 sensor portrait, 6 sensor.
## Runtime switching uses DisplayServer.screen_set_orientation, which only acts on mobile (guarded by the
## "mobile" feature tag; desktop/headless/CI never call it). UNVERIFIED on a device: see docs/phase1/live_construction.md.

const GAME_SETTING: String = "mulligan/ui/game_orientation"
const PROJECT_SETTING: String = "display/window/handheld/orientation"
const LANDSCAPE: int = 0
const PORTRAIT: int = 1
const REVERSE_LANDSCAPE: int = 2
const REVERSE_PORTRAIT: int = 3
const SENSOR_LANDSCAPE: int = 4
const SENSOR_PORTRAIT: int = 5
const SENSOR: int = 6
const DEFAULT_GAME: int = SENSOR_LANDSCAPE


## Pure. Valid orientation value, or `fallback` for anything outside 0..6.
static func sanitize(value: int, fallback: int) -> int:
	if value < LANDSCAPE or value > SENSOR:
		return fallback
	return value


## Pure. True for the three landscape-only values.
static func is_landscape_only(value: int) -> bool:
	return value == LANDSCAPE or value == REVERSE_LANDSCAPE or value == SENSOR_LANDSCAPE


static func game_orientation() -> int:
	return sanitize(int(ProjectSettings.get_setting(GAME_SETTING, DEFAULT_GAME)), DEFAULT_GAME)


static func default_orientation() -> int:
	return sanitize(int(ProjectSettings.get_setting(PROJECT_SETTING, SENSOR)), SENSOR)


## Call when a game scene starts.
static func apply_game() -> void:
	_apply(game_orientation())


## Call when a game scene leaves (restores the project-wide setting).
static func restore_default() -> void:
	_apply(default_orientation())


static func _apply(value: int) -> void:
	if not OS.has_feature("mobile"):
		return
	DisplayServer.screen_set_orientation(value as DisplayServer.ScreenOrientation)
