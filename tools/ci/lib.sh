#!/usr/bin/env bash
# Shared helpers for tools/ci scripts. Source it; do not execute it.
# Compatible with bash 3.2 (macOS runners): no associative arrays, no mapfile.
set -euo pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$CI_DIR/../.." && pwd)"
# shellcheck disable=SC1091
source "$CI_DIR/versions.env"

GODOT_FULL="${GODOT_VERSION}-${GODOT_FLAVOR}"
GODOT_CACHE_DIR="${GODOT_CACHE_DIR:-$HOME/.cache/mh-godot}"
GODOT_RELEASE_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_FULL}"

# Game project location, relative to the repo root (workflow input game_path).
GAME_PATH="${GAME_PATH:-game}"
case "$GAME_PATH" in
  /*|*..*) echo "ERROR: game_path must be relative to the repo and contain no '..': $GAME_PATH" >&2; exit 2 ;;
esac
GAME_DIR="$REPO_ROOT/$GAME_PATH"
OUT_DIR="${OUT_DIR:-$REPO_ROOT/ci-out}"

log() { echo "[ci] $*" >&2; }
die() { echo "[ci] ERROR: $*" >&2; exit 1; }

# Markdown to the GitHub job summary (or stdout when run locally).
summary() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat >> "$GITHUB_STEP_SUMMARY"; else cat; fi
}

detect_os() {
  case "$(uname -s)" in
    Linux*) echo linux ;;
    Darwin*) echo macos ;;
    MINGW*|MSYS*|CYGWIN*) echo windows ;;
    *) die "unsupported OS $(uname -s)" ;;
  esac
}

PYBIN=""
for c in python3 python; do
  if command -v "$c" >/dev/null 2>&1; then PYBIN="$c"; break; fi
done
py() { [ -n "$PYBIN" ] || die "python3 not found"; "$PYBIN" "$@"; }

sha512_of() {
  if command -v sha512sum >/dev/null 2>&1; then sha512sum "$1" | awk '{print $1}'
  else shasum -a 512 "$1" | awk '{print $1}'; fi
}

download() { # url dest
  log "download $1"
  curl -fsSL --retry 5 --retry-delay 5 --retry-connrefused -o "$2" "$1" || die "download failed: $1"
}

# Verify file $1 (asset name $2) against SHA512-SUMS.txt ($3) and optional pin ($4).
verify_sha512() {
  local file="$1" name="$2" sums="$3" pin="${4:-}" want got
  want="$(awk -v n="$name" '$2==n || $2=="*"n {print $1}' "$sums" | head -n1)"
  [ -n "$want" ] || die "no checksum for $name in $sums"
  got="$(sha512_of "$file")"
  [ "$want" = "$got" ] || die "SHA512 mismatch for $name (expected $want, got $got)"
  if [ -n "$pin" ] && [ "$pin" != "$got" ]; then
    die "SHA512 for $name does not match the pin in versions.env (pin $pin, got $got)"
  fi
  log "sha512 OK $name $got"
  echo "$name $got" >> "${OUT_DIR}/godot-checksums.txt" 2>/dev/null || true
}

# extract_zip ZIP DEST [glob ...]   (globs match member names; none = everything)
extract_zip() {
  py - "$@" <<'PY'
import sys, zipfile, fnmatch, os
z, dest, pats = sys.argv[1], sys.argv[2], sys.argv[3:]
os.makedirs(dest, exist_ok=True)
with zipfile.ZipFile(z) as f:
    for m in f.infolist():
        if pats and not any(fnmatch.fnmatch(m.filename, p) for p in pats):
            continue
        f.extract(m, dest)
        mode = m.external_attr >> 16
        if mode:
            try: os.chmod(os.path.join(dest, m.filename), mode & 0o7777)
            except OSError: pass
PY
}

template_root() {
  case "$(detect_os)" in
    linux) echo "${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates" ;;
    macos) echo "$HOME/Library/Application Support/Godot/export_templates" ;;
    windows)
      local a="${APPDATA:-$HOME/AppData/Roaming}"
      if command -v cygpath >/dev/null 2>&1; then a="$(cygpath -u "$a")"; fi
      echo "$a/Godot/export_templates" ;;
  esac
}

editor_settings_dir() {
  case "$(detect_os)" in
    linux) echo "${XDG_CONFIG_HOME:-$HOME/.config}/godot" ;;
    macos) echo "$HOME/Library/Application Support/Godot" ;;
    windows)
      local a="${APPDATA:-$HOME/AppData/Roaming}"
      if command -v cygpath >/dev/null 2>&1; then a="$(cygpath -u "$a")"; fi
      echo "$a/Godot" ;;
  esac
}

require_godot() {
  [ -n "${GODOT_BIN:-}" ] || die "GODOT_BIN not set (run tools/ci/download_godot.sh first)"
  [ -e "$GODOT_BIN" ] || die "GODOT_BIN does not exist: $GODOT_BIN"
}

# Set/replace a key in a Godot INI-style file. set_ini FILE SECTION KEY RAWVALUE
set_ini() {
  py - "$@" <<'PY'
import sys, re
path, section, key, val = sys.argv[1:5]
lines = open(path, encoding="utf-8").read().rstrip("\n").split("\n")
hdr = "[" + section + "]"
start = None
for i, ln in enumerate(lines):
    if ln.strip() == hdr:
        start = i
        break
if start is None:
    lines += ["", hdr, key + "=" + val]
else:
    end = len(lines)
    for j in range(start + 1, len(lines)):
        t = lines[j].strip()
        if t.startswith("[") and t.endswith("]"):
            end = j
            break
    for j in range(start + 1, end):
        if re.match(r"^" + re.escape(key) + r"\s*=", lines[j].strip()):
            lines[j] = key + "=" + val
            break
    else:
        last = start
        for j in range(start + 1, end):
            if lines[j].strip():
                last = j
        lines.insert(last + 1, key + "=" + val)
open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
PY
}
