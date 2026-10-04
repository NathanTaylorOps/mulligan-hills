class_name MHArtRng
extends RefCounted
## Tiny deterministic integer RNG for procedural art. Never uses randf/randi.
## Same algorithm family as MHForestRng (lowbias32 hash + LCG) but kept separate so the art module
## has no dependency on game/render/. Every multiply goes through mul32 (no int64 overflow reliance).

const MASK: int = 0xFFFFFFFF

var state: int = 0


func _init(seed_value: int = 0) -> void:
	state = MHArtRng.hash32((seed_value & MASK) ^ 0x9E3779B9)


static func mul32(a: int, b: int) -> int:
	return ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & MASK


static func hash32(value: int) -> int:
	var x: int = value & MASK
	x ^= x >> 16
	x = MHArtRng.mul32(x, 0x7FEB352D)
	x ^= x >> 15
	x = MHArtRng.mul32(x, 0x846CA68B)
	x ^= x >> 16
	return x & MASK


## Stateless hash of two integers, for per-vertex jitter that must not depend on call order.
static func hash2(a: int, b: int) -> int:
	return MHArtRng.hash32(MHArtRng.hash32(a) ^ ((b * 0x27D4EB2F) & MASK))


## Stateless value in [-1.0, 1.0] from two integers.
static func noise2(a: int, b: int) -> float:
	return float(MHArtRng.hash2(a, b) % 20001) / 10000.0 - 1.0


func next_u32() -> int:
	state = (MHArtRng.mul32(state, 1664525) + 1013904223) & MASK
	return MHArtRng.hash32(state)


## Integer in [0, n). n must be > 0.
func range_int(n: int) -> int:
	return next_u32() % n


## Float in [0.0, 1.0].
func unit() -> float:
	return float(next_u32() % 10001) / 10000.0


## Float in [lo, hi].
func range_f(lo: float, hi: float) -> float:
	return lo + (hi - lo) * unit()


## Float in [-1.0, 1.0].
func signed() -> float:
	return unit() * 2.0 - 1.0
