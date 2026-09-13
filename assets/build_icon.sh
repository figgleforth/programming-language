#!/bin/bash
# Builds a macOS .icns file from a source image.
#
# Usage:
#   assets/build_icon.sh                       Rebuild assets/icon.icns from assets/icon.svg
#   assets/build_icon.sh <source> [out.icns]   Build from any image sips can read
#
# Run this any time you change icon.svg. It only rebuilds the .icns --
# it does not touch macOS file type registration. See register_macos_type.sh
# for that, set_icon.sh to replace the icon in one step, and readme.md for
# how the three fit together.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-$REPO_ROOT/assets/icon.svg}"
OUT="${2:-$REPO_ROOT/assets/icon.icns}"
WORK_DIR="$(mktemp -d)"

trap 'rm -rf "$WORK_DIR"' EXIT

if [[ ! -f "$SRC" ]]; then
	echo "Missing $SRC" >&2
	exit 1
fi

ICONSET="$WORK_DIR/icon.iconset"
mkdir -p "$ICONSET"
# 512 is the largest slot iconutil accepts; its  (1024px) covers Retina,
# so there's no need to also render a 1024 base size -- iconutil silently
# ignores it if present.
for sz in 16 32 128 256 512; do
	sips -s format png -z "$sz" "$sz" "$SRC" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
	d2=$((sz * 2))
	sips -s format png -z "$d2" "$d2" "$SRC" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT"

echo "Built $OUT"
