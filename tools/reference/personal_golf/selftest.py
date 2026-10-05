"""Boundary and exhaustive monotonicity checks; run directly with Python."""
import unittest
from model import ATTRIBUTES, BAD, envelope, profile

P = {'v': 1, **dict.fromkeys(ATTRIBUTES, 500)}

def shot(**kw):
    args = dict(desired_cy=10000, base_carry_cy=30000, lie='fairway')
    args.update(kw)
    return envelope(P, **args)

class Checks(unittest.TestCase):
    def test_boundaries(self):
        for x in (0, 1000):
            self.assertEqual(profile({'v': 1, **dict.fromkeys(ATTRIBUTES, x)})['luck'], x)
        for x in (-1, 1001, True, 1.5, '500', None):
            with self.assertRaises(ValueError): profile({**P, 'power': x})

    def test_snapshot(self):
        for p in ({k:v for k,v in P.items() if k != 'luck'}, {**P, 'extra':0}, {**P, 'v':True}, {**P, 'v':2}):
            with self.assertRaises(ValueError): profile(p)
        snapshot = profile(P); snapshot['power'] = 0
        self.assertEqual(P['power'], 500)

    def test_power(self):
        values = [envelope({**P, 'power':v}, 10000, 30000, 'fairway')['carry_max_cy'] for v in range(1001)]
        self.assertEqual(values, sorted(values))
        self.assertEqual((values[0], values[-1]), (18000, 30000))

    def test_accuracy(self):
        values = [envelope({**P, 'accuracy':v}, 10000, 30000, 'fairway')['lateral_scale_cy'] for v in range(1001)]
        self.assertEqual(values, sorted(values, reverse=True))
        self.assertEqual((values[0], values[-1]), (1300, 400))

    def test_touch(self):
        for lie, style in (('fairway', 'straight'), ('green', 'putt')):
            for axis in ('lateral_scale_cy', 'depth_scale_cy'):
                values = [envelope({**P, 'touch':v}, 500, 30000, lie, style)[axis] for v in range(1001)]
                self.assertEqual(values, sorted(values, reverse=True))

    def test_recovery(self):
        for lie in BAD:
            results = [envelope({**P, 'recovery':v}, 5000, 30000, lie) for v in range(1001)]
            carries = [r['carry_max_cy'] for r in results]
            errors = [r['lateral_scale_cy'] for r in results]
            self.assertEqual(carries, sorted(carries)); self.assertEqual(errors, sorted(errors, reverse=True))
            self.assertLess(carries[-1], shot()['carry_max_cy'])
            overreach = [envelope({**P, 'recovery':v}, 120000, 30000, lie) for v in range(1001)]
            spread = [r['lie_spread_pm'] for r in overreach]
            self.assertEqual(spread, sorted(spread, reverse=True))
            self.assertGreater(spread[-1], 1000)
        self.assertEqual(envelope({**P,'recovery':0},10000,30000,'fairway'), envelope({**P,'recovery':1000},10000,30000,'fairway'))

    def test_safe(self):
        normal = shot(lie='rough'); safe = shot(lie='rough', style='safe_recovery')
        self.assertEqual(safe['effective_cy'],6000)
        self.assertLess(safe['lateral_scale_cy'], normal['lateral_scale_cy'])
        with self.assertRaises(ValueError): shot(style='safe_recovery')

    def test_pressure(self):
        values = [envelope({**P,'composure':v},10000,30000,'fairway',pressure_pm=150)['lateral_scale_cy'] for v in range(1001)]
        self.assertEqual(values, sorted(values, reverse=True))
        self.assertEqual(shot(pressure_pm=150)['carry_max_cy'],shot()['carry_max_cy'])

    def test_putt_and_invalid(self):
        a=envelope({**P,'power':0,'accuracy':0},500,30000,'green','putt')
        b=envelope({**P,'power':1000,'accuracy':1000},500,30000,'green','putt')
        self.assertEqual(a,b)
        self.assertEqual(envelope(P,1,1,'deep')['effective_cy'],1)
        for kw in ({'desired_cy':0},{'desired_cy':True},{'base_carry_cy':40001},{'pressure_pm':151},{'lie':'water'},{'style':'draw'},{'lie':'green'},{'style':'putt'},{'lie':[]},{'style':{}},{'pressure_pm':False}):
            with self.assertRaises(ValueError): shot(**kw)

    def test_pure(self):
        before=P.copy(); self.assertEqual(shot(),shot()); self.assertEqual(P,before)
        self.assertEqual(envelope({**P,'luck':0,'shaping':0},10000,30000,'fairway'),envelope({**P,'luck':1000,'shaping':1000},10000,30000,'fairway'))
        self.assertEqual(shot(), {'model':'MHPERSONAL-ENVELOPE-0.1','carry_max_cy':24000,'effective_cy':10000,'lie_spread_pm':1000,'lateral_scale_cy':850,'depth_scale_cy':430})

if __name__ == '__main__': unittest.main()
