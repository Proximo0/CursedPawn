#!/usr/bin/env bash
# Renders every procedural sound to /tmp/sfx/*.wav and prints one line per sound (duration, peak, rms, build ms).
# Usage: tools/render_sfx.sh [seed]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
ARGS=()
[ $# -gt 0 ] && ARGS=(-- "--seed=$1")
"$GODOT" --headless --path . -s res://tests/shots/sfx_dump.gd "${ARGS[@]}" 2>&1 | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )'
exit "${PIPESTATUS[0]}"
