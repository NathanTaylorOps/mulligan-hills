#!/usr/bin/env bash
# Run a bench scene under xvfb + Mesa software GL and collect PNGs and bench JSON.
# Env: SCENE (res://...tscn, required), GAME_PATH, GODOT_BIN, FRAMES (default 300),
#      RENDERER (compatibility|mobile, default compatibility), BENCH_TIMEOUT (secs, 900).
# The scene receives user args after "--": BENCH_ARGS (default matches game/bench/bench_scene.gd:
# --autostart --mode=quick --tier=medium --quit-after-bench) plus --out=<abs dir> --frames=<n>
# (unknown args are ignored by the scene). bench.json in --out or user:// is collected.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require_godot
SCENE="${SCENE:?SCENE must be a res:// scene path}"
FRAMES="${FRAMES:-300}"
BENCH_ARGS="${BENCH_ARGS:---autostart --mode=quick --tier=medium --quit-after-bench}"
SHOT_DELAYS="${SHOT_DELAYS:-6 12 20}"
RENDERER="${RENDERER:-compatibility}"
B="$OUT_DIR/bench"; rm -rf "$B"; mkdir -p "$B"
start_marker="$OUT_DIR/.bench-start"; touch "$start_marker"

case "$RENDERER" in
  compatibility) drv=opengl3; meth=gl_compatibility ;;
  mobile) drv=vulkan; meth=mobile ;;
  *) die "RENDERER must be compatibility or mobile" ;;
esac

export LIBGL_ALWAYS_SOFTWARE=1 GALLIUM_DRIVER=llvmpipe
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/xdg-runtime-$USER}"; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
if command -v glxinfo >/dev/null 2>&1; then
  xvfb-run -a -s "-screen 0 1280x720x24" glxinfo -B > "$B/glxinfo.txt" 2>&1 || true
fi

# Godot runs in the background so an external screenshot of the virtual display can be
# taken (imagemagick "import") at SHOT_DELAYS seconds: this works with any scene, even one
# that never saves a PNG itself. Scene-saved PNGs in --out or user:// are collected too.
export B GODOT_BIN GAME_DIR drv meth SCENE FRAMES BENCH_ARGS SHOT_DELAYS
set +e
timeout "${BENCH_TIMEOUT:-900}" xvfb-run -a -s "-screen 0 1280x720x24" bash -c '
  "$GODOT_BIN" --path "$GAME_DIR" --rendering-driver "$drv" --rendering-method "$meth" \
    --resolution 1280x720 --audio-driver Dummy "$SCENE" -- $BENCH_ARGS --out="$B" --frames="$FRAMES" \
    > "$B/bench.log" 2>&1 &
  gpid=$!
  n=0
  for d in $SHOT_DELAYS; do
    sleep "$d"
    if kill -0 "$gpid" 2>/dev/null; then
      n=$((n+1)); import -window root "$B/xvfb_shot_$n.png" 2>>"$B/shots.err" || true
    fi
  done
  wait "$gpid"
'
rc=$?

set -e
log "bench exit code: $rc"
tail -n 40 "$B/bench.log" >&2 || true

# Fallback: pick up files the scene wrote to user:// instead of --out.
ud="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata"
if [ -d "$ud" ]; then
  find "$ud" -type f \( -name '*.png' -o -name '*.json' \) -newer "$start_marker" 2>/dev/null | while read -r f; do
    cp -n "$f" "$B/" 2>/dev/null || true
  done
fi

"$CI_DIR/bench_summary.sh" "$B" "$rc"
if [ "$rc" -ne 0 ]; then log "bench run failed (exit $rc)"; exit "$rc"; fi
