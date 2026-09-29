class_name MHFixed
extends RefCounted
## Q16.16 fixed point on GDScript 64-bit ints. Mirror of tools/reference/determinism/mh_fixed.py.
##
## Format: raw = value * 65536. Range for mul: |raw| <= 2^31 (product < 2^62, no int64 overflow).
## Why Q16.16 and not Q24.8: 1/65536 m resolution keeps 0.01 fractions (wind, dispersion) exact
## enough; Q24.8 (1/256 m) loses too much in products of small terms. Range +-32768 m is ample.
##
## Integer semantics chosen (never rely on the surprising ones):
##  - No shift is applied to a negative value: mul/div work on absolute values and re-apply sign.
##  - No integer overflow is relied on: all intermediates stay below 2^63.
##  - int / int truncates toward zero in GDScript; we only divide non-negative operands.
##  - Results of mul/div/trunc_int truncate toward zero; floor_int rounds toward -infinity.

const FRAC: int = 16
const ONE: int = 65536
const DIV0: int = 2147483647 ## div(x, 0) saturates to +-DIV0


static func from_int(i: int) -> int:
	return i * 65536


static func mul(a: int, b: int) -> int:
	var neg: bool = (a < 0) != (b < 0)
	var r: int = (absi(a) * absi(b)) >> 16
	return -r if neg else r


@warning_ignore("integer_division")
static func div(a: int, b: int) -> int:
	if b == 0:
		return DIV0 if a >= 0 else -DIV0
	var q: int = (absi(a) * 65536) / absi(b)
	return -q if (a < 0) != (b < 0) else q


## Floor integer square root, Newton iteration, n in [0, 2^63).
@warning_ignore("integer_division")
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var bits: int = 0
	var t: int = n
	while t > 0:
		t = t >> 1
		bits += 1
	var x: int = 1 << ((bits + 1) >> 1)
	while true:
		var y: int = (x + n / x) >> 1
		if y >= x:
			return x
		x = y
	return x


static func sqrt_fx(a: int) -> int:
	if a <= 0:
		return 0
	return isqrt(a * 65536)


static func hypot(dx: int, dy: int) -> int:
	return sqrt_fx(mul(dx, dx) + mul(dy, dy))


static func abs_fx(a: int) -> int:
	return -a if a < 0 else a


static func clamp_fx(a: int, lo: int, hi: int) -> int:
	if a < lo:
		return lo
	if a > hi:
		return hi
	return a


static func lerp_fx(a: int, b: int, t: int) -> int:
	return a + mul(b - a, t)


## Q16.16 -> int, truncating toward zero.
static func trunc_int(a: int) -> int:
	var q: int = absi(a) >> 16
	return -q if a < 0 else q


## Q16.16 -> int, rounding toward negative infinity.
static func floor_int(a: int) -> int:
	if a >= 0:
		return a >> 16
	return -((-a + 65535) >> 16)
