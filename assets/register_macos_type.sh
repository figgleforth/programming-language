#!/bin/bash
# Registers .code files with macOS as their own file type (globally, for this Mac).
#
# What it does:
#   - Packs Info.plist, icon.icns, and app_stub into a tiny, invisible
#     helper app bundle: ~/Applications/Code_Lang_Icon_Stub.app
#   - Registers that bundle with Launch Services, the system service that
#     tracks file types, icons, and default apps
#
# Info.plist (checked into this folder, plain text, read it yourself) is what
# actually declares the file type: .code files conform to Apple's
# public.source-code type (itself plain text), and get the icon.icns icon.
#
# This does NOT make anything the default app that opens .code files on
# double-click — it only affects the icon and the reported content type.
#
# macOS requires this declaration to live inside a real, launchable bundle
# (an .app) for `lsregister` to accept it — a bare Info.plist, or a
# non-launchable .bundle, is rejected. app_stub is that bundle's
# "executable": it does nothing but exit immediately if ever double-clicked.
#
# On official-ness: UTExportedTypeDeclarations, the Info.plist key that
# actually declares the type, *is* Apple's public, documented mechanism for
# this — the Uniform Type Identifiers system, unchanged since Tiger. There's
# no more-official alternative to that part.
#
# `lsregister` itself is the one private piece — no man page, not on $PATH,
# doesn't ship a stable CLI Apple documents. It's still the standard way
# real installers (Adobe, Microsoft, and plenty of smaller text/note apps)
# push a freshly-installed bundle's declarations live immediately, rather
# than waiting on it. Its path under CoreServices.framework has been stable
# since Tiger and is the one every how-to for this uses; there's no public
# replacement for "rescan Launch Services right now." Skipping this call
# entirely still works — Launch Services rescans app directories on its own
# (e.g. at login) and would pick up the same bundle eventually — this call
# just avoids waiting for that.
#
# Needs assets/icon.icns to exist first — run build_icon.sh once, or
# set_icon.sh to replace the icon and register in one step.
# Safe to re-run any time.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$REPO_ROOT/assets"
APP_NAME="Code_Lang_Icon_Stub"
APP_DIR="$HOME/Applications/$APP_NAME.app"

if [[ ! -f "$ASSETS/icon.icns" ]]; then
	echo "Missing $ASSETS/icon.icns — run assets/build_icon.sh first." >&2
	exit 1
fi

mkdir -p "$HOME/Applications" "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ASSETS/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ASSETS/icon.icns" "$APP_DIR/Contents/Resources/icon.icns"
cp "$ASSETS/app_stub" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null

/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP_DIR"

echo "Registered .code files with macOS, icon from icon.icns."
echo "If Finder still shows the old icon on existing files, run: killall Finder"
