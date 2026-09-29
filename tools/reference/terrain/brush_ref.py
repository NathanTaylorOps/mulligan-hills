#!/usr/bin/env python3
"""Python reference for the Mulligan Hills terrain brush integer math.

Mirrors game/terrain/mh_brush.gd and mh_height_grid.gd exactly. No floats anywhere.
Usage:
  python3 brush_ref.py            self-test, then (re)generate the golden JSON
  python3 brush_ref.py --check    self-test, then verify the golden JSON is up to date
"""
import json
import os
import sys

MIN_H, MAX_H = -32768, 32767
FNV_OFFSET, FNV_PRIME = 2166136261, 16777619
RAISE, LOWER, SMOOTH, FLATTEN = 0, 1, 2, 3
HERE = os.path.dirname(os.path.abspath(__file__))
GOLDEN = os.path.normpath(os.path.join(HERE, "..", "..", "..", "game", "tests", "terrain", "golden", "brush_golden.json"))


def idiv(a, b):
    """Integer division truncating toward zero (matches GDScript/C++)."""
    return a // b if a >= 0 else -((-a) // b)


def falloff_table():
    return [(3 * t * t * 1024 - 2 * t * t * t) // 1048576 for t in range(1025)]


FALLOFF = falloff_table()


def fnv_values(values):
    h = FNV_OFFSET
    for v in values:
        u = v + 32768
        h = ((h ^ (u & 255)) * FNV_PRIME) & 0xFFFFFFFF
        h = ((h ^ (u >> 8)) * FNV_PRIME) & 0xFFFFFFFF
    return h


class Grid:
    def __init__(self, cells):
        self.cells = cells
        self.sx = cells + 1
        self.h = [0] * (self.sx * self.sx)

    def fill_lcg_noise(self, seed, amp):
        state = seed & 0x7FFFFFFF
        span = 2 * amp + 1
        for i in range(len(self.h)):
            state = (state * 1103515245 + 12345) & 0x7FFFFFFF
            self.h[i] = max(MIN_H, min(MAX_H, ((state >> 8) % span) - amp))

    def hash(self):
        return fnv_values(self.h)


def apply_dab(g, mode, cx, cy, radius, strength, level):
    r = max(radius, 1)
    sx = g.sx
    x0, x1 = max(cx - r, 0), min(cx + r, sx - 1)
    y0, y1 = max(cy - r, 0), min(cy + r, sx - 1)
    if x0 > x1 or y0 > y1:
        return
    r2 = r * r
    out = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if d2 > r2:
                continue
            w = FALLOFF[((r2 - d2) * 1024) // r2]
            if w == 0:
                continue
            i = y * sx + x
            h = g.h[i]
            nh = h
            if mode == RAISE:
                nh = h + (strength * w + 512) // 1024
            elif mode == LOWER:
                nh = h - (strength * w + 512) // 1024
            elif mode == SMOOTH:
                s = c = 0
                for ny in range(max(y - 1, 0), min(y + 1, sx - 1) + 1):
                    for nx in range(max(x - 1, 0), min(x + 1, sx - 1) + 1):
                        s += g.h[ny * sx + nx] + 32768
                        c += 1
                avg = s // c - 32768
                nh = h + idiv((avg - h) * w * strength, 1024000)
            elif mode == FLATTEN:
                nh = h + idiv((level - h) * w * strength, 1024000)
            nh = max(MIN_H, min(MAX_H, nh))
            if nh != h:
                out.append((i, nh))
    for i, v in out:
        g.h[i] = v


def build_ops():
    ops = [
        # hand-written edge cases: corners, clipping, big radius, saturation, negative smooth/flatten
        (RAISE, 32, 32, 10, 500, 0), (LOWER, 32, 32, 6, 200, 0), (SMOOTH, 32, 32, 12, 800, 0),
        (FLATTEN, 20, 20, 9, 700, 1234), (FLATTEN, 40, 40, 9, 1000, -3000),
        (RAISE, 0, 0, 8, 900, 0), (LOWER, 64, 64, 8, 900, 0), (SMOOTH, 0, 64, 7, 1000, 0),
        (RAISE, 10, 50, 1, 300, 0), (LOWER, -3, 30, 6, 400, 0), (RAISE, 70, 30, 6, 400, 0),
        (RAISE, 32, 32, 30, 40000, 0), (LOWER, 32, 32, 30, 40000, 0),
        (SMOOTH, 32, 32, 40, 1000, 0), (FLATTEN, 32, 32, 40, 1000, 0),
    ]
    state = 424242
    for _ in range(40):
        vals = []
        for _k in range(5):
            state = (state * 1103515245 + 12345) & 0x7FFFFFFF
            vals.append(state >> 8)
        mode = vals[0] % 4
        cx, cy = vals[1] % 65, vals[2] % 65
        radius = 1 + vals[3] % 14
        strength = (50 + vals[4] % 400) if mode < 2 else (100 + vals[4] % 900)
        level = (vals[4] >> 5) % 4001 - 2000
        ops.append((mode, cx, cy, radius, strength, level))
    return ops


def generate():
    cells, seed, amp = 64, 12345, 1000
    g = Grid(cells)
    g.fill_lcg_noise(seed, amp)
    doc = {
        "version": 1,
        "cells": cells, "seed": seed, "amplitude": amp,
        "falloff_fnv": fnv_values(FALLOFF),
        "falloff_samples": {str(t): FALLOFF[t] for t in (0, 1, 100, 256, 512, 768, 1000, 1023, 1024)},
        "initial_hash": g.hash(),
        "ops": [],
    }
    for mode, cx, cy, radius, strength, level in build_ops():
        apply_dab(g, mode, cx, cy, radius, strength, level)
        doc["ops"].append({"mode": mode, "cx": cx, "cy": cy, "radius": radius, "strength": strength,
                           "level": level, "hash_after": g.hash()})
    doc["final_hash"] = g.hash()
    doc["probe"] = [[x, y, g.h[y * g.sx + x]] for (x, y) in ((0, 0), (32, 32), (64, 64), (10, 50), (63, 1), (1, 63))]
    return doc


def selftest():
    # FNV-1a known vector on bytes: "a" -> 0xE40C292C (validates constants)
    h = FNV_OFFSET
    h = ((h ^ 0x61) * FNV_PRIME) & 0xFFFFFFFF
    assert h == 0xE40C292C
    assert FALLOFF[0] == 0 and FALLOFF[1024] == 1024 and FALLOFF[512] == 512
    assert all(FALLOFF[i] <= FALLOFF[i + 1] for i in range(1024))
    assert idiv(-7, 2) == -3 and idiv(7, 2) == 3 and idiv(-1, 1024000) == 0
    # raise then lower same dab returns to (near) start at centre; centre delta exactly strength
    g = Grid(16)
    apply_dab(g, RAISE, 8, 8, 5, 300, 0)
    assert g.h[8 * g.sx + 8] == 300
    apply_dab(g, LOWER, 8, 8, 5, 300, 0)
    assert all(v == 0 for v in g.h)
    # flatten at 1000 per mille pulls centre exactly to level
    g.fill_lcg_noise(1, 800)
    apply_dab(g, FLATTEN, 8, 8, 4, 1000, 250)
    assert g.h[8 * g.sx + 8] == 250
    # saturation clamps
    apply_dab(g, RAISE, 8, 8, 3, 60000, 0)
    assert g.h[8 * g.sx + 8] == MAX_H
    # smooth never increases the max nor decreases the min inside the footprint neighbourhood
    g.fill_lcg_noise(9, 1000)
    lo, hi = min(g.h), max(g.h)
    apply_dab(g, SMOOTH, 8, 8, 6, 1000, 0)
    assert lo <= min(g.h) and max(g.h) <= hi
    # determinism
    assert generate() == generate()
    print("self-test OK")


def main():
    selftest()
    doc = generate()
    text = json.dumps(doc, indent=1, sort_keys=True) + "\n"
    if "--check" in sys.argv:
        with open(GOLDEN) as f:
            assert f.read() == text, "golden JSON is stale; rerun without --check"
        print("golden up to date:", GOLDEN)
    else:
        os.makedirs(os.path.dirname(GOLDEN), exist_ok=True)
        with open(GOLDEN, "w") as f:
            f.write(text)
        print("wrote", GOLDEN, "ops:", len(doc["ops"]), "final_hash:", doc["final_hash"])


if __name__ == "__main__":
    main()
