"""MHRng reference: PCG32 (XSH-RR 64/32) with the 64-bit state kept as two
32-bit halves (hi, lo). Every intermediate stays below 2**63, so GDScript never
depends on signed-overflow behaviour. seed >= 0 (< 2**63), stream >= 0 (< 2**62).
"""
from mh_fixed import chk

M32 = 0xFFFFFFFF
MULT_HI = 0x5851F42D
MULT_LO = 0x4C957F2D


def mul32lo(a, b):
    """Low 32 bits of a*b for a, b in [0, 2**32)."""
    t = chk((a & 0xFFFF) * b) + ((chk((a >> 16) * b) & 0xFFFF) << 16)
    return t & M32


class Pcg32:
    def __init__(self, seed=0, stream=0):
        self.reseed(seed, stream)

    def _step(self):
        sh = self.hi
        sl = self.lo
        ml1 = MULT_LO >> 16
        ml0 = MULT_LO & 0xFFFF
        a0 = chk(sl * ml0)
        a1 = chk(sl * ml1)
        t = a0 + ((a1 & 0xFFFF) << 16)
        lo = t & M32
        hi = ((a1 >> 16) + (t >> 32) + mul32lo(sh, MULT_LO) + mul32lo(sl, MULT_HI)) & M32
        lo += self.inc_lo
        carry = lo >> 32
        lo &= M32
        hi = (hi + self.inc_hi + carry) & M32
        self.hi = hi
        self.lo = lo

    def reseed(self, seed, stream):
        assert 0 <= seed < (1 << 63) and 0 <= stream < (1 << 62)
        self.inc_lo = ((stream << 1) | 1) & M32
        self.inc_hi = (stream >> 31) & M32
        self.hi = 0
        self.lo = 0
        self._step()
        lo = self.lo + (seed & M32)
        carry = lo >> 32
        self.lo = lo & M32
        self.hi = (self.hi + ((seed >> 32) & M32) + carry) & M32
        self._step()

    def next_u32(self):
        oh = self.hi
        ol = self.lo
        self._step()
        t = (oh << 14) | (ol >> 18)
        u = ol | ((oh & 0x7FFFFFF) << 32)
        x = t ^ u
        xs = (x >> 27) & M32
        rot = oh >> 27
        return ((xs >> rot) | (xs << ((32 - rot) & 31))) & M32

    def bounded(self, n):
        """Uniform in [0, n), 1 <= n <= 2**32, unbiased (rejection)."""
        assert 1 <= n <= (1 << 32)
        threshold = ((1 << 32) - n) % n
        while True:
            r = self.next_u32()
            if r >= threshold:
                return r % n

    def range_incl(self, lo, hi):
        assert lo <= hi
        return lo + self.bounded(hi - lo + 1)

    def gauss_q16(self):
        """Sum of four uniforms in [0,65536) centred: range +-131070, sd ~ 37837 (0.577 in Q16.16)."""
        u = self.next_u32()
        v = self.next_u32()
        s = (u & 0xFFFF) + (u >> 16) + (v & 0xFFFF) + (v >> 16)
        return s - 131070
