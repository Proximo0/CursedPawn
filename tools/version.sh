#!/usr/bin/env bash
# Prints the build's version string: <base>+<yyyymmdd>[.<short sha>]. Base is $VERSION_BASE or 1.0.0.
# --write: also sets application/config/version in project.godot (so the diagnostics report and the export carry it).
# Quiet: one line. Run it as the first step of a release build (docs/release_checklist.md).
set -euo pipefail
cd "$(dirname "$0")/.."
V="${VERSION_BASE:-1.0.0}+$(date -u +%Y%m%d)"
if SHA=$(git rev-parse --short HEAD 2>/dev/null); then V="${V}.${SHA}"; fi
if [[ "${1:-}" == "--write" ]]; then
	if grep -q '^config/version=' project.godot; then
		sed -i "s|^config/version=.*|config/version=\"${V}\"|" project.godot
	else
		sed -i "0,/^config\/name=.*/s||&\nconfig/version=\"${V}\"|" project.godot
	fi
fi
echo "${V}"
