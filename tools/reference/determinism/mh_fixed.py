"""MHFixed reference: Q16.16 fixed point on signed 64-bit ints.

Semantics mirrored from GDScript (game/core/mh_fixed.gd):
  * Python ints are unbounded, so every product/shift that could overflow int64
    in GDScript goes through chk(), which asserts it stays inside int64.
    The design never RELIES on wraparound; the asserts prove that in tests.
  * No shift is ever applied to a negative value (sign-magnitude everywhere).
  * Division and modulo are only applied to non-negative operands, or through
    tdiv() which truncates toward zero exactly like GDScript int / int.
"""

FRAC = 16
ONE = 1 << 16
INT64_MIN = -(1 << 63)
INT64_MAX = (1 << 63) - 1
DIV0 = 2147483647  # saturation value returned by div(x, 0)


def chk(v):
    assert INT64_MIN <= v <= INT64_MAX, "int64 overflow would occur in GDScript"
    return v


def tdiv(a, b):
    """Truncate-toward-zero integer division (GDScript int / int)."""
    assert b != 0
    q = abs(a) // abs(b)
    return -q if (a < 0) != (b < 0) else q


def from_int(i):
    return chk(i * 65536)


def mul(a, b):
    neg = (a < 0) != (b < 0)
    p = chk(abs(a) * abs(b))
    r = p >> 16
    return -r if neg else r


def div(a, b):
    if b == 0:
        return DIV0 if a >= 0 else -DIV0
    n = chk(abs(a) * 65536)
    q = n // abs(b)
    return -q if (a < 0) != (b < 0) else q


def isqrt(n):
    """Floor integer square root by Newton iteration. n >= 0, n < 2**63."""
    if n <= 0:
        return 0
    bits = 0
    t = n
    while t > 0:
        t >>= 1
        bits += 1
    x = 1 << ((bits + 1) >> 1)  # >= sqrt(n)
    while True:
        y = (x + n // x) >> 1
        if y >= x:
            return x
        x = y


def sqrt(a):
    if a <= 0:
        return 0
    return isqrt(chk(a * 65536))


def hypot(dx, dy):
    return sqrt(mul(dx, dx) + mul(dy, dy))


def fabs(a):
    return -a if a < 0 else a


def clamp(a, lo, hi):
    if a < lo:
        return lo
    if a > hi:
        return hi
    return a


def lerp(a, b, t):
    return a + mul(b - a, t)


def trunc_int(a):
    """Q16.16 -> int, truncating toward zero."""
    q = abs(a) >> 16
    return -q if a < 0 else q


def floor_int(a):
    """Q16.16 -> int, rounding toward negative infinity."""
    if a >= 0:
        return a >> 16
    return -((-a + 65535) >> 16)
