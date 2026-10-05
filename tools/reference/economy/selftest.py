"""Self-checks for the Python economy reference. Run: python3 tools/reference/economy/selftest.py"""
import mh_economy as E
import sim

P = sim.load()
UP = sim.UPK


def main():
    # hourly split sums to the daily amount
    for d in (0, 1, 7, 10, 12345, 999999):
        assert sum(E.split_hour(d, h) for h in range(E.HOURS_PER_DAY)) == d
    # a quiet course pays its upkeep exactly over a day and ledger arithmetic holds
    e = E.Economy(P, UP)
    e.tiers[2] = 1
    e.ext_permille = 0
    up = e.daily_upkeep()
    paid = 0
    for _ in range(E.HOURS_PER_DAY):
        paid += e.tick_hour()["upkeep_paid"]
    assert paid == up, (paid, up)
    # cash never negative through spend
    e = E.Economy(P, UP)
    for i in range(100):
        e.spend(137000 + i)
        assert e.cash >= 0
    # prices follow DEC-050 and every tier adds at least the floor
    for b in sim.BIDS:
        for t in range(5):
            assert P["price_dollars"][b][t] == P["payback_targets_days"][t] * P["added_daily_income_dollars"][b][t]
            assert P["added_daily_income_dollars"][b][t] >= P["added_floor_dollars"]
    # file targets equal params targets
    for i in range(len(sim.BIDS)):
        assert sim.TARGETS_FILE[i] == P["payback_targets_days"], sim.BIDS[i]
    # parcel schedule sanity (the shipped schedule is 8,000 growing 15 percent, integer steps)
    assert E.parcel_cost_cents(25000, 130, 0) == 2500000
    assert sim.LAND["parcel_base_cost"] == 8000 and sim.LAND["parcel_growth_pct"] == 115
    assert [E.parcel_cost_cents(8000, 115, n) // 100 for n in range(4)] == [8000, 9200, 10580, 12167]
    # DEC-065: economy tournament constants equal the host cost in tournaments.json, and revenue is below cost at the
    # Clubhouse tiers a club has when it first qualifies (tournaments are a net cost, not a profit engine)
    assert P["core"]["tournament_cost_cents"] == sim.TLEVELS["local"]["host_cost"] * 100 == 2500000
    assert P["core"]["tournament_regional_cost_cents"] == sim.TLEVELS["regional"]["host_cost"] * 100 == 6000000
    assert sim.tournament_revenue_dollars("local", 3) == 14850
    assert sim.tournament_revenue_dollars("regional", 3) == 38300
    for lvl in sim.TLEVELS:
        for ch in (3, 4):
            if sim.TLEVELS[lvl]["entry"]["min_spectator_capacity"] <= sim.TCAP[ch - 1]:
                assert sim.tournament_revenue_dollars(lvl, ch) < sim.TLEVELS[lvl]["host_cost"], (lvl, ch)
    # renovation sink: costs grow, stop at the maximum, and are only available on a finished course
    c = P["core"]
    costs = [E.renovation_cost_cents(P, n) for n in range(c["renov_max_levels"] + 1)]
    assert all(costs[i] < costs[i + 1] for i in range(c["renov_max_levels"] - 1)), costs
    assert costs[-1] == 0 and E.renovation_cost_cents(P, -1) == 0
    e = E.Economy(P, UP)
    e.cash = 10 ** 12
    assert e.purchase_renovation() == E.ERR_NOT_AVAILABLE
    e.holes = 18
    e.tiers = [5] * 9 + [3]
    assert e.purchase_renovation() == E.ERR_NOT_AVAILABLE
    e.tiers = [4] * 10
    assert e.purchase_renovation() == E.ERR_NOT_AVAILABLE and e.renovation == 0
    e.tiers = [5] * 10
    assert e.purchase_renovation() == E.OK and e.renovation == 1 and e.cash == 10 ** 12 - costs[0]
    for _ in range(c["renov_max_levels"] + 3):
        e.purchase_renovation()
    assert e.renovation == c["renov_max_levels"] and e.renovation_available() is False
    # renovation adds demand and upkeep to the day estimate
    base = E.day_estimate(P, UP, [5] * 10, 18, 15, 66, 300000, 4000)
    reno = E.day_estimate(P, UP, [5] * 10, 18, 15, 66, 300000, 4000, 1000, 1000, 3)
    assert reno["arrivals_milli"] > base["arrivals_milli"] and reno["upkeep"] == base["upkeep"] + 3 * c["renov_upkeep_cents_per_level"]
    # Mandatory losses carry debt but use the same bankruptcy policy as upkeep.
    e = E.Economy(P, UP)
    e.cash = 50
    assert e.incur_loss(100) == E.OK and e.cash == 0 and e.arrears == 50 and not e.bankrupt
    assert e.incur_loss(-1) == E.ERR_INVALID and e.arrears == 50
    print("economy selftest OK")


if __name__ == "__main__":
    main()
