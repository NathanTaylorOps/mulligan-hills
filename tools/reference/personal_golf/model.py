"""Personal golf envelope prototype. Integer only; no official rating changes."""
ATTRIBUTES = ('power', 'accuracy', 'touch', 'recovery', 'shaping', 'composure', 'luck')
BAD = {'rough': (800, 1500), 'deep': (600, 2200), 'bunker': (700, 1800)}
LIES = ('tee', 'fairway', 'fringe', 'rough', 'deep', 'bunker', 'green')
VERSION = 'MHPERSONAL-ENVELOPE-0.1'


def integer(value, lo, hi):
    if type(value) is not int or not lo <= value <= hi:
        raise ValueError('integer out of range')
    return value


def profile(raw):
    if type(raw) is not dict or set(raw) != {'v', *ATTRIBUTES}:
        raise ValueError('profile fields')
    if type(raw['v']) is not int or raw['v'] != 1:
        raise ValueError('profile version')
    return {'v': 1, **{key: integer(raw[key], 0, 1000) for key in ATTRIBUTES}}


def envelope(raw, desired_cy, base_carry_cy, lie, style='straight', pressure_pm=0):
    p = profile(raw)
    desired = integer(desired_cy, 1, 120000)
    base = integer(base_carry_cy, 1, 40000)
    pressure = integer(pressure_pm, 0, 150)
    if type(lie) is not str or type(style) is not str or lie not in LIES or style not in ('straight', 'safe_recovery', 'putt'):
        raise ValueError('lie/style')
    if (style == 'putt') != (lie == 'green'):
        raise ValueError('putting requires green')
    if style == 'safe_recovery' and lie not in BAD:
        raise ValueError('recovery requires bad lie')
    carry = base * (600 + p['power'] * 400 // 1000) // 1000
    disp = 1000
    if lie in BAD:
        c, d = BAD[lie]
        carry = carry * (c + p['recovery'] * (1000-c) // 2000) // 1000
        disp = d - p['recovery'] * (d-1000) // 2000
    if style == 'putt':
        carry = 3000
        lateral_pm = 60 - p['touch'] * 50 // 1000
        depth_pm = 100 - p['touch'] * 80 // 1000
    elif desired <= 800:
        lateral_pm = depth_pm = 80 - p['touch'] * 60 // 1000
    else:
        lateral_pm = 130 - p['accuracy'] * 90 // 1000
        depth_pm = 60 - p['touch'] * 35 // 1000
    if style == 'safe_recovery':
        carry = min(carry, 6000)
    carry = max(1, carry)
    effective = min(desired, carry)
    multiplier = 1000 + pressure * (1000-p['composure']) // 1000
    lateral = effective * lateral_pm // 1000 * disp // 1000 * multiplier // 1000
    depth = effective * depth_pm // 1000 * disp // 1000 * multiplier // 1000
    if style == 'safe_recovery':
        lateral = lateral * 700 // 1000
        depth = depth * 700 // 1000
    return {'model': VERSION, 'carry_max_cy': carry, 'effective_cy': effective,
            'lie_spread_pm': disp, 'lateral_scale_cy': max(1, lateral), 'depth_scale_cy': max(1, depth)}
