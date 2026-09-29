class_name MHAdaptiveScale
extends RefCounted
## Adaptive 3D render scale. Feed it frame times; once per WINDOW_FRAMES it looks at the window's p95 frame
## time and steps Viewport.scaling_3d_scale within the tier's [min, max]. Only the 3D scale changes:
## UI/CanvasLayer rendering is not affected by scaling_3d_scale, so text and buttons stay native resolution.
##
## Hysteresis: down needs p95 > target * DOWN_THRESHOLD; up needs p95 < target * UP_THRESHOLD for
## `required_calm` consecutive windows. If a down step follows an up step within FLIP_WINDOWS windows,
## the calm requirement doubles (up to MAX_UP_HOLD) so the scale does not oscillate; it resets after
## STABLE_RESET_WINDOWS windows with no change.
## Pure decision in static `next_scale` so it is unit-testable; `apply` touches the viewport.

const STEP: float = 0.05
const WINDOW_FRAMES: int = 30
const DOWN_THRESHOLD: float = 1.05
const UP_THRESHOLD: float = 0.80
const UP_HOLD_WINDOWS: int = 4
const MAX_UP_HOLD: int = 16
const FLIP_WINDOWS: int = 6
const STABLE_RESET_WINDOWS: int = 20

var enabled: bool = true
## When true, frames are ignored (idle throttling makes long frames that are not a performance problem).
var paused: bool = false
var scale_min: float = 0.6
var scale_max: float = 1.0
var target_ms: float = 33.3
var current: float = 1.0
var changes: int = 0
var last_p95_ms: float = 0.0
var required_calm: int = UP_HOLD_WINDOWS

var _win: PackedFloat32Array = PackedFloat32Array()
var _calm_windows: int = 0
var _windows_since_change: int = 1000
var _last_change_dir: int = 0


func configure(cfg: Dictionary) -> void:
	scale_min = float(cfg["render_scale_min"])
	scale_max = float(cfg["render_scale_max"])
	target_ms = 1000.0 / float(cfg["target_fps"])
	current = scale_max
	changes = 0
	last_p95_ms = 0.0
	required_calm = UP_HOLD_WINDOWS
	_win = PackedFloat32Array()
	_calm_windows = 0
	_windows_since_change = 1000
	_last_change_dir = 0


## Frame time budget follows the active fps cap (30 -> 33.3 ms, 60 -> 16.7 ms).
func set_target_fps(fps: int) -> void:
	target_ms = 1000.0 / float(maxi(fps, 1))


## Pure decision for one finished window. Returns {scale, calm, dir} where dir is -1, 0 or 1.
static func next_scale(cur: float, p95_ms: float, budget_ms: float, smin: float, smax: float, calm: int, calm_needed: int) -> Dictionary:
	if p95_ms > budget_ms * DOWN_THRESHOLD:
		var lower: float = maxf(smin, cur - STEP)
		var d: int = -1 if lower < cur - 0.0001 else 0
		return {"scale": lower, "calm": 0, "dir": d}
	if p95_ms < budget_ms * UP_THRESHOLD:
		var c: int = calm + 1
		if c >= calm_needed:
			var higher: float = minf(smax, cur + STEP)
			var d2: int = 1 if higher > cur + 0.0001 else 0
			return {"scale": higher, "calm": 0, "dir": d2}
		return {"scale": cur, "calm": c, "dir": 0}
	return {"scale": cur, "calm": 0, "dir": 0}


## Returns the (possibly changed) scale after observing one frame.
func step(frame_ms: float) -> float:
	if not enabled or paused:
		return current
	_win.append(frame_ms)
	if _win.size() < WINDOW_FRAMES:
		return current
	var sorted: PackedFloat32Array = _win.duplicate()
	sorted.sort()
	_win = PackedFloat32Array()
	last_p95_ms = MHBenchStats.percentile_sorted(sorted, 95.0)
	_windows_since_change += 1
	if _windows_since_change >= STABLE_RESET_WINDOWS:
		required_calm = UP_HOLD_WINDOWS
	var r: Dictionary = next_scale(current, last_p95_ms, target_ms, scale_min, scale_max, _calm_windows, required_calm)
	_calm_windows = int(r["calm"])
	var dir: int = int(r["dir"])
	current = float(r["scale"])  # always take the clamped value so the floor and ceiling are exact
	if dir != 0:
		if dir < 0 and _last_change_dir > 0 and _windows_since_change < FLIP_WINDOWS:
			required_calm = mini(required_calm * 2, MAX_UP_HOLD)
		_last_change_dir = dir
		_windows_since_change = 0
		changes += 1
	return current


func apply(viewport: Viewport) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = current
