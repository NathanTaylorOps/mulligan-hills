class_name MHBenchRunner
extends Node
## Frame-time benchmark harness. Add as a child, call start(). Logs a JSON line to stdout and rewrites
## user://bench.json every LOG_INTERVAL_S and at the end. Emits `finished(summary)`.
##
## WHAT GODOT CANNOT TELL US: there is no core Godot API for device temperature, thermal state, CPU/GPU
## clocks or throttling level (as far as we know; verify at https://docs.godotengine.org). We record
## battery percent and power state from OS.* (availability on Android unverified) and use the ratio of
## last-window fps to first-window fps as a throttling proxy. Real thermal data needs the platform
## plugin (workstream F) or `adb shell dumpsys thermalservice` during the run.

signal finished(summary: Dictionary)

const LOG_INTERVAL_S: float = 5.0
const OUTPUT_PATH: String = "user://bench.json"
const MODE_QUICK: String = "quick"
const MODE_SOAK: String = "soak"
const MODE_IDLE: String = "idle"
const IDLE_SECONDS: float = 30.0
const QUICK_SECONDS: float = 60.0
const SOAK_SECONDS: float = 1200.0

var mode: String = MODE_QUICK
var duration_s: float = QUICK_SECONDS
var running: bool = false
## Set by the scene; called every window to attach tier/scale info. Returns Dictionary.
var context_cb: Callable = Callable()

var _all_ms: PackedFloat32Array = PackedFloat32Array()
var _win_ms: PackedFloat32Array = PackedFloat32Array()
var _windows: Array = []
var _start_us: int = 0
var _last_us: int = 0
var _win_start_us: int = 0
var _draw_sum: float = 0.0
var _draw_max: float = 0.0
var _prim_sum: float = 0.0
var _prim_max: float = 0.0
var _perf_samples: int = 0
var _mem_max: float = 0.0
var _vram_max: float = 0.0
var _batt_start: int = -1
var _summary: Dictionary = {}


func start(new_mode: String, seconds_override: float = -1.0) -> void:
	mode = new_mode
	duration_s = SOAK_SECONDS if new_mode == MODE_SOAK else QUICK_SECONDS
	if new_mode == MODE_IDLE:
		duration_s = IDLE_SECONDS
	if seconds_override > 0.0:
		duration_s = seconds_override
	_all_ms = PackedFloat32Array()
	_win_ms = PackedFloat32Array()
	_windows = []
	_draw_sum = 0.0
	_draw_max = 0.0
	_prim_sum = 0.0
	_prim_max = 0.0
	_perf_samples = 0
	_mem_max = 0.0
	_vram_max = 0.0
	_start_us = Time.get_ticks_usec()
	_last_us = _start_us
	_win_start_us = _start_us
	_batt_start = -1  # Godot 4 has no battery API; read manually per device_runbook
	running = true
	set_process(true)


func stop() -> void:
	if running:
		_finish()


func elapsed_s() -> float:
	return float(Time.get_ticks_usec() - _start_us) / 1000000.0


func _ready() -> void:
	set_process(false)


func _process(_delta: float) -> void:
	if not running:
		return
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now - _last_us) / 1000.0
	_last_us = now
	_all_ms.append(ms)
	_win_ms.append(ms)
	_sample_render_stats()
	if float(now - _win_start_us) / 1000000.0 >= LOG_INTERVAL_S:
		_log_window(now)
	if float(now - _start_us) / 1000000.0 >= duration_s:
		_finish()


func _sample_render_stats() -> void:
	var dc: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var pr: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_draw_sum += dc
	_prim_sum += pr
	_draw_max = maxf(_draw_max, dc)
	_prim_max = maxf(_prim_max, pr)
	_perf_samples += 1


func _snapshot_common() -> Dictionary:
	var mem: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var vram: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	_mem_max = maxf(_mem_max, mem)
	_vram_max = maxf(_vram_max, vram)
	var d: Dictionary = {
		"draw_calls_avg": snappedf(_draw_sum / float(maxi(_perf_samples, 1)), 0.1),
		"draw_calls_max": int(_draw_max),
		"primitives_avg": int(_prim_sum / float(maxi(_perf_samples, 1))),
		"primitives_max": int(_prim_max),
		"static_mem_mb": snappedf(mem, 0.1),
		"video_mem_mb": snappedf(vram, 0.1),
		"battery_pct": -1  # Godot 4 has no battery API; read manually per device_runbook,
	}
	if context_cb.is_valid():
		var ctx: Dictionary = context_cb.call()
		for k in ctx.keys():
			d[k] = ctx[k]
	return d


func _log_window(now_us: int) -> void:
	var w: Dictionary = MHBenchStats.summarize(_win_ms)
	var snap: Dictionary = _snapshot_common()
	for k in snap.keys():
		w[k] = snap[k]
	w["t_s"] = snappedf(float(now_us - _start_us) / 1000000.0, 0.1)
	_windows.append(w)
	_win_ms = PackedFloat32Array()
	_win_start_us = now_us
	print("MH_BENCH_WINDOW ", JSON.stringify(w))
	_write_file(false)


func _finish() -> void:
	running = false
	set_process(false)
	if _win_ms.size() > 0:
		_log_window(Time.get_ticks_usec())
	var s: Dictionary = MHBenchStats.summarize(_all_ms)
	var snap: Dictionary = _snapshot_common()
	for k in snap.keys():
		s[k] = snap[k]
	s["mode"] = mode
	s["duration_s"] = snappedf(elapsed_s(), 0.1)
	s["battery_start_pct"] = _batt_start
	s["static_mem_max_mb"] = snappedf(_mem_max, 0.1)
	s["video_mem_max_mb"] = snappedf(_vram_max, 0.1)
	s["throttle_ratio"] = _throttle_ratio()
	s["thermal"] = "NOT EXPOSED by Godot API; use adb dumpsys thermalservice"
	s["verdict"] = MHBenchStats.verdict(s)
	_summary = s
	print("MH_BENCH_SUMMARY ", JSON.stringify(s))
	_write_file(true)
	finished.emit(s)


## Average fps of the last window divided by that of the first window. Below 1.0 suggests
## throttling or leak growth. 1.0 when fewer than two windows exist.
func _throttle_ratio() -> float:
	if _windows.size() < 2:
		return 1.0
	var first: Dictionary = _windows[0]
	var last: Dictionary = _windows[_windows.size() - 1]
	var f0: float = float(first["avg_fps"])
	if f0 <= 0.0:
		return 1.0
	return snappedf(float(last["avg_fps"]) / f0, 0.01)


func _write_file(final: bool) -> void:
	var doc: Dictionary = {
		"meta": device_meta(),
		"final": final,
		"summary": _summary,
		"windows": _windows,
	}
	var f: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("MHBenchRunner: cannot open %s (error %d)" % [OUTPUT_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(doc, "  "))
	f.close()


static func device_meta() -> Dictionary:
	var meta: Dictionary = {
		"godot": Engine.get_version_info().get("string", "unknown"),
		"os": OS.get_name(),
		"model": OS.get_model_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderer_setting": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"cpu_count": OS.get_processor_count(),
		"screen_px": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"debug_build": OS.is_debug_build(),
	}
	if RenderingServer.has_method("get_current_rendering_method"):
		meta["renderer_active"] = str(RenderingServer.call("get_current_rendering_method"))
	if RenderingServer.has_method("get_current_rendering_driver_name"):
		meta["driver"] = str(RenderingServer.call("get_current_rendering_driver_name"))
	return meta


func last_summary() -> Dictionary:
	return _summary
