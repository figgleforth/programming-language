# Assets

- `icon.svg` / `icon@2x.svg` — the icon for `.code` files. `icon@2x.svg` is the source used to build the macOS file icon.
- `icon.sketch` — the Sketch source file for the icon.
- `icon.icns` — the built macOS icon file, generated from `icon@2x.svg` by `build_icon.sh`. Not source — rebuild it, don't hand-edit it.
- `build_icon.sh` — builds `icon.icns` from `icon@2x.svg`. Run standalone, any time you change the SVG.
- `Info.plist` — the actual file type declaration macOS reads. Plain text, read it directly.
- `app_stub` — a two-line do-nothing script. See "Why a helper app" below.
- `register_macos_type.sh` — tells macOS about `.code` files, using the three files above.

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

### Opt out

Remove the helper app and tell Launch Services to forget it:

```bash
rm -rf ~/Applications/Code_Lang_Icon_Stub.app
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f -u ~/Applications/Code_Lang_Icon_Stub.app
```

A restart also clears it, since Launch Services notices the app is gone.

After this, `.code` files go back to a generic icon and a generic (plain text) type.
