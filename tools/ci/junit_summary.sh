#!/usr/bin/env bash
# junit_summary.sh DIR : parse every results.xml under DIR, print a Markdown summary to
# the job summary, exit 1 if any failure/error or if zero tests were found.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
dir="${1:?usage: junit_summary.sh DIR}"
set +e
py - "$dir" <<'PY' | summary
import sys, os, glob
import xml.etree.ElementTree as ET
d = sys.argv[1]
files = sorted(glob.glob(os.path.join(d, "**", "*.xml"), recursive=True))
tot = fail = skip = 0
bad, suites = [], {}
for f in files:
    try: root = ET.parse(f).getroot()
    except ET.ParseError: continue
    for tc in root.iter("testcase"):
        tot += 1
        suite = tc.get("classname") or "?"
        s = suites.setdefault(suite, [0, 0, 0]); s[0] += 1
        fl = tc.find("failure"); er = tc.find("error"); sk = tc.find("skipped")
        if fl is not None or er is not None:
            fail += 1; s[1] += 1
            n = fl if fl is not None else er
            bad.append((suite, tc.get("name"), (n.get("message") or n.text or "").strip().replace("\n", " ")[:300]))
        elif sk is not None:
            skip += 1; s[2] += 1
status = "PASS" if tot > 0 and fail == 0 else "FAIL"
print("## Test results: %s" % status)
print()
print("| tests | failed | skipped | result files |")
print("| ---: | ---: | ---: | ---: |")
print("| %d | %d | %d | %d |" % (tot, fail, skip, len(files)))
if tot == 0:
    print("\n**No test cases found.** gdUnit4 produced no JUnit XML: check test.log (plugin missing, wrong test path, or crash).")
if suites:
    print("\n| suite | tests | failed | skipped |\n| --- | ---: | ---: | ---: |")
    for k in sorted(suites): print("| %s | %d | %d | %d |" % (k, *suites[k]))
if bad:
    print("\n### Failures\n")
    for s, n, m in bad[:50]: print("- `%s` / `%s`: %s" % (s, n, m))
sys.exit(0 if status == "PASS" else 1)
PY
rc="${PIPESTATUS[0]}"
exit "$rc"
