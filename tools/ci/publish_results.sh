#!/usr/bin/env bash
# Push small text results to the branch `ci-results` so the dev lead can read them through the
# repository (job logs and artifacts are not reachable from the dev sandbox).
# Usage: publish_results.sh <name> <path>...   Env: GITHUB_TOKEN, GITHUB_REPOSITORY, GITHUB_RUN_ID
set -uo pipefail
NAME="${1:?name}"; shift
RUN="${GITHUB_RUN_ID:-local}-$NAME"
URL="https://x-access-token:${GITHUB_TOKEN:?}@github.com/${GITHUB_REPOSITORY:?}.git"
tmp="$(mktemp -d)"
if ! git clone --quiet --depth 1 --branch ci-results "$URL" "$tmp" 2>/dev/null; then
  rm -rf "$tmp"; mkdir -p "$tmp"; git -C "$tmp" init -q; git -C "$tmp" checkout -q -b ci-results
  git -C "$tmp" remote add origin "$URL"
fi
mkdir -p "$tmp/$RUN"
for p in "$@"; do
  for f in $p; do [ -e "$f" ] && cp -r "$f" "$tmp/$RUN/"; done
done
# keep files small: last 300 KB of anything larger, and drop binaries
find "$tmp/$RUN" -type f \( -name '*.png' -o -name '*.apk' -o -name '*.aab' -o -name '*.zip' \) -delete
find "$tmp/$RUN" -type f -size +300k -exec sh -c 'tail -c 300000 "$1" > "$1.tmp" && mv "$1.tmp" "$1"' _ {} \;
git -C "$tmp" add -A
git -C "$tmp" -c user.name=ci -c user.email=ci@users.noreply.github.com commit -q -m "results $RUN" || exit 0
for i in 1 2 3; do
  git -C "$tmp" push -q origin ci-results && exit 0
  git -C "$tmp" pull -q --rebase origin ci-results || true
done
exit 0
