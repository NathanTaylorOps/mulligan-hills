"""Writes the BASE economy_params.json (constants only). Run sim.py afterwards to derive the added-income and price
tables and to write the final file. Edit the numbers HERE or pass overrides to sim.tune(); never edit the JSON by hand
(it is regenerated)."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))

BASE = {
    "schema": "mh.economy_params",
    "version": 1,
    "hours_per_day": 11,
    "core": {
        "start_cash_cents": 5000000,
        "fee_min_cents": 500,
        "fee_max_cents": 25000,
        "fee_start_cents": 1500,
        "start_holes": 6,
        "start_parcels": 5,
        "start_rating": 34,
        "wtp_base_per_hole_cents": 10,
        "wtp_per_rating_per_hole_cents": 5,
        "arrivals_base_milli": 44000,
        "arrivals_per_hole_milli": 2000,
        "tee_groups_per_hour": 5,
        "tee_group_size_x10": 30,
        "hole_upkeep_cents": 6000,
        "parcel_upkeep_cents": 2500,
        "hole_cost_base_dollars": 5000,
        "hole_cost_growth_permille": 1100,
        "member_dues_cents": 300,
        "member_join_rate_permille": 60,
        "member_rating_floor": 28,
        "member_rating_span": 30,
        "bankrupt_arrears_days_x10": 20,
        "bankrupt_min_arrears_cents": 100000,
        "loan_upkeep_days": 10,
        "loan_min_cents": 500000,
        "loan_max_cents": 5000000,
        "loan_fee_permille": 0,
        "loan_repay_share_permille": 250,
        "loan_max_taken": 3,
        "loan_rep_penalty_permille": 150,
        "rep_floor_permille": 500,
        "rep_recover_per_day_permille": 3,
        "recovery_token_cost": 3,
        "recovery_holiday_days": 5,
        "tournament_cost_cents": 2500000,
        "tournament_regional_cost_cents": 6000000,
        "renov_base_dollars": 150000,
        "renov_growth_permille": 1300,
        "renov_max_levels": 12,
        "renov_min_tier": 4,
        "renov_dem_milli_per_level": 8000,
        "renov_upkeep_cents_per_level": 20000
    },
    "hour_profile": [6, 8, 9, 10, 10, 9, 9, 10, 10, 9, 6],
    "member_cap": [40, 80, 140, 220, 320],
    "payback_targets_days": [10, 12, 16, 50, 80],
    "ref_holes": [6, 8, 12, 16, 18],
    "ref_rating": [34, 36, 46, 56, 66],
    "building_ids": ["clubhouse", "pro_shop", "driving_range", "restaurant", "pool_spa", "cart_barn",
                     "maintenance", "lodging", "homes", "landmark"],
    # Design intent for building value (see sim.calibrate): net added income per day, in dollars, summed over the ten
    # buildings at each tier, split by these weights. The effect arrays below are RESULTS of calibration (integers).
    "calibration": {
        "tier_total_net_dollars": [450, 600, 900, 3500, 6000],
        "weights": {"clubhouse": 10, "pro_shop": 8, "driving_range": 7, "restaurant": 9, "pool_spa": 8,
                    "cart_barn": 3, "maintenance": 3, "lodging": 9, "homes": 10, "landmark": 12},
        "channels": {
            "clubhouse": [["dem", 100]],
            "pro_shop": [["anc", 100]],
            "driving_range": [["anc", 50], ["dem", 50]],
            "restaurant": [["anc", 100]],
            "pool_spa": [["flat", 70], ["dem", 30]],
            "cart_barn": [["anc", 60], ["dem", 40]],
            "maintenance": [["cut", 40], ["dem", 60]],
            "lodging": [["flat", 100]],
            "homes": [["flat", 100]],
            "landmark": [["dem", 100]]
        },
        "landmark_flat_from_tier": 3
    },
    "effects": {}
}


def write_base(path=None):
    path = path or os.path.join(HERE, "economy_params.json")
    with open(path, "w", newline="\n") as f:
        json.dump(BASE, f, indent=1)
        f.write("\n")


if __name__ == "__main__":
    write_base()
