#!/bin/bash
# Replaces the .code file icon everywhere on this Mac, from one image you
# supply. This is the closest equivalent to the drag-a-new-icon-onto-Get-Info
# trick you'd use to re-skin an app -- macOS has no such control for a
# declared file type (there's no "Get Info" on a UTI), so this script is it.
#
# Usage:
#   assets/set_icon.sh path/to/new-icon.svg
#   assets/set_icon.sh path/to/new-icon.png
#   assets/set_icon.sh path/to/new-icon.icns
#
# Accepts an .icns directly, or any image `sips` can rasterize (.svg, .png,
# .jpg, .tiff, .pdf, .heic, ...). An .svg input also replaces the tracked
# vector source, assets/icon.svg -- commit that alongside the rebuilt
# icon.icns so future rebuilds start from the same art. Any other format
# only replaces icon.icns; it isn't resolution-independent, so it's not
# worth keeping as the checked-in source.
#
# Rebuilds and re-registers in one step -- no separate build_icon.sh /
# register_macos_type.sh calls needed afterward.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$REPO_ROOT/assets"

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 <path-to-new-icon>" >&2
	exit 1
fi

SRC="$1"
if [[ ! -f "$SRC" ]]; then
	echo "No such file: $SRC" >&2
	exit 1
fi

EXT="${SRC##*.}"
EXT="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"

if [[ "$EXT" == "icns" ]]; then
	cp "$SRC" "$ASSETS/icon.icns"
	echo "Copied $SRC -> $ASSETS/icon.icns"
elif [[ "$EXT" == "svg" ]]; then
	cp "$SRC" "$ASSETS/icon.svg"
	"$ASSETS/build_icon.sh"
	echo "Replaced assets/icon.svg and rebuilt icon.icns from it."
else
	"$ASSETS/build_icon.sh" "$SRC" "$ASSETS/icon.icns"
	echo "Built icon.icns from $SRC -- assets/icon.svg left untouched ($EXT isn't vector source)."
fi

"$ASSETS/register_macos_type.sh"
