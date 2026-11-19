#!/usr/bin/env bash
# Renders every music track to /tmp/music/*.wav (each layer count, loop twice) and prints build times.
# Usage: tools/render_music.sh
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
tools/import.sh || exit 1
"$GODOT" --headless --path . -s res://tests/shots/music_dump.gd 2>&1 | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )'
exit "${PIPESTATUS[0]}"
