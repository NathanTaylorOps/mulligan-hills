#!/usr/bin/env python3
"""Python reference for the MHTerrainSave binary format (versions 1 and 2), golden fixture generator.

Mirrors game/terrain/mh_terrain_save.gd for UNCOMPRESSED bodies (flags = 0), which are byte-for-byte
reproducible (zstd output is not portable across libraries, so compressed files are not golden).
Fixture grid: 6 x 4 cells (7 x 5 samples, deliberately not square), cell size 1000 mm.
  heights[i]        = ((i * 7919) % 4001) - 2000, then sample 0 = -32768 and last sample = 32767
  v2 splat byte     = (texel * 7 + layer * 13 + 5) & 255      (11 layers per texel)
  v1 rgba byte      = (texel * 5 + channel * 29 + 3) & 255    (4 bytes per texel, R fairway G rough B sand A green)
Usage:
  python3 save_ref.py            regenerate the fixtures in game/tests/terrain/golden/
  python3 save_ref.py --check    verify the fixtures on disk are up to date (exit 1 if stale)
"""
import json
import os
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
GOLDEN_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "..", "game", "tests", "terrain", "golden"))
FNV_OFFSET, FNV_PRIME = 2166136261, 16777619
CELLS_X, CELLS_Y, CELL_MM = 6, 4, 1000
LAYERS = 11


def fnv_heights(values):
    h = FNV_OFFSET
    for v in values:
        u = v + 32768
        h = ((h ^ (u & 255)) * FNV_PRIME) & 0xFFFFFFFF
        h = ((h ^ (u >> 8)) * FNV_PRIME) & 0xFFFFFFFF
    return h


def fnv_bytes(data):
    h = FNV_OFFSET
    for b in data:
        h = ((h ^ b) * FNV_PRIME) & 0xFFFFFFFF
    return h


def heights():
    n = (CELLS_X + 1) * (CELLS_Y + 1)
    h = [((i * 7919) % 4001) - 2000 for i in range(n)]
    h[0] = -32768
    h[-1] = 32767
    return h


def wrap(version, inner):
    head = bytearray(20)
    head[0:4] = b"MHTS"
    struct.pack_into("<HHII", head, 4, version, 0, len(inner), len(inner))
    crc = zlib.crc32(bytes(head[0:16]) + inner) & 0xFFFFFFFF
    struct.pack_into("<I", head, 16, crc)
    return bytes(head) + inner


def v2_splat():
    n = (CELLS_X + 1) * (CELLS_Y + 1)
    return bytes(((t * 7 + l * 13 + 5) & 255) for t in range(n) for l in range(LAYERS))


def v1_rgba():
    n = (CELLS_X + 1) * (CELLS_Y + 1)
    return bytes(((t * 5 + c * 29 + 3) & 255) for t in range(n) for c in range(4))


def encode_v2():
    h = heights()
    sp = v2_splat()
    inner = struct.pack("<IIIII", CELLS_X, CELLS_Y, CELL_MM, fnv_heights(h), fnv_bytes(sp))
    inner += b"".join(struct.pack("<h", v) for v in h) + sp
    return wrap(2, inner)


def encode_v1():
    h = heights()
    inner = struct.pack("<IIII", CELLS_X, CELLS_Y, CELL_MM, fnv_heights(h))
    inner += b"".join(struct.pack("<h", v) for v in h) + v1_rgba()
    return wrap(1, inner)


def expected_json():
    return {
        "cells_x": CELLS_X, "cells_y": CELLS_Y, "cell_size_mm": CELL_MM,
        "height_hash": fnv_heights(heights()),
        "v2_splat_hash": fnv_bytes(v2_splat()),
        "v2_file_size": len(encode_v2()),
        "v1_file_size": len(encode_v1()),
        "v2_crc": struct.unpack_from("<I", encode_v2(), 16)[0],
        "v1_crc": struct.unpack_from("<I", encode_v1(), 16)[0],
    }


def files():
    return {
        "save_v1_6x4.mhts": encode_v1(),
        "save_v2_6x4.mhts": encode_v2(),
        "save_golden.json": (json.dumps(expected_json(), indent=2, sort_keys=True) + "\n").encode(),
    }


def selftest():
    assert zlib.crc32(b"123456789") == 0xCBF43926
    assert len(encode_v2()) == 20 + 20 + 35 * 2 + 35 * 11
    assert len(encode_v1()) == 20 + 16 + 35 * 2 + 35 * 4


def main():
    selftest()
    check = "--check" in sys.argv
    os.makedirs(GOLDEN_DIR, exist_ok=True)
    stale = False
    for name, data in files().items():
        path = os.path.join(GOLDEN_DIR, name)
        if check:
            if not os.path.exists(path) or open(path, "rb").read() != data:
                print("STALE:", name)
                stale = True
        else:
            open(path, "wb").write(data)
            print("wrote", path)
    if check:
        print("golden save fixtures are stale" if stale else "golden save fixtures OK")
        sys.exit(1 if stale else 0)


if __name__ == "__main__":
    main()
