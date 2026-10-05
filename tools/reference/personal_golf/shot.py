"""Versioned personal shot reference; no engine physics or official sim mutation."""
import copy
import sys
from pathlib import Path
from math import isqrt
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'rating'))
sys.path.insert(0, str(HERE.parent / 'determinism'))
import rating_core as core
from mh_rng import Pcg32
from model import envelope, integer, profile

VERSION = 'MHPERSONAL-SHOT-0.1'
LIE_NAMES = ('tee','fairway','fringe','rough','deep','bunker','green','water','ob')


def geometry(raw):
    if type(raw) is not dict:
        raise ValueError('hole object')
    integer(raw.get('slot_id',1),1,18)
    for key in ('tee_z_mm','green_z_mm'):
        integer(raw.get(key,0),-2147483648,2147483647)
    for key,size in (('tee',2),('green',3)):
        coords=raw.get(key)
        if type(coords) is not list or len(coords)!=size: raise ValueError('hole coordinates')
        for v in coords: integer(v,-1200,1200)
    features=raw.get('features')
    if type(features) is not list or len(features)>3000:
        raise ValueError('features')
    for f in features:
        if type(f) is not dict or type(f.get('t')) is not str:
            raise ValueError('feature type')
        shapes=[key for key in ('rect','circle','at') if key in f]
        if 'count' in f: integer(f['count'],0,2147483647)
        for key in shapes:
            coords=f[key]
            if type(coords) is not list: raise ValueError('feature coordinates')
            if key=='at':
                for pair in coords:
                    if type(pair) is not list or len(pair)!=2: raise ValueError('feature points')
                    for v in pair: integer(v,-1200,1200)
            else:
                for v in coords: integer(v,-1200,1200)
        if len(shapes)>1:
            raise ValueError('ambiguous feature shape')
        if f['t']=='tree' and (shapes not in (['at'],['rect']) or (shapes==['rect'] and 'count' not in f)):
            raise ValueError('tree shape/count')
    saved = copy.deepcopy(raw)
    ok, reason = core.validate_input({'schema':1,'engine':core.ENGINE,'hole':saved})
    if not ok:
        raise ValueError(reason)
    hole = core.Hole(saved)
    if not hole.valid:
        raise ValueError('invalid hole')
    return hole


def position(raw):
    if type(raw) not in (list, tuple) or len(raw) != 2:
        raise ValueError('position')
    return tuple(integer(x,-120000,120000) for x in raw)


def starting_lie(hole, ball, lie):
    if type(lie) is not str or lie not in LIE_NAMES[:7]:
        raise ValueError('starting lie')
    actual = hole.lie_at(ball)
    if actual in (core.LIE_WATER, core.LIE_OB):
        raise ValueError('hazard start')
    if lie == 'tee':
        if ball != hole.tee: raise ValueError('tee position')
    elif lie == 'deep' and actual != core.LIE_DEEP:
        if actual == core.LIE_GREEN or not any(core.dist(*ball,*t)<=300 for t in hole.trees):
            raise ValueError('deep backoff')
    elif LIE_NAMES[actual] != lie:
        raise ValueError('lie mismatch')


def preview(raw_hole, raw_profile, ball, lie, aim, style='straight', pressure_pm=0):
    hole = geometry(raw_hole)
    p = profile(raw_profile)
    ball, aim = position(ball), position(aim)
    starting_lie(hole,ball,lie)
    _,_,distance = core.unit(aim[0]-ball[0],aim[1]-ball[1])
    integer(distance,1,120000)
    club = -1 if style == 'putt' else 0
    selected = None
    for i in range(11,-1,-1):
        candidate = envelope(p,distance,core.CLUB_BASE[i]*100,lie,style,pressure_pm)
        selected = candidate
        if style == 'putt' or candidate['carry_max_cy'] >= distance:
            if style != 'putt': club=i
            break
    return {**selected,'club':club}


