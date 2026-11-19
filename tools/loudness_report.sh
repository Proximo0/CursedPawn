#!/usr/bin/env bash
# Offline loudness report for every procedural sound (and music stem). Exit 1 if a sound is >2 dB off its class target.
# Usage: tools/loudness_report.sh [-v]   (-v prints every line; default prints only out-of-tolerance lines and the summary)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
tools/import.sh || exit 1
OUT=$("$GODOT" --headless --path . -s res://tests/shots/loudness_report.gd 2>&1 | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )')
rc=$?
if [ "${1:-}" = "-v" ]; then echo "$OUT"; else echo "$OUT" | grep -E ' OUT$|^LOUDNESS'; fi
echo "$OUT" | grep -q '^LOUDNESS out_of_tolerance=0 ' && exit 0
exit 1
