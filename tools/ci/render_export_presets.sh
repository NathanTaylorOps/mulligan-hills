#!/usr/bin/env bash
# Render game/export_presets.cfg from game/export_presets.cfg.template by replacing
# @@KEY@@ placeholders from the environment. The result is git-ignored: it may contain
# signing values on the runner. Never upload it as an artifact.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
tpl="$GAME_DIR/export_presets.cfg.template"
[ -f "$tpl" ] || tpl="$REPO_ROOT/game/export_presets.cfg.template"
[ -f "$tpl" ] || die "export_presets.cfg.template not found"
code="${MH_VERSION_CODE:-${GITHUB_RUN_NUMBER:-1}}"
export MH_VERSION_CODE="$code"
export MH_VERSION_NAME="${MH_VERSION_NAME:-0.0.$code}"
export MH_PACKAGE_ID="${MH_PACKAGE_ID:-com.mulliganhills.game}"
export MH_ANDROID_TARGET_SDK="${MH_ANDROID_TARGET_SDK:-$ANDROID_TARGET_SDK}"
export MH_ANDROID_RELEASE_KEYSTORE="${MH_ANDROID_RELEASE_KEYSTORE:-}"
export MH_ANDROID_RELEASE_USER="${MH_ANDROID_RELEASE_USER:-}"
export MH_ANDROID_RELEASE_PASSWORD="${MH_ANDROID_RELEASE_PASSWORD:-}"
export MH_APPLE_TEAM_ID="${MH_APPLE_TEAM_ID:-}"
py - "$tpl" "$GAME_DIR/export_presets.cfg" <<'PY'
import sys, os, re
src, dst = sys.argv[1:3]
t = open(src, encoding="utf-8").read()
def rep(m):
    k = m.group(1)
    if not k.startswith("MH_"): k = "MH_" + k
    if k not in os.environ:
        sys.exit("unknown placeholder @@%s@@ (set env %s or fix the template)" % (m.group(1), k))
    return os.environ[k]
out = re.sub(r"@@([A-Z0-9_]+)@@", rep, t)
open(dst, "w", encoding="utf-8").write(out)
print("rendered", dst)
PY
