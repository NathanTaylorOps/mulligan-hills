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
    # parcel schedule sanity
    assert E.parcel_cost_cents(25000, 130, 0) == 2500000
    print("economy selftest OK")


if __name__ == "__main__":
    main()
