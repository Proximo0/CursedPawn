#!/usr/bin/env bash
# Engine-free unit tests, headless. Usage: tools/run_tests.sh [test_name]
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# Refresh the class_name cache so new classes resolve (skipped when nothing changed). Quiet unless it fails.
tools/import.sh || exit 1
ARGS=()
[ $# -gt 0 ] && ARGS=(-- "--only=$1")
"$GODOT" --headless --path . -s res://tests/runner.gd "${ARGS[@]}" 2>&1 \
  | grep -vE '^(Godot Engine v|$|WARNING: .*audio|   at: )' 
exit "${PIPESTATUS[0]}"
