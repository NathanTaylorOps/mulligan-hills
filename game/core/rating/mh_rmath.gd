class_name MHRMath
extends RefCounted
## Integer helpers for the rating engine (docs/spec/rating/golfer-sim.md section 1 and 3).
## Mirror of tools/reference/rating/rating_core.py. No float anywhere. GDScript int `/` truncates toward
## zero, so every division whose numerator can be negative goes through fdiv (floor).
@warning_ignore_start("integer_division")

const M32: int = 0xFFFFFFFF


## Floor division, b > 0.
static func fdiv(a: int, b: int) -> int:
	var q: int = a / b
	if a < 0 and (a % b) != 0:
		q -= 1
	return q


## Round half away from zero, b > 0.
static func rdiv(a: int, b: int) -> int:
	if a >= 0:
		return (2 * a + b) / (2 * b)
	return -((-2 * a + b) / (2 * b))


static func clampi_inc(x: int, lo: int, hi: int) -> int:
	if x < lo:
		return lo
	if x > hi:
		return hi
	return x


## Floor integer square root for n >= 0 (integer Newton, never sqrt()).
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


## Unit direction scaled by 1024: Vector3i(ux, uy, d). d == 0 gives (0, 1024, 0).
static func unit(dx: int, dy: int) -> Vector3i:
	var d: int = isqrt(dx * dx + dy * dy)
	if d == 0:
		return Vector3i(0, 1024, 0)
	return Vector3i(rdiv(dx * 1024, d), rdiv(dy * 1024, d), d)


## Piecewise linear over a flat ascending table [x0, y0, x1, y1, ...].
static func interp(tab: PackedInt32Array, x: int) -> int:
	var n: int = tab.size() / 2
	if x <= tab[0]:
		return tab[1]
	for i in range(1, n):
		var x1: int = tab[i * 2]
		if x <= x1:
			var x0: int = tab[i * 2 - 2]
			var y0: int = tab[i * 2 - 1]
			var y1: int = tab[i * 2 + 1]
			return y0 + rdiv((y1 - y0) * (x - x0), x1 - x0)
	return tab[n * 2 - 1]


## Low 32 bits of a * c for a, c in [0, 2^32), without relying on signed overflow.
static func mul32(a: int, c: int) -> int:
	return (((a & 0xFFFF) * c) + ((((a >> 16) * c) & 0xFFFF) << 16)) & M32


static func mix32(h_in: int) -> int:
	var h: int = h_in & M32
	h = h ^ (h >> 16)
	h = mul32(h, 0x85EBCA6B)
	h = h ^ (h >> 13)
	h = mul32(h, 0xC2B2AE35)
	h = h ^ (h >> 16)
	return h


static func h32_step(h: int, x: int) -> int:
	return mix32(((h ^ (x & M32)) + 0x9E3779B9) & M32)


static func h32b(a: int, b: int) -> int:
	return h32_step(h32_step(0x811C9DC5, a), b)


static func h32c(a: int, b: int, c: int) -> int:
	return h32_step(h32_step(h32_step(0x811C9DC5, a), b), c)


static func h32d(a: int, b: int, c: int, d: int) -> int:
	return h32_step(h32_step(h32_step(h32_step(0x811C9DC5, a), b), c), d)


## Generic H32 over an Array of ints (tests, rare paths).
static func h32(args: Array) -> int:
	var h: int = 0x811C9DC5
	for v in args:
		h = h32_step(h, int(v))
	return h


static func hex32(v: int) -> String:
	var digits: String = "0123456789abcdef"
	var s: String = ""
	for i in range(7, -1, -1):
		s += digits[(v >> (i * 4)) & 15]
	return s


## MH-HASH64: two 32-bit FNV-1a lanes (basis 0x811C9DC5 and 0x9747B28C), lane 0 printed first.
static func hash64(data: PackedByteArray) -> String:
	var h0: int = 0x811C9DC5
	var h1: int = 0x9747B28C
	for b in data:
		h0 = ((h0 ^ b) * 16777619) & M32
		h1 = ((h1 ^ b) * 16777619) & M32
	return hex32(h0) + hex32(h1)


static func push_i32(buf: PackedByteArray, v: int) -> void:
	var u: int = v & M32
	buf.append(u & 0xFF)
	buf.append((u >> 8) & 0xFF)
	buf.append((u >> 16) & 0xFF)
	buf.append((u >> 24) & 0xFF)


static func push_ascii(buf: PackedByteArray, s: String) -> void:
	buf.append_array(s.to_utf8_buffer())


static func hole_seed(save_secret: int, epoch: int, slot_id: int) -> int:
	return h32d(save_secret, epoch, slot_id, 0x4D48)


static func daily_seed(challenge_id: int, slot_id: int) -> int:
	return h32d(0xDA11, challenge_id, slot_id, 0x4D48)


static func tournament_seed(save_secret: int, event_id: int, slot_id: int) -> int:
	return h32d(save_secret, event_id, slot_id, 0x7E)
