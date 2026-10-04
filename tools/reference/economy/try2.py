import sys, json, sim, tune
def setup(o):
    sim.CORE["wtp_base_per_hole_cents"] = o.get("wb",20)
    sim.CORE["wtp_per_rating_per_hole_cents"] = o.get("wr",6)
    sim.CORE["parcel_base_cents"]=o.get("pb",2500000)
    sim.CORE["parcel_growth_permille"]=o.get("pg",1300)
    sim.apply_scale(anc=o.get("anc",.3), flat=o.get("flat",.3), dem=o.get("dem",.25))
    sim.T["arrivals_per_hole"] = o.get("aph",5.0)
    sim.T["arrivals_base"] = o.get("ab",20.0)
    sim.T["hole_cost_base_cents"]=o.get("hb",1000000)
    sim.T["hole_cost_growth_permille"]=o.get("hg",1080)
    sim.T["hole_upkeep_cents"]=o.get("hu",3000)
    sim.T["parcel_upkeep_cents"]=o.get("pu",1200)
    if "targets" in o: sim.T["targets"]=o["targets"]
if __name__=="__main__":
    o=json.loads(sys.argv[1]) if len(sys.argv)>1 else {}
    setup(o)
    tune.milestones("t2", n=o.get("n",24), days=o.get("days",900))
