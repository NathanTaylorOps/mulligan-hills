"""Explicitly regenerate personal-shot vectors after a reviewed model-version change."""
import copy
import json
from pathlib import Path
from model import ATTRIBUTES
from shot import shot, VERSION
P={'v':1,**dict.fromkeys(ATTRIBUTES,500)}
H={'slot_id':1,'tee':[0,0],'green':[0,100,5],'features':[{'t':'fairway','rect':[-20,0,20,95]}]}
BASE={'raw_hole':H,'raw_profile':P,'ball':[0,0],'lie':'tee','aim':[0,6000],'seed':1234,'shot_index':1}
rows=[]
for name,changes in [
    ('straight',{}),('next_shot',{'shot_index':2}),
    ('water',{'raw_hole':{**H,'features':H['features']+[{'t':'water','rect':[-10,55,10,65]}]}}),
    ('ob',{'raw_hole':{**H,'features':H['features']+[{'t':'ob','rect':[-10,55,10,65]}]}}),
    ('tree',{'raw_hole':{**H,'features':H['features']+[{'t':'tree','at':[[0,10]]}]}}),
    ('putt',{'ball':[0,9500],'lie':'green','aim':[0,10000],'style':'putt'}),
    ('fast_putt',{'ball':[0,9500],'lie':'green','aim':[0,11000],'style':'putt','raw_profile':{**P,'touch':1000}}),
    ('recovery',{'ball':[3000,5000],'lie':'rough','aim':[0,9000],'style':'safe_recovery'}),
    ('pressure',{'pressure_pm':150}),('overreach',{'aim':[0,50000]}),
    ('diagonal',{'aim':[1000,6000]}),
    ('putt_water_path',{'ball':[0,9500],'lie':'green','aim':[0,10000],'style':'putt','raw_hole':{**H,'features':H['features']+[{'t':'water','rect':[-5,96,5,97]}]}})
]:
    inputs=copy.deepcopy({**BASE,**changes})
    rows.append({'name':name,'inputs':inputs,'expected':shot(**inputs)})
Path(__file__).with_name('shot_golden.json').write_text(json.dumps({'model':VERSION,'cases':rows},indent=2)+'\n')
