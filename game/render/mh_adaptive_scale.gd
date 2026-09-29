class_name MHAdaptiveScale
extends RefCounted
## Adaptive 3D render scale. Feed it frame times; it steps Viewport.scaling_3d_scale within the tier's
## [min, max]. Pure logic in `step` so it can be tested; `apply` touches the viewport.

const STEP: float = 0.05
const WINDOW_FRAMES: int = 30
const DOWN_THRESHOLD: float = 1.10
const UP_THRESHOLD: float = 0.80
const UP_HOLD_WINDOWS: int = 4

var enabled: bool = true
var scale_min: float = 0.6
var scale_max: float = 1.0
var target_ms: float = 33.3
var current: float = 1.0

var _sum_ms: float = 0.0
var _frames: int = 0
var _calm_windows: int = 0


func configure(cfg: Dictionary) -> void:
	scale_min = float(cfg["render_scale_min"])
	scale_max = float(cfg["render_scale_max"])
	target_ms = 1000.0 / float(cfg["target_fps"])
	current = scale_max
	_sum_ms = 0.0
	_frames = 0
	_calm_windows = 0


## Returns the (possibly changed) scale after observing one frame.
func step(frame_ms: float) -> float:
	if not enabled:
		return current
	_sum_ms += frame_ms
	_frames += 1
	if _frames < WINDOW_FRAMES:
		return current
	var avg: float = _sum_ms / float(_frames)
	_sum_ms = 0.0
	_frames = 0
	if avg > target_ms * DOWN_THRESHOLD:
		current = maxf(scale_min, current - STEP)
		_calm_windows = 0
	elif avg < target_ms * UP_THRESHOLD:
		_calm_windows += 1
		if _calm_windows >= UP_HOLD_WINDOWS:
			current = minf(scale_max, current + STEP)
			_calm_windows = 0
	else:
		_calm_windows = 0
	return current


func apply(viewport: Viewport) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = current
