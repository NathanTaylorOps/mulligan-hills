#!/usr/bin/env bash
# bench_summary.sh DIR [GODOT_EXIT_CODE] : Markdown table of every *.json in DIR plus a
# PNG list, appended to the job summary. Exit 1 if there is no JSON and no PNG.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
dir="${1:?usage: bench_summary.sh DIR [rc]}"
rc="${2:-0}"
set +e
py - "$dir" "$rc" <<'PY' | summary
import sys, os, glob, json
d, rc = sys.argv[1], sys.argv[2]
pngs = sorted(glob.glob(os.path.join(d, "*.png")))
jsons = sorted(glob.glob(os.path.join(d, "*.json")))
print("## Bench results\n")
print("Godot exit code: `%s`; PNG files: %d; JSON files: %d\n" % (rc, len(pngs), len(jsons)))
def flat(v, p=""):
    if isinstance(v, dict):
        r = {}
        for k in v: r.update(flat(v[k], p + str(k) + "."))
        return r
    if isinstance(v, list):
        return {p.rstrip("."): json.dumps(v)[:80]}
    return {p.rstrip("."): v}
def fmt(x):
    if isinstance(x, float): return ("%.3f" % x).rstrip("0").rstrip(".")
    return str(x).replace("|", "/")
def table(rows):
    cols = []
    for r in rows:
        for k in r:
            if k not in cols: cols.append(k)
    print("| " + " | ".join(cols) + " |")
    print("| " + " | ".join("---" for _ in cols) + " |")
    for r in rows: print("| " + " | ".join(fmt(r.get(c, "")) for c in cols) + " |")
    print()
for jf in jsons:
    print("### %s\n" % os.path.basename(jf))
    try: data = json.load(open(jf, encoding="utf-8"))
    except Exception as e:
        print("Could not parse: %s\n" % e); continue
    rows = None
    if isinstance(data, list) and data and all(isinstance(x, dict) for x in data):
        rows = [flat(x) for x in data]
    elif isinstance(data, dict):
        for k, v in data.items():
            if isinstance(v, list) and v and all(isinstance(x, dict) for x in v):
                rows = [flat(x) for x in v]; break
    if rows:
        table(rows)
        if isinstance(data, dict):
            rest = {k: v for k, v in data.items() if not (isinstance(v, list) and v and all(isinstance(x, dict) for x in v))}
            if rest: table([flat(rest)])
    else:
        f = flat(data)
        print("| key | value |\n| --- | --- |")
        for k in f: print("| %s | %s |" % (k, fmt(f[k])))
        print()
if pngs:
    print("### Screenshots\n")
    for p in pngs: print("- `%s` (%d KB)" % (os.path.basename(p), os.path.getsize(p) // 1024))
    print("\nDownload the `bench-*` artifact to view them.")
if not pngs and not jsons:
    print("**Bench produced no PNG and no JSON.** Check bench.log in the artifact.")
    sys.exit(1)
PY
exit "${PIPESTATUS[0]}"
