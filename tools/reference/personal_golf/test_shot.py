import copy
import json
from pathlib import Path
import unittest
from model import ATTRIBUTES
from shot import shot, preview
P={'v':1,**dict.fromkeys(ATTRIBUTES,500)}
H={'slot_id':1,'tee':[0,0],'green':[0,100,5],'features':[{'t':'fairway','rect':[-20,0,20,95]}]}

def play(h=None,p=None,ball=(0,0),lie='tee',aim=(0,6000),seed=1234,index=1,style='straight',pressure=0):
    return shot(H if h is None else h,P if p is None else p,ball,lie,aim,seed,index,style,pressure)

def feature(kind,rect):
    h=copy.deepcopy(H);h['features'].append({'t':kind,'rect':rect});return h

class Shots(unittest.TestCase):
    def test_checked_in_golden_cases(self):
        data=json.loads(Path(__file__).with_name("shot_golden.json").read_text())
        self.assertEqual(len(data["cases"]),12)
        for row in data["cases"]:
            with self.subTest(row["name"]):
                self.assertEqual(shot(**row["inputs"]),row["expected"])

    def test_fixed_straight(self):
        self.assertEqual(play(),{'model':'MHPERSONAL-SHOT-0.1','x':-192,'y':6044,'lie':'fairway','club':10,'penalty':0,'penalty_kind':0,'tree':False,'holed':False,'shot_index':1})

    def test_preview_and_resume(self):
        a=play();preview(H,P,(0,0),'tee',(0,6000));self.assertEqual(play(),a)
        self.assertNotEqual((play(index=2)['x'],play(index=2)['y']),(a['x'],a['y']))

    def test_water(self):
        r=play(h=feature('water',[-10,55,10,65]))
        self.assertEqual((r['x'],r['y'],r['lie'],r['penalty'],r['penalty_kind']),(0,0,'tee',1,1))

    def test_ob(self):
        r=play(h=feature('ob',[-10,55,10,65]))
        self.assertEqual((r['x'],r['y'],r['penalty'],r['penalty_kind']),(0,0,1,2))

    def test_tree(self):
        h=copy.deepcopy(H);h['features'].append({'t':'tree','at':[[0,10]]})
        r=play(h=h);self.assertTrue(r['tree']);self.assertLess(r['y'],1000);self.assertEqual(r['lie'],'deep')
        # Stored deep lie at the actual impact backoff is accepted for the next shot.
        self.assertIsInstance(play(h=h,ball=(r['x'],r['y']),lie='deep',index=2,style='safe_recovery'),dict)

    def test_slow_cup(self):
        r=play(ball=(0,9500),lie='green',aim=(0,10000),style='putt')
        self.assertEqual((r['x'],r['y'],r['holed']),(0,10000,True))

    def test_fast_cup_pass(self):
        p={**P,'touch':1000}
        r=play(p=p,ball=(0,9500),lie='green',aim=(0,11000),style='putt')
        self.assertFalse(r['holed']);self.assertGreater(r['y'],10500)

    def test_putt_hazard_before_safe_endpoint(self):
        for kind,code in (('water',1),('ob',2)):
            h=feature(kind,[-5,96,5,97])
            r=play(h=h,p={**P,'touch':1000},ball=(0,9500),lie='green',aim=(0,10000),style='putt')
            self.assertEqual((r['x'],r['y'],r['penalty'],r['penalty_kind'],r['holed']),(0,9500,1,code,False))

    def test_zero_width_ground_hazards(self):
        h=feature('water',[-5,96,5,96])
        r=play(h=h,ball=(0,9500),lie='green',aim=(0,10000),style='putt')
        self.assertEqual(r['penalty_kind'],1)

    def test_air_crossing_does_not_capture(self):
        r=play(aim=(0,10500));self.assertFalse(r['holed'])

    def test_invalid_inputs(self):
        for kw in ({'seed':True},{'index':0},{'index':1000001},{'ball':(True,0)},{'ball':(1.0,0)},{'aim':(0,0)},{'lie':'water'},{'lie':'green'},{'ball':(0,100),'lie':'tee'},{'style':'draw'},{'h':{'tee':[0,0]}},{'p':{**P,'luck':1001}}):
            with self.assertRaises(ValueError):play(**kw)

    def test_malformed_geometry_types(self):
        for changes in ({'tee':[0.0,0]},{'features':[{'t':'tree','at':[[0,10.0]]}]},{'features':[{'t':'water','rect':[-1,10,1,11.0]}]},{'features':[{'t':'tree','rect':[0,10,1,11],'count':1.0}]},{'slot_id':True},{'slot_id':19},{'tee_z_mm':0.5},{'features':[{'t':{}}]},{'features':[{'t':'tree','circle':[0,10,1]}]},{'features':[{'t':'tree','rect':[0,10,1,11]}]},{'features':[{'t':'water','rect':[1,1,2,2],'circle':[1,1,1]}]}):
            with self.assertRaises(ValueError):play(h={**H,**changes})

    def test_pure_inputs_and_shapes(self):
        before=copy.deepcopy((H,P));play();self.assertEqual((H,P),before)
        r=play();self.assertTrue(all(type(r[k]) is int for k in ('x','y','club','penalty','penalty_kind','shot_index')))
        self.assertEqual(play(p={**P,'shaping':0,'luck':0}),play(p={**P,'shaping':1000,'luck':1000}))

if __name__=='__main__':unittest.main()
