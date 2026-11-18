#!/usr/bin/env bash
# Export the "Web" preset (Compatibility, single-threaded) to build/web/ and check its download size.
# Fetches only web_nothreads_release.zip (9 MB) on first use via tools/fetch_templates.py.
# Usage: tools/export_web.sh [--debug]. Quiet: prints errors and the WEB size line. Exit 1 on failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
GODOT_VERSION="4.7.2"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
OUT="build/web/index.html"
MODE="--export-release"; TEMPLATE="web_nothreads_release.zip"
if [[ "${1:-}" == "--debug" ]]; then MODE="--export-debug"; TEMPLATE="web_nothreads_debug.zip"; fi

fail() {
	echo "export_web: $1" >&2
	exit 1
}

cd "${ROOT}"
if [[ ! -f "${TEMPLATE_DIR}/${TEMPLATE}" ]]; then
	python3 -I tools/fetch_templates.py "${GODOT_VERSION}" "${TEMPLATE_DIR}" "${TEMPLATE}" >/dev/null \
		|| fail "template download failed"
fi
tools/import.sh || fail "import failed"
rm -rf build/web && mkdir -p build/web
log=$("${GODOT}" --headless --path . "${MODE}" Web "${OUT}" 2>&1) || { echo "$log" | grep -E 'ERROR' >&2; fail "godot export failed"; }
[[ -f build/web/index.wasm ]] || { echo "$log" | grep -E 'ERROR' >&2; fail "no index.wasm in build/web"; }
tools/web_size.sh build/web
