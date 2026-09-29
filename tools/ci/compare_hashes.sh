#!/usr/bin/env bash
# compare_hashes.sh DIR : DIR contains one sub-folder per platform, each with hashes.txt
# (lines MH_HASH:label=hex). Fails on any difference, on a missing file, or on zero hashes.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
dir="${1:?usage: compare_hashes.sh DIR}"
set +e
py - "$dir" <<'PY' | summary
import sys, os, glob
d = sys.argv[1]
plat = {}
for f in sorted(glob.glob(os.path.join(d, "*", "hashes.txt"))):
    name = os.path.basename(os.path.dirname(f))
    plat[name] = dict(l.strip()[len("MH_HASH:"):].split("=", 1) for l in open(f) if l.startswith("MH_HASH:"))
print("## Determinism comparison\n")
if len(plat) < 2:
    print("**FAIL:** need hashes from at least 2 platforms, found %d (%s)." % (len(plat), ", ".join(plat) or "none")); sys.exit(1)
labels = sorted(set().union(*[set(v) for v in plat.values()]))
if not labels:
    print("**FAIL:** no `MH_HASH:<label>=<hex>` lines were printed by the tests on any platform."); sys.exit(1)
names = sorted(plat)
print("| label | " + " | ".join(names) + " | match |")
print("| --- | " + " | ".join("---" for _ in names) + " | --- |")
bad = 0
for l in labels:
    vals = [plat[n].get(l, "MISSING") for n in names]
    ok = len(set(vals)) == 1 and vals[0] != "MISSING"
    bad += 0 if ok else 1
    print("| %s | " % l + " | ".join("`%s`" % v[:16] for v in vals) + " | %s |" % ("yes" if ok else "**NO**"))
print("\n**%s** (%d labels, %d mismatches)" % ("PASS" if not bad else "FAIL", len(labels), bad))
sys.exit(1 if bad else 0)
PY
exit "${PIPESTATUS[0]}"
