#!/bin/bash
# Builds assets/icon.icns from assets/icon@2x.svg.
#
# Run this any time you change icon@2x.svg. It only rebuilds the .icns —
# it does not touch macOS file type registration. See register_macos_type.sh
# for that, and readme.md for how the two fit together.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$REPO_ROOT/assets/icon@2x.svg"
OUT="$REPO_ROOT/assets/icon.icns"
WORK_DIR="$(mktemp -d)"

trap 'rm -rf "$WORK_DIR"' EXIT

if [[ ! -f "$SVG" ]]; then
	echo "Missing $SVG" >&2
	exit 1
fi

ICONSET="$WORK_DIR/Code_Lang_Icon_Stub.iconset"
mkdir -p "$ICONSET"
for sz in 16 32 128 256 512 1024; do
	sips -s format png -z "$sz" "$sz" "$SVG" --out "$ICONSET/icon_${sz}x${sz}.png" >/dev/null
	d2=$((sz * 2))
	sips -s format png -z "$d2" "$d2" "$SVG" --out "$ICONSET/icon_${sz}x${sz}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT"

echo "Built $OUT"
