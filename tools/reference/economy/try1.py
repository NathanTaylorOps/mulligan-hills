import sys, sim, tune
sim.CORE["wtp_base_per_hole_cents"] = 20
sim.CORE["wtp_per_rating_per_hole_cents"] = 6
sim.apply_scale(anc=0.4, flat=0.4, dem=0.4)
sim.T["arrivals_per_hole"] = 7.0
sim.T["arrivals_base"] = 20.0
sim.T["hole_cost_base_cents"]=1000000
sim.T["hole_cost_growth_permille"]=1080
sim.T["hole_upkeep_cents"]=3000
sim.T["parcel_upkeep_cents"]=1200
tune.milestones("try1", n=24, days=900)
