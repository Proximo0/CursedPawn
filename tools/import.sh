#!/usr/bin/env bash
# Shared import step for every tool: runs `godot --import` only when project files changed since the last import.
# A no-op import still costs ~3.4 s, while the fingerprint (path, size, mtime of every file outside .godot/, .git/
# build/ and out/, plus the Godot version) takes milliseconds. FORCE_IMPORT=1 imports anyway.
# Holds /tmp/<project>_import.lock (the only lock any tool takes). Quiet: prints the import log only on failure.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
STAMP=".godot/import.stamp"
LOG="/tmp/$(basename "$PWD")_import.log"
exec 9>"/tmp/$(basename "$PWD")_import.lock"
flock 9
fingerprint() {
  { "$GODOT" --version 2>/dev/null; find . \( -path ./.godot -o -path ./.git -o -path ./build -o -path ./out \) -prune \
    -o -type f -printf '%p %s %T@\n' | LC_ALL=C sort; } | md5sum | cut -d' ' -f1
}
fp=$(fingerprint)
if [[ "${FORCE_IMPORT:-0}" != 1 && -f "$STAMP" && -f .godot/global_script_class_cache.cfg && "$(cat "$STAMP")" == "$fp" ]]; then
  exit 0
fi
rm -f "$STAMP"
"$GODOT" --headless --path . --import >"$LOG" 2>&1 || { cat "$LOG"; exit 1; }
# The stamp is the fingerprint from before the import, so a file edited while it ran triggers another import next time
# (as does a .uid file the import writes for a new script: one extra import, never a stale cache).
echo "$fp" >"$STAMP"
