"""Independent DEC-070 boundary arithmetic; no Godot or frame-loop implementation needed.

Token-backed scenarios state their effective 1x duration explicitly. Existing Godot tests check
event order and ledger draining; this verifies their integer minute/remainder expectations.
Run: python3 tools/reference/clock/check_clock_vectors.py
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]
PERIOD_US = 1_500_000_000
GAME_MINUTES = 660


def state(effective_us):
    return divmod(effective_us * GAME_MINUTES, PERIOD_US)


def main():
    clock = (ROOT / "game/core/clock/mh_game_clock.gd").read_text()
    assert int(re.search(r"const REAL_US_PER_DAY_1X: int = (\d+)", clock)[1]) == PERIOD_US
    cases = [
        (1_500_000_000, (660, 0)),
        (2_000_000, (0, 1_320_000_000)),
        (3_000_000, (1, 480_000_000)),
        (216000 * 16667, (1584, 47_520_000)),
        (300_000_000, (132, 0)),
        (60_000_000 * 2 + 1_000_000, (53, 360_000_000)),
        (45_000_000 * 8 + 5_000_000, (160, 900_000_000)),
        (90_000_000 * 4 + 10_000_000, (162, 1_200_000_000)),
        (120_000_000 + 8000 * 16667, (111, 701_760_000)),
        (480_000_000, (211, 300_000_000)),
        (10_000_000, (4, 600_000_000)),
        (120_000_000, (52, 1_200_000_000)),
        (188 * 8_000_000, (661, 1_140_000_000)),
    ]
    for elapsed, expected in cases:
        assert state(elapsed) == expected, (elapsed, state(elapsed), expected)
    # Legacy half-minute state converts to half a minute under the new denominator.
    assert 450_000_000 * PERIOD_US // 900_000_000 == 750_000_000
    assert PERIOD_US // 60_000_000 == 25
    print("clock boundary vectors OK (13 scenarios + legacy fraction)")


if __name__ == "__main__":
    main()
