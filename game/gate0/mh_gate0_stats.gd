class_name MHGate0Stats
extends RefCounted
## Rolling frame-time statistics (milliseconds) for the Gate 0 scenes. Pure logic, no engine calls.
## Keeps the most recent `window` samples plus running totals since reset().

var window: int = 1800
var total_frames: int = 0
var total_ms: float = 0.0
var worst_ms: float = 0.0

var _buf: PackedFloat32Array = PackedFloat32Array()
var _head: int = 0
var _filled: int = 0


func _init(p_window: int = 1800) -> void:
	window = maxi(p_window, 1)
	_buf.resize(window)


func reset() -> void:
	total_frames = 0
	total_ms = 0.0
	worst_ms = 0.0
	_head = 0
	_filled = 0


func add(ms: float) -> void:
	_buf[_head] = ms
	_head = (_head + 1) % window
	if _filled < window:
		_filled += 1
	total_frames += 1
	total_ms += ms
	if ms > worst_ms:
		worst_ms = ms


func window_count() -> int:
	return _filled


func window_samples() -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(_filled):
		out.append(_buf[i])
	return out


## Nearest-rank percentile on an ascending array. p in (0, 100].
static func percentile_sorted(sorted_ms: PackedFloat32Array, p: float) -> float:
	var n: int = sorted_ms.size()
	if n == 0:
		return 0.0
	var rank: int = int(ceil(p / 100.0 * float(n)))
	return sorted_ms[clampi(rank - 1, 0, n - 1)]


## Summary of the rolling window. Keys: frames, avg_ms, avg_fps, p95_ms, p99_ms, max_ms,
## pct_over_33ms, total_frames, worst_ms_since_reset.
func summary() -> Dictionary:
	var s: PackedFloat32Array = window_samples()
	var n: int = s.size()
	var out: Dictionary = {"frames": n, "avg_ms": 0.0, "avg_fps": 0.0, "p95_ms": 0.0, "p99_ms": 0.0,
		"max_ms": 0.0, "pct_over_33ms": 0.0, "total_frames": total_frames, "worst_ms_since_reset": snappedf(worst_ms, 0.01)}
	if n == 0:
		return out
	var sum: float = 0.0
	var over: int = 0
	for v: float in s:
		sum += v
		if v > 33.4:
			over += 1
	s.sort()
	var avg: float = sum / float(n)
	out["avg_ms"] = snappedf(avg, 0.01)
	out["avg_fps"] = snappedf(1000.0 / avg if avg > 0.0 else 0.0, 0.1)
	out["p95_ms"] = snappedf(percentile_sorted(s, 95.0), 0.01)
	out["p99_ms"] = snappedf(percentile_sorted(s, 99.0), 0.01)
	out["max_ms"] = snappedf(s[n - 1], 0.01)
	out["pct_over_33ms"] = snappedf(100.0 * float(over) / float(n), 0.1)
	return out


## One-line text for a live HUD.
func live_line() -> String:
	var d: Dictionary = summary()
	return "fps %.1f  avg %.1f ms  p95 %.1f ms  max %.1f ms" % [d["avg_fps"], d["avg_ms"], d["p95_ms"], d["max_ms"]]


## Gate 0 budget (DEC-047, placeholder until measured): avg >= 30 fps, p95 <= 33.4 ms, no frame > 100 ms.
static func verdict_30fps(sum: Dictionary) -> String:
	if int(sum.get("frames", 0)) == 0:
		return "NO_DATA"
	if float(sum["avg_fps"]) >= 30.0 and float(sum["p95_ms"]) <= 33.4 and float(sum["max_ms"]) <= 100.0:
		return "PASS_30FPS"
	return "FAIL_30FPS"
