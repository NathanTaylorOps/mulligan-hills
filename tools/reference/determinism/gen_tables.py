"""Generate game/core/mh_trig_table.gd from the reference tables.
Run: python3 tools/reference/determinism/gen_tables.py"""
import os
from mh_trig import SIN_Q, ATAN_T

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
OUT = os.path.join(ROOT, "game", "core", "mh_trig_table.gd")


def fmt(name, vals):
    lines = []
    for i in range(0, len(vals), 16):
        lines.append("\t" + ", ".join(str(v) for v in vals[i:i + 16]))
    return "const %s: Array = [\n%s\n]\n" % (name, ",\n".join(lines))


def main():
    with open(OUT, "w", newline="\n") as f:
        f.write("# GENERATED FILE. Do not edit. Source: tools/reference/determinism/gen_tables.py\n")
        f.write("# SIN_QUARTER[i] = round(sin(i * pi / 512) * 65536), i = 0..256 (first quarter turn, Q16.16).\n")
        f.write("# ATAN_OCTANT[i] = round(atan(i / 256) / (2 pi) * 65536), i = 0..256 (brads16, 0..8192).\n")
        f.write("class_name MHTrigTable\nextends RefCounted\n\n")
        f.write(fmt("SIN_QUARTER", SIN_Q))
        f.write("\n")
        f.write(fmt("ATAN_OCTANT", ATAN_T))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
