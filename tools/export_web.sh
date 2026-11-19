#!/usr/bin/env bash
# Export the "Web" preset (Compatibility, single-threaded) to build/web/ and check its download size.
# Release uses the Web preset's 2D-only engine (tools/fetch_web_template.sh); --debug the stock debug template
# (tools/fetch_templates.py). Both are fetched on first use.
# Usage: tools/export_web.sh [--debug]. Quiet: prints errors and the WEB size line. Exit 1 on failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
GODOT_VERSION="4.7.2"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
OUT="build/web/index.html"
MODE="--export-release"
if [[ "${1:-}" == "--debug" ]]; then MODE="--export-debug"; fi

fail() {
	echo "export_web: $1" >&2
	exit 1
}

cd "${ROOT}"
if [[ "${MODE}" == "--export-release" ]]; then
	# The Web preset's custom release template: the 2D-only engine from the web-template-2d draft release.
	[[ -f build/templates/web_nothreads_release_2d_min.zip ]] || tools/fetch_web_template.sh >/dev/null \
		|| fail "2D web template fetch failed (needs gh with access to the repo)"
elif [[ ! -f "${TEMPLATE_DIR}/web_nothreads_debug.zip" ]]; then
	python3 -I tools/fetch_templates.py "${GODOT_VERSION}" "${TEMPLATE_DIR}" web_nothreads_debug.zip >/dev/null \
		|| fail "template download failed"
fi
tools/import.sh || fail "import failed"
rm -rf build/web && mkdir -p build/web
log=$("${GODOT}" --headless --path . "${MODE}" Web "${OUT}" 2>&1) || { echo "$log" | grep -E 'ERROR' >&2; fail "godot export failed"; }
[[ -f build/web/index.wasm ]] || { echo "$log" | grep -E 'ERROR' >&2; fail "no index.wasm in build/web"; }
tools/web_size.sh build/web
