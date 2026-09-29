class_name MHFrameGovernor
extends RefCounted
## Frame governor: picks Engine.max_fps and OS.low_processor_usage_mode from activity.
## Decision logic is pure (static `decide`, `resolve_cap`, instance `update`) so it can be unit tested with
## fake time. Only `apply` touches the engine. Nothing here changes what is drawn per frame: it only stops
## the device rendering frames nobody can see change (idle scene), or holds the player's chosen cap.
##
## Cap setting values: "30", "60", "auto". Auto picks by MHQuality tier (low/medium 30, high 60).

const SETTING_30: String = "30"
const SETTING_60: String = "60"
const SETTING_AUTO: String = "auto"
const SETTINGS: Array = ["30", "60", "auto"]

const MODE_DISABLED: String = "disabled"
const MODE_ACTIVE: String = "active"
const MODE_IDLE: String = "idle"

## No activity for this long before the governor drops to idle fps.
const DEFAULT_HOLD_MS: int = 2000
const DEFAULT_IDLE_FPS: int = 15

var enabled: bool = true
var cap_setting: String = SETTING_AUTO
var tier_name: String = MHQuality.TIER_MEDIUM
var hold_ms: int = DEFAULT_HOLD_MS
var idle_fps: int = DEFAULT_IDLE_FPS

var mode: String = MODE_ACTIVE
var target_fps: int = 30
var low_processor: bool = false
var transitions: int = 0
var active_ms: int = 0
var idle_ms_total: int = 0

var _last_activity_ms: int = 0
var _last_update_ms: int = -1
var _applied_fps: int = -1
var _applied_low: bool = false
var _applied_once: bool = false


static func normalize_setting(raw: String) -> String:
	var s: String = raw.strip_edges().to_lower()
	if SETTINGS.has(s):
		return s
	return SETTING_AUTO


## Frame cap in fps for a setting and tier. Always >= 1.
static func resolve_cap(setting: String, tier: String) -> int:
	var s: String = normalize_setting(setting)
	if s == SETTING_30:
		return 30
	if s == SETTING_60:
		return 60
	if MHQuality.normalize_name(tier) == MHQuality.TIER_HIGH:
		return 60
	return 30


## Pure decision. `since_activity_ms` is time since the last activity (0 while active).
## Returns {mode, target_fps, low_processor}. Idle fps is never above the cap.
static func decide(cap: int, since_activity_ms: int, hold: int, idle_target: int, ambient_animation: bool) -> Dictionary:
	var c: int = maxi(cap, 1)
	if since_activity_ms < hold:
		return {"mode": MODE_ACTIVE, "target_fps": c, "low_processor": false}
	# low processor mode stops redrawing when nothing asks for it, which would freeze shader-driven
	# ambient animation (water), so it is only allowed when nothing ambient is animating.
	return {"mode": MODE_IDLE, "target_fps": clampi(idle_target, 1, c), "low_processor": not ambient_animation}


func set_setting(raw: String) -> void:
	cap_setting = normalize_setting(raw)


func set_tier(t: String) -> void:
	tier_name = MHQuality.normalize_name(t)


func cap() -> int:
	return resolve_cap(cap_setting, tier_name)


## Call on any input event, so wake-up is immediate rather than waiting for the next update.
func note_input(now_ms: int) -> void:
	_last_activity_ms = now_ms


## Advance the governor. Returns the decision Dictionary. Does not touch the engine.
func update(now_ms: int, input_active: bool, camera_moving: bool, anim_active: bool, ambient_animation: bool) -> Dictionary:
	if not enabled:
		mode = MODE_DISABLED
		return {"mode": MODE_DISABLED, "target_fps": 0, "low_processor": false}
	if input_active or camera_moving or anim_active:
		_last_activity_ms = now_ms
	var dt: int = 0
	if _last_update_ms >= 0:
		dt = maxi(now_ms - _last_update_ms, 0)
	_last_update_ms = now_ms
	var d: Dictionary = decide(cap(), maxi(now_ms - _last_activity_ms, 0), hold_ms, idle_fps, ambient_animation)
	var new_mode: String = str(d["mode"])
	if new_mode != mode:
		transitions += 1
	mode = new_mode
	target_fps = int(d["target_fps"])
	low_processor = bool(d["low_processor"])
	if mode == MODE_IDLE:
		idle_ms_total += dt
	else:
		active_ms += dt
	return d


## Pushes a decision to the engine. Only calls the engine when the value changed.
func apply(d: Dictionary) -> void:
	if str(d["mode"]) == MODE_DISABLED:
		return
	var fps: int = int(d["target_fps"])
	var low: bool = bool(d["low_processor"])
	if not _applied_once or fps != _applied_fps:
		Engine.max_fps = fps
		_applied_fps = fps
	if not _applied_once or low != _applied_low:
		OS.low_processor_usage_mode = low
		_applied_low = low
	_applied_once = true


## Restores unlimited fps and normal processor mode (used when the governor is turned off).
func release() -> void:
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	_applied_once = false
	_applied_fps = -1


func idle_pct() -> float:
	var total: int = active_ms + idle_ms_total
	if total <= 0:
		return 0.0
	return snappedf(100.0 * float(idle_ms_total) / float(total), 0.1)
