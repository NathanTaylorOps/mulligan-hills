"""MHTrig reference. Angles are 'brads16': 65536 units = one full turn.

Tables are built here with 60-digit Decimal arithmetic (no floats) and are
what game/core/mh_trig_table.gd is generated from (gen_tables.py).
Output of sin/cos is Q16.16 in [-65536, 65536].
"""
from decimal import Decimal, getcontext, ROUND_HALF_UP

getcontext().prec = 60
_D = Decimal


def _atan_series(x):
    x2 = x * x
    term = x
    total = x
    k = 1
    eps = _D(10) ** -56
    while True:
        term = -term * x2
        k += 2
        add = term / k
        total += add
        if abs(add) < eps:
            return total


def _pi():
    return 16 * _atan_series(_D(1) / 5) - 4 * _atan_series(_D(1) / 239)


def _atan(x):  # 0 <= x <= 1
    y = x / (1 + (1 + x * x).sqrt())
    return 2 * _atan_series(y)


def _sin(x):  # 0 <= x <= ~1.6
    x2 = x * x
    term = x
    total = x
    k = 1
    eps = _D(10) ** -56
    while True:
        term = -term * x2 / ((k + 1) * (k + 2))
        k += 2
        total += term
        if abs(term) < eps:
            return total


def _rnd(v):
    return int(v.to_integral_value(rounding=ROUND_HALF_UP))


def build_tables():
    pi = _pi()
    sin_q = [_rnd(_sin(pi * i / 512) * 65536) for i in range(257)]
    atan_t = [_rnd(_atan(_D(i) / 256) * 65536 / (2 * pi)) for i in range(257)]
    sin_q[256] = 65536
    atan_t[256] = 8192
    return sin_q, atan_t


SIN_Q, ATAN_T = build_tables()


def _qs(r):  # r in 0..16384
    idx = r >> 6
    if idx >= 256:
        return SIN_Q[256]
    frac = r & 63
    return SIN_Q[idx] + (((SIN_Q[idx + 1] - SIN_Q[idx]) * frac) >> 6)


def sin_brad(a):
    a &= 0xFFFF
    q = a >> 14
    r = a & 16383
    if q == 0:
        return _qs(r)
    if q == 1:
        return _qs(16384 - r)
    if q == 2:
        return -_qs(r)
    return -_qs(16384 - r)


def cos_brad(a):
    return sin_brad(a + 16384)


def _atan_q(r):  # r = ratio in Q16.16, 0..65536 -> brads 0..8192
    idx = r >> 8
    if idx >= 256:
        return ATAN_T[256]
    frac = r & 255
    return ATAN_T[idx] + (((ATAN_T[idx + 1] - ATAN_T[idx]) * frac) >> 8)


def atan2_brad(y, x):
    """Angle of vector (x, y) in brads16, range 0..65535 (counter-clockwise from +x)."""
    ax = -x if x < 0 else x
    ay = -y if y < 0 else y
    if ax == 0 and ay == 0:
        return 0
    if ay <= ax:
        base = _atan_q((ay * 65536) // ax)
    else:
        base = 16384 - _atan_q((ax * 65536) // ay)
    if x >= 0:
        if y >= 0:
            return base
        return (65536 - base) & 0xFFFF
    if y >= 0:
        return 32768 - base
    return 32768 + base
