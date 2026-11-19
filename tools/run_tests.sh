#!/usr/bin/env bash
# Engine-free unit tests, headless. Usage: tools/run_tests.sh [test_name]
# All files: split across JOBS Godot processes (default: CPU count, at most one per file). Quiet: on a pass it prints
# only the summary line; on a failure it prints every failing shard's full output (FAIL lines, engine errors).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
FILTER='^(Godot Engine v|$|WARNING: .*audio|   at: )'
# Refresh the class_name cache so new classes resolve (skipped when nothing changed). Quiet unless it fails.
tools/import.sh || exit 1
if [ $# -gt 0 ]; then
  "$GODOT" --headless --path . -s res://tests/runner.gd -- "--only=$1" 2>&1 | grep -vE "$FILTER"
  exit "${PIPESTATUS[0]}"
fi
files=$(ls tests/unit/test_*.gd | wc -l)
JOBS="${JOBS:-$(nproc)}"
(( JOBS > files )) && JOBS=$files
OUT=$(mktemp -d "/tmp/tests.$(basename "$PWD").XXXXXX")
for ((i = 0; i < JOBS; i++)); do
  ( "$GODOT" --headless --path . -s res://tests/runner.gd -- "--shard=$i" "--nshards=$JOBS" >"$OUT/$i.log" 2>&1
    echo $? >"$OUT/$i.rc" ) &
done
wait
passed=0; failed=0; rc=0
for ((i = 0; i < JOBS; i++)); do
  line=$(grep -E '^TESTS passed=' "$OUT/$i.log" | tail -1)
  if [[ "$line" =~ passed=([0-9]+)\ failed=([0-9]+) ]]; then
    passed=$((passed + BASH_REMATCH[1])); failed=$((failed + BASH_REMATCH[2]))
  else
    failed=$((failed + 1)); echo "shard $i crashed:"
  fi
  if [ "$(cat "$OUT/$i.rc")" != 0 ] || [ -z "$line" ]; then
    rc=1
    grep -vE "$FILTER" "$OUT/$i.log" | grep -v '^TESTS passed='
  fi
done
rm -rf "$OUT"
echo "TESTS passed=$passed failed=$failed"
exit "$rc"
