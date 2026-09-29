#!/usr/bin/env bash
# Create a placeholder game/icon.png if the project has none (exports fail without an
# icon on some platforms). Never overwrites a real icon.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
icon="$GAME_DIR/icon.png"
[ -f "$icon" ] && { log "icon present"; exit 0; }
py - "$icon" <<'PY'
import sys, zlib, struct
n = 512
row = b"\x00" + bytes([46, 125, 50]) * n          # flat green
raw = row * n
def chunk(t, d):
    c = struct.pack(">I", len(d)) + t + d
    return c + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", n, n, 8, 2, 0, 0, 0)) \
      + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY
log "wrote placeholder icon $icon (CI only, do not commit)"
