import sys, json
import sim
from sim import *

def milestones(label, n=30, days=1000, archs=("typical",), quiet=False):
    price, added = sim.compute_prices()
    ppm = sim.CORE["upkeep_ppm_per_day"]
    for arch in archs:
        rs = [sim.run(1000 + i, arch, days, price, ppm) for i in range(n)]
        # restrict to skill >= 62 and < 62 separately
        for name, sel in (("skill>=64", [r for r in rs if r["skill"] >= 64]), ("skill<64", [r for r in rs if r["skill"] < 64])):
            if not sel: continue
            line = []
            for k in range(1, 6):
                a = [r["first_any"][k] for r in sel if k in r["first_any"]]
                al = [r["all"][k] for r in sel if k in r["all"]]
                line.append("T%d any %s all %s (%d/%d)" % (k, sim.pct(a, .5), sim.pct(al, .5), len(al), len(sel)))
            sn = [r["snap"] for r in sel]
            def med(d, i):
                v = [x[d][i] for x in sn if d in x]
                return sim.pct(v, .5) if v else None
            print(label, arch, name, "|", "; ".join(line))
            print("    cash d60/180/360/720: %s; net/day d60/180/360/720: %s; h18 %s; m50 %s; bankrupt %d quit %d" % (
                [ (med(d,0) or 0)//100 for d in (60,180,360,720)], [(med(d,2) or 0)//100 for d in (60,180,360,720)],
                sim.pct([r["h18"] for r in sel if r["h18"] is not None], .5), sim.pct([r["m50"] for r in sel if r["m50"] is not None], .5),
                sum(1 for r in sel if r["bankrupt"]), sum(1 for r in sel if r["quit"])))
    return price, added
if __name__ == "__main__":
    sim.CORE["wtp_base_per_hole_cents"] = 20
    sim.CORE["wtp_per_rating_per_hole_cents"] = 6
    sim.apply_scale(anc=0.5, flat=0.6)
    p, a = milestones("scaled")
    for b in sim.BIDS: print(b, [x//100 for x in p[b]])
