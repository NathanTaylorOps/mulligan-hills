import sim
exec(open('try1.py').read().split('tune.milestones')[0])
s=sim.new_state(); s["holes"]=18; s["gp"]=12; s["op"]=4; s["rating"]=66.0
for b in sim.BIDS: s["tier"][b]=5
s["members"]=300
f=sim.best_fee(s); print("fee",f); m=sim.day_model(s,f); print({k:int(v) for k,v in m.items()})
s2=sim.new_state(); s2["holes"]=18; s2["gp"]=12; s2["rating"]=56.0
for b in sim.BIDS: s2["tier"][b]=3
s2["members"]=100
f=sim.best_fee(s2); print("fee",f); print({k:int(v) for k,v in sim.day_model(s2,f).items()})
