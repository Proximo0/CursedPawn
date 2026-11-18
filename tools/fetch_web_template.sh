#!/usr/bin/env bash
# Fetches the 2D-only, size-optimised web export template (built by the web-template-2d workflow and attached to
# the draft release "web-template-2d") into build/templates/, where the Web preset expects it.
# Rebuild it with: gh api -X POST repos/<owner>/<repo>/actions/workflows/web_template.yml/dispatches -f ref=main
set -euo pipefail
cd "$(dirname "$0")/.."
repo="${REPO:-Proximo0/CursedPawn}"
out="build/templates/web_nothreads_release_2d.zip"
mkdir -p build/templates
id=$(gh api "repos/$repo/releases" --jq '.[] | select(.tag_name=="web-template-2d") | .assets[] | select(.name=="web_nothreads_release_2d.zip") | .id')
[ -n "$id" ] || { echo "fetch_web_template: no asset on release web-template-2d" >&2; exit 1; }
gh api -H "Accept: application/octet-stream" "repos/$repo/releases/assets/$id" > "$out.tmp" && mv "$out.tmp" "$out"
echo "fetch_web_template: ok $out $(du -h "$out" | cut -f1)"
