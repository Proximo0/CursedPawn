#!/usr/bin/env bash
# Export the "Linux" preset (export_presets.cfg) and zip it to build/<slug>-linux.zip. With --smoke, then run the exported
# binary headless: the play-bot plays one whole run through the real screen and must print a BOT line and exit 0.
# Quiet: prints errors and one summary line. Exit 1 on failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="Cursed Pawn"
PROJECT_SLUG="Cursed-Pawn"  # no spaces: used for file names
GODOT_VERSION="4.7.2"
TEMPLATE_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
TEMPLATE_BIN="${TEMPLATE_DIR}/linux_release.x86_64"
BIN_OUT="build/linux/${PROJECT_SLUG}.x86_64"
ZIP_OUT="build/${PROJECT_SLUG}-linux.zip"
SMOKE=0
[[ "${1:-}" == "--smoke" ]] && SMOKE=1

fail() {
	echo "export_linux (${PROJECT_NAME}): $1" >&2
	exit 1
}

command -v godot >/dev/null 2>&1 || fail "godot not found on PATH"
command -v zip >/dev/null 2>&1 || fail "zip not found on PATH"
command -v python3 >/dev/null 2>&1 || fail "python3 not found on PATH"

if [[ ! -f "${TEMPLATE_BIN}" ]]; then
	# Range-reads just the Linux x86_64 release template out of the 1.28 GB tpz (tools/fetch_templates.py).
	python3 -I "${ROOT}/tools/fetch_templates.py" "${GODOT_VERSION}" "${TEMPLATE_DIR}" 'linux_release.x86_64*' >/dev/null \
		|| fail "template download failed"
	[[ -f "${TEMPLATE_BIN}" ]] || fail "linux_release.x86_64 missing after fetch"
fi

cd "${ROOT}"
tools/import.sh || fail "import failed"
rm -rf build/linux
mkdir -p build/linux

if ! godot --headless --path . --export-release "Linux" "${BIN_OUT}" >/dev/null 2>&1; then
	fail "godot export failed (rerun with godot directly for details)"
fi
[[ -f "${BIN_OUT}" ]] || fail "binary not produced at ${BIN_OUT}"
chmod +x "${BIN_OUT}"
# Online-service credentials (docs/online.md), when the owner has them: next to the binary, where the game looks.
for c in "${ROOT}"/config/*credentials*; do
	if [[ -f "$c" ]]; then cp "$c" build/linux/; fi
done

rm -f "${ZIP_OUT}"
(cd build && zip -q -r "$(basename "${ZIP_OUT}")" linux) || fail "zip not produced"
[[ -f "${ZIP_OUT}" ]] || fail "zip not produced"

if [[ ${SMOKE} -eq 1 ]]; then
	# Unpack the zip elsewhere so the check runs what a player would get, not the build folder.
	TMP="$(mktemp -d "/tmp/linux-smoke.XXXXXX")"
	trap 'rm -rf "${TMP}"' EXIT
	unzip -q "${ZIP_OUT}" -d "${TMP}"
	OUT="$(timeout 120 "${TMP}/linux/${PROJECT_SLUG}.x86_64" --headless -- --scripted --bot=greedy --seed=7 2>&1)" \
		|| { echo "${OUT}" | tail -15 >&2; fail "smoke run failed (exit code or bot stuck)"; }
	echo "${OUT}" | grep -q '^BOT ' || { echo "${OUT}" | tail -15 >&2; fail "smoke run printed no BOT line"; }
	echo "export_linux: smoke ok ($(echo "${OUT}" | grep '^BOT ' | cut -c1-90))"
fi

echo "export_linux: ok ${ZIP_OUT} ($(du -h "${ZIP_OUT}" | cut -f1))"
