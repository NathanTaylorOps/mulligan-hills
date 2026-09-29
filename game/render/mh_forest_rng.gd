class_name MHForestRng
extends RefCounted
## Tiny integer-only RNG for tree placement. All values stay inside 32 bits and
## every multiply goes through mul32 so no intermediate exceeds 2^48 (no reliance
## on int64 overflow behaviour). Python reference lives in docs/phase0/forest.md.

const MASK: int = 0xFFFFFFFF

var state: int = 0


func _init(seed_value: int = 0) -> void:
	state = MHForestRng.hash32((seed_value & MASK) ^ 0x9E3779B9)


## 32-bit multiply modulo 2^32 without int64 overflow.
static func mul32(a: int, b: int) -> int:
	return ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & MASK


## lowbias32-style avalanche hash.
static func hash32(value: int) -> int:
	var x: int = value & MASK
	x ^= x >> 16
	x = mul32(x, 0x7FEB352D)
	x ^= x >> 15
	x = mul32(x, 0x846CA68B)
	x ^= x >> 16
	return x & MASK


func next_u32() -> int:
	state = (mul32(state, 1664525) + 1013904223) & MASK
	return MHForestRng.hash32(state)


## Uniform-ish integer in [0, n). n must be > 0 and <= 2^31.
func range_int(n: int) -> int:
	return next_u32() % n
