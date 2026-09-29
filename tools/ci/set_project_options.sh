#!/usr/bin/env bash
# Patch game/project.godot for a CI build variant. All inputs optional, via env:
#   MH_RENDERER     compatibility | mobile   (both desktop and mobile feature overrides)
#   MH_MAIN_SCENE   res://path/to/scene.tscn  (becomes application/run/main_scene)
# Only touches the checked-out copy on the runner.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
pg="$GAME_DIR/project.godot"
[ -f "$pg" ] || die "no project.godot in $GAME_DIR"
case "${MH_RENDERER:-}" in
  "") ;;
  compatibility)
    set_ini "$pg" rendering renderer/rendering_method '"gl_compatibility"'
    set_ini "$pg" rendering renderer/rendering_method.mobile '"gl_compatibility"' ;;
  mobile)
    set_ini "$pg" rendering renderer/rendering_method '"mobile"'
    set_ini "$pg" rendering renderer/rendering_method.mobile '"mobile"' ;;
  *) die "MH_RENDERER must be compatibility or mobile" ;;
esac
if [ -n "${MH_MAIN_SCENE:-}" ]; then
  case "$MH_MAIN_SCENE" in res://*.tscn|res://*.scn) ;; *) die "MH_MAIN_SCENE must be res://...tscn" ;; esac
  set_ini "$pg" application run/main_scene "\"$MH_MAIN_SCENE\""
fi
log "project options applied: renderer=${MH_RENDERER:-unchanged} main_scene=${MH_MAIN_SCENE:-unchanged}"
grep -nE 'rendering_method|main_scene' "$pg" >&2 || true
