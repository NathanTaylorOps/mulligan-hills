class_name MHHash
extends RefCounted
## FNV-1a 64-bit with state as two 32-bit halves. Mirror of tools/reference/determinism/mh_hash.py.
## prime 0x100000001B3 = 2^40 + 435, so x * prime mod 2^64 = x * 435 + (x << 40), done without overflow.
## Ints are absorbed as 8 little-endian two's-complement bytes; |v| must be < 2^62.

const M32: int = 0xFFFFFFFF

var hi: int = 0xCBF29CE4
var lo: int = 0x84222325


func reset() -> void:
	hi = 0xCBF29CE4
	lo = 0x84222325


func add_byte(b: int) -> void:
	var l: int = lo ^ (b & 0xFF)
	var t: int = l * 435
	lo = t & M32
	hi = (hi * 435 + (t >> 32) + ((l << 8) & M32)) & M32


func add_u32(v: int) -> void:
	add_byte(v)
	add_byte(v >> 8)
	add_byte(v >> 16)
	add_byte(v >> 24)


@warning_ignore("integer_division")
func add_i64(v: int) -> void:
	var l: int = v & M32
	var h: int = ((v - l) / 4294967296) & M32 # exact division, so truncation does not matter
	add_u32(l)
	add_u32(h)


func hex() -> String:
	return hex32(hi) + hex32(lo)


static func hex32(v: int) -> String:
	var digits: String = "0123456789abcdef"
	var s: String = ""
	for i in range(7, -1, -1):
		s += digits[(v >> (i * 4)) & 15]
	return s
