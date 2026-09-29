#!/usr/bin/env bash
# Write game/build_info.json (git-ignored) so the app can show which build it is.
# Run after set_project_options.sh and before import/export. Env (all optional):
#   MH_RENDERER, GITHUB_RUN_NUMBER, GITHUB_RUN_ID, GITHUB_WORKFLOW, GITHUB_SHA
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
sha="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
[ -n "$sha" ] || sha="$(printf '%s' "${GITHUB_SHA:-unknown}" | cut -c1-7)"
# Strip anything that could break the JSON strings.
clean() { printf '%s' "$1" | tr -d '"\\' | tr -c '[:print:]' ' '; }
renderer="${MH_RENDERER:-compatibility}"
out="$GAME_DIR/build_info.json"
cat > "$out" <<JSON
{
  "sha": "$(clean "$sha")",
  "run_number": "$(clean "${GITHUB_RUN_NUMBER:-0}")",
  "run_id": "$(clean "${GITHUB_RUN_ID:-0}")",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "workflow": "$(clean "${GITHUB_WORKFLOW:-local}")",
  "renderer": "$(clean "$renderer")"
}
JSON
log "wrote $out"
cat "$out" >&2
