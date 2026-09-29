class_name MHRng
extends RefCounted
## PCG32 (XSH-RR 64/32). Mirror of tools/reference/determinism/mh_rng.py.
## The 64-bit state is kept as two 32-bit halves in GDScript ints; 64-bit multiplication is done with
## 16-bit limbs so every intermediate stays below 2^63 (no reliance on signed overflow wrap).
## seed must be in [0, 2^63), stream in [0, 2^62). NEVER use randf/randi in simulation code.

const M32: int = 0xFFFFFFFF
const MULT_HI: int = 0x5851F42D
const MULT_LO: int = 0x4C957F2D

var _hi: int = 0
var _lo: int = 0
var _inc_hi: int = 0
var _inc_lo: int = 0


func _init(seed_value: int = 0, stream: int = 0) -> void:
	reseed(seed_value, stream)


static func _mul32lo(a: int, b: int) -> int:
	# low 32 bits of a*b for a, b in [0, 2^32)
	return (((a & 0xFFFF) * b) + ((((a >> 16) * b) & 0xFFFF) << 16)) & M32


func _step() -> void:
	var sh: int = _hi
	var sl: int = _lo
	var ml1: int = MULT_LO >> 16
	var ml0: int = MULT_LO & 0xFFFF
	var a0: int = sl * ml0
	var a1: int = sl * ml1
	var t: int = a0 + ((a1 & 0xFFFF) << 16)
	var lo: int = t & M32
	var hi: int = ((a1 >> 16) + (t >> 32) + _mul32lo(sh, MULT_LO) + _mul32lo(sl, MULT_HI)) & M32
	lo += _inc_lo
	var carry: int = lo >> 32
	lo = lo & M32
	hi = (hi + _inc_hi + carry) & M32
	_hi = hi
	_lo = lo


func reseed(seed_value: int, stream: int) -> void:
	_inc_lo = ((stream << 1) | 1) & M32
	_inc_hi = (stream >> 31) & M32
	_hi = 0
	_lo = 0
	_step()
	var lo: int = _lo + (seed_value & M32)
	var carry: int = lo >> 32
	_lo = lo & M32
	_hi = (_hi + ((seed_value >> 32) & M32) + carry) & M32
	_step()


func next_u32() -> int:
	var oh: int = _hi
	var ol: int = _lo
	_step()
	var t: int = (oh << 14) | (ol >> 18)
	var u: int = ol | ((oh & 0x7FFFFFF) << 32)
	var x: int = t ^ u
	var xs: int = (x >> 27) & M32
	var rot: int = oh >> 27
	return ((xs >> rot) | (xs << ((32 - rot) & 31))) & M32


## Uniform in [0, n), 1 <= n <= 2^32, unbiased by rejection.
func bounded(n: int) -> int:
	var threshold: int = (4294967296 - n) % n
	while true:
		var r: int = next_u32()
		if r >= threshold:
			return r % n
	return 0


## Uniform in [lo, hi] inclusive.
func range_incl(lo: int, hi: int) -> int:
	return lo + bounded(hi - lo + 1)


## Gaussian-like: sum of four uniforms in [0,65536) minus 131070 -> range +-131070, sd about 37837 (0.577 in Q16.16).
func gauss_q16() -> int:
	var u: int = next_u32()
	var v: int = next_u32()
	var s: int = (u & 0xFFFF) + (u >> 16) + (v & 0xFFFF) + (v >> 16)
	return s - 131070
