#!/usr/bin/env bash
# Download size of the web build (feel target: <= 30 MB). Players download it gzip-compressed, so the
# target is checked on the gzip size; the raw size is printed too. Usage: tools/web_size.sh [build/web]
set -uo pipefail
DIR="${1:-build/web}"
LIMIT_MB="${WEB_LIMIT_MB:-30}"
[[ -f "$DIR/index.wasm" ]] || { echo "WEB FAIL no build in $DIR (run: godot --headless --path . --export-release Web $DIR/index.html)"; exit 1; }
raw=0; gz=0
for f in "$DIR"/*; do
  [[ -f "$f" ]] || continue
  raw=$((raw + $(stat -c %s "$f")))
  gz=$((gz + $(gzip -9 -c "$f" | wc -c)))
done
mb() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1048576 }'; }
verdict=PASS; awk -v g="$gz" -v l="$LIMIT_MB" 'BEGIN { exit !(g / 1048576 > l) }' && verdict=FAIL
echo "WEB size $verdict download_gzip=$(mb $gz)MB raw=$(mb $raw)MB limit=${LIMIT_MB}MB"
[[ "$verdict" == PASS ]]
