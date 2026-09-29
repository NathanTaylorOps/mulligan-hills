"""MHHash reference: FNV-1a 64-bit with the state as two 32-bit halves.
Prime 0x100000001B3 = 2**40 + 435, so x*prime mod 2**64 = x*435 + (x << 40).
Integers are absorbed as 8 little-endian two's-complement bytes (|v| < 2**62).
"""
M32 = 0xFFFFFFFF
OFFSET_HI = 0xCBF29CE4
OFFSET_LO = 0x84222325


def hex32(v):
    return "%08x" % v


class Fnv64:
    def __init__(self):
        self.reset()

    def reset(self):
        self.hi = OFFSET_HI
        self.lo = OFFSET_LO

    def add_byte(self, b):
        lo = self.lo ^ (b & 0xFF)
        t = lo * 435
        self.lo = t & M32
        self.hi = (self.hi * 435 + (t >> 32) + ((lo << 8) & M32)) & M32

    def add_u32(self, v):
        assert 0 <= v <= M32
        self.add_byte(v)
        self.add_byte(v >> 8)
        self.add_byte(v >> 16)
        self.add_byte(v >> 24)

    def add_i64(self, v):
        assert -(1 << 62) <= v < (1 << 62)
        lo = v & M32
        hi = ((v - lo) // 4294967296) & M32  # exact division
        self.add_u32(lo)
        self.add_u32(hi)

    def hex(self):
        return hex32(self.hi) + hex32(self.lo)
