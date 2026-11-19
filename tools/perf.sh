#!/usr/bin/env bash
# Frame-time profile of the real game screen (tests/perf/perf.gd) under xvfb with software GL: boot phases, p50/p95/p99/max
# frame ms, draw calls, and the first-call cost of SpriteKit textures. Usage: tools/perf.sh [--frames=600] [--seed=7]
# Quiet: prints PERF lines only. Native software rendering is a pessimistic stand-in for a mid PC GPU.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
tools/import.sh || exit 1
xvfb-run -a "$GODOT" --path . --disable-vsync --resolution "${RES:-640x360}" -s res://tests/perf/perf.gd -- --scripted --seed=7 "$@" 2>&1 \
	| grep -E '^(PERF|SCRIPT ERROR|ERROR)'
exit "${PIPESTATUS[1]}"