def cross(a,b,c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def segments_touch(a,b,c,d):
    if max(a[0],b[0])<min(c[0],d[0]) or max(c[0],d[0])<min(a[0],b[0]): return False
    if max(a[1],b[1])<min(c[1],d[1]) or max(c[1],d[1])<min(a[1],b[1]): return False
    def opposite_or_zero(x,y):
        return x==0 or y==0 or (x<0)!=(y<0)
    return opposite_or_zero(cross(a,b,c),cross(a,b,d)) and opposite_or_zero(cross(c,d,a),cross(c,d,b))


def hazard_segment(hole,a,b):
    # Inclusive primitive boundaries, including zero-width strips: never jump hazards.
    for kind,code in (('ob',2),('water',1)):
        for x0,y0,x1,y1 in hole.rects[kind]:
            if (x0<=a[0]<=x1 and y0<=a[1]<=y1) or (x0<=b[0]<=x1 and y0<=b[1]<=y1): return code
            corners=((x0,y0),(x1,y0),(x1,y1),(x0,y1))
            if any(segments_touch(a,b,corners[i],corners[(i+1)%4]) for i in range(4)): return code
        for cx,cy,r in hole.circles[kind]:
            dx,dy=b[0]-a[0],b[1]-a[1]; length2=dx*dx+dy*dy
            dot=(cx-a[0])*dx+(cy-a[1])*dy
            if length2==0 or dot<=0:
                hit=(cx-a[0])**2+(cy-a[1])**2<=r*r
            elif dot>=length2:
                hit=(cx-b[0])**2+(cy-b[1])**2<=r*r
            else:
                hit=cross(a,b,(cx,cy))**2<=r*r*length2
            if hit:return code
    return 0


def shot(raw_hole, raw_profile, ball, lie, aim, seed, shot_index, style='straight', pressure_pm=0):
    integer(seed,0,0xFFFFFFFF); integer(shot_index,1,1000000)
    env = preview(raw_hole,raw_profile,ball,lie,aim,style,pressure_pm)
    hole = geometry(raw_hole)
    ball,aim = position(ball),position(aim)
    ux,uy,_=core.unit(aim[0]-ball[0],aim[1]-ball[1])
    lateral=Pcg32(seed,shot_index*8).gauss_q16()*env['lateral_scale_cy']//65536
    depth=Pcg32(seed,shot_index*8+1).gauss_q16()*env['depth_scale_cy']//65536
    along=max(0,env['effective_cy']+depth)
    destination=(ball[0]+core.rdiv(ux*along-uy*lateral,1024),ball[1]+core.rdiv(uy*along+ux*lateral,1024))
    tree=False; holed=False
    if style == 'putt':
        distance=core.dist(*ball,*destination)
        steps=max(1,(distance+24)//25)
        points=[]
        nearest=None
        for i in range(1,steps+1):
            pt=(ball[0]+core.rdiv((destination[0]-ball[0])*i,steps),ball[1]+core.rdiv((destination[1]-ball[1])*i,steps))
            points.append(pt)
            cup_dist=core.dist(*pt,*hole.gc)
            if nearest is None or cup_dist<nearest[0]: nearest=(cup_dist,core.dist(*ball,*pt),i)
        capture_index=nearest[2] if nearest[0]<=15 and distance<=nearest[1]+100 else -1
        previous=ball
        for i,pt in enumerate(points,1):
            crossing=hazard_segment(hole,previous,pt)
            if crossing:
                return result(ball,lie,env['club'],1,crossing,False,False,shot_index)
            previous=pt
            loc=hole.lie_at(pt)
            if loc in (core.LIE_WATER,core.LIE_OB):
                return result(ball,lie,env['club'],1,1 if loc==core.LIE_WATER else 2,False,False,shot_index)
            if i==capture_index:
                return result(hole.gc,'green',env['club'],0,0,False,True,shot_index)
    else:
        cutoff=1000 if style=='safe_recovery' else core.TMAX[env['club']]
        hit=hole.tree_hit(ball,destination,cutoff)
        if hit is not None:
            tree=True
            _,hx,hy=hit
            bx,by,d=core.unit(hx-ball[0],hy-ball[1]); back=min(d,100)
            destination=(hx-bx*back//1024,hy-by*back//1024)
    loc=hole.lie_at(destination)
    if loc in (core.LIE_WATER,core.LIE_OB):
        return result(ball,lie,env['club'],1,1 if loc==core.LIE_WATER else 2,tree,False,shot_index)
    if tree and loc!=core.LIE_GREEN: loc=core.LIE_DEEP
    return result(destination,LIE_NAMES[loc],env['club'],0,0,tree,holed,shot_index)


def result(ball,lie,club,penalty,kind,tree,holed,index):
    return {'model':VERSION,'x':ball[0],'y':ball[1],'lie':lie,'club':club,'penalty':penalty,'penalty_kind':kind,'tree':tree,'holed':holed,'shot_index':index}
