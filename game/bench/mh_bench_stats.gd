class_name MHBenchStats
extends RefCounted
## Pure statistics helpers for frame-time samples (milliseconds).


## Nearest-rank percentile on an ALREADY SORTED ascending array. p in (0, 100].
static func percentile_sorted(sorted_ms: PackedFloat32Array, p: float) -> float:
	var n: int = sorted_ms.size()
	if n == 0:
		return 0.0
	var rank: int = int(ceil(p / 100.0 * float(n)))
	var idx: int = clampi(rank - 1, 0, n - 1)
	return sorted_ms[idx]


static func summarize(frame_ms: PackedFloat32Array) -> Dictionary:
	var n: int = frame_ms.size()
	if n == 0:
		return {"frames": 0, "avg_ms": 0.0, "avg_fps": 0.0, "p50_ms": 0.0, "p95_ms": 0.0,
			"p99_ms": 0.0, "max_ms": 0.0, "min_fps": 0.0, "pct_over_33ms": 0.0, "pct_over_50ms": 0.0}
	var sorted: PackedFloat32Array = frame_ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	var over33: int = 0
	var over50: int = 0
	for v in frame_ms:
		total += v
		if v > 33.4:
			over33 += 1
		if v > 50.0:
			over50 += 1
	var avg: float = total / float(n)
	var mx: float = sorted[n - 1]
	return {
		"frames": n,
		"avg_ms": snappedf(avg, 0.01),
		"avg_fps": snappedf(1000.0 / avg if avg > 0.0 else 0.0, 0.1),
		"p50_ms": snappedf(percentile_sorted(sorted, 50.0), 0.01),
		"p95_ms": snappedf(percentile_sorted(sorted, 95.0), 0.01),
		"p99_ms": snappedf(percentile_sorted(sorted, 99.0), 0.01),
		"max_ms": snappedf(mx, 0.01),
		"min_fps": snappedf(1000.0 / mx if mx > 0.0 else 0.0, 0.1),
		"pct_over_33ms": snappedf(100.0 * float(over33) / float(n), 0.1),
		"pct_over_50ms": snappedf(100.0 * float(over50) / float(n), 0.1),
	}


## Pass rule used by the harness (assumption; confirm against docs/phase0/GATE0.md):
## average fps >= 30 and p95 frame time <= 34.0 ms.
static func verdict(summary: Dictionary) -> String:
	if int(summary.get("frames", 0)) == 0:
		return "NO_DATA"
	if float(summary["avg_fps"]) >= 30.0 and float(summary["p95_ms"]) <= 34.0:
		return "PASS_30FPS"
	return "FAIL_30FPS"
