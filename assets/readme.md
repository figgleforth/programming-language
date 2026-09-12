# Assets

- `icon.svg` / `icon@2x.svg` — the icon for `.code` files. `icon@2x.svg` is the source used to build the macOS file icon.
- `icon.sketch` — the Sketch source file for the icon.
- `icon.icns` — the built macOS icon file, built from `icon@2x.svg` by `build_icon.sh`. Don't hand-edit it — rebuild it with `build_icon.sh` (or `set_icon.sh`) instead. It's committed on purpose: a fresh clone can register the icon straight away, with no build step and no `sips`/`iconutil` dependency check, before ever touching the SVG.
- `build_icon.sh` — builds `icon.icns` from `icon@2x.svg` (or any image path you pass it). Run standalone, any time you change the SVG.
- `set_icon.sh` — the one-command way to replace the icon: point it at any image (`.svg`, `.png`, `.icns`, ...) and it rebuilds `icon.icns` and re-registers it with macOS in one step. This is the closest thing to the drag-a-new-icon-onto-Get-Info trick, since macOS has no such control for a declared file type.
- `Info.plist` — the actual file type declaration macOS reads. Plain text, read it directly.
- `app_stub` — a two-line do-nothing script. See "Why a helper app" below.
- `register_macos_type.sh` — tells macOS about `.code` files, using the files above.

## The `.code` file icon on macOS

macOS does not know about `.code` files by default. A `.code` file shows a blank, generic icon, and some tools may treat it as an unknown or binary file.

`register_macos_type.sh` fixes this. It tells macOS that:

- `.code` is a real file type, with its own identifier (`com.bp.codelang.code-source`).
- This file type is plain text, specifically source code (it conforms to Apple's `public.source-code` type, which itself conforms to `public.plain-text`). This helps Spotlight, Quick Look, and text-aware tools handle `.code` files correctly.
- This file type has an icon, built from `icon@2x.svg`.

This change is **global** on your Mac. It applies to every `.code` file, in every folder, not just this repo. It does **not** change what app opens a `.code` file when you double-click it.

### Why a helper app

macOS only reads file type declarations (`UTExportedTypeDeclarations`) out of a real, launchable app bundle (`.app`) — this was tested directly on this machine: neither a bare, standalone `.plist` file nor a lighter, non-launchable `.bundle` package is accepted by `lsregister`, the system tool that reads these declarations. Both fail with the same error a broken app bundle would give.

So `register_macos_type.sh` builds the smallest thing that qualifies: a tiny `.app` at `~/Applications/Code_Lang_Icon_Stub.app`, holding a copy of `Info.plist`, `icon.icns`, and `app_stub` as its "executable." It never launches for real — `app_stub` just exits immediately if it's ever double-clicked. It exists only so macOS has a bundle to register.

### Is this the "real" way to do this?

Yes, for the part that matters. `UTExportedTypeDeclarations` in `Info.plist` — what actually declares `.code` as a type, gives it an icon, and says it's source code — is Apple's own public, documented API for this (Uniform Type Identifiers), unchanged since Tiger. There's no more-official way to declare a file type than that.

The one piece that isn't public is `lsregister` itself, the tool that pushes a bundle's declarations live immediately instead of waiting for Launch Services' own periodic rescan (e.g. at login). It has no man page and isn't on `$PATH`. It's still the standard tool for this — real installers (Adobe's, Microsoft's, and plenty of smaller text/note apps) call it the same way, at the same path under `CoreServices.framework`, which has been stable for two decades. Skipping it and just waiting for macOS's own rescan (or a restart) would work too, just not on demand.

### Opt in

1. Build the icon (only needed once, or after changing `icon@2x.svg`):

   ```bash
   assets/build_icon.sh
   ```

2. Register the file type:

   ```bash
   assets/register_macos_type.sh
   ```

If a `.code` file still shows the old icon afterward, run `killall Finder`, or log out and back in.

To change the icon later, `assets/set_icon.sh path/to/new-icon.svg` does both steps in one call.

### Opt out

Remove the helper app and tell Launch Services to forget it:

```bash
rm -rf ~/Applications/Code_Lang_Icon_Stub.app
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f -u ~/Applications/Code_Lang_Icon_Stub.app
```

A restart also clears it, since Launch Services notices the app is gone.

After this, `.code` files go back to a generic icon and a generic (plain text) type.
