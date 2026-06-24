# LinkRouter Distribution Notes

This document tracks the lightweight distribution path for personal use and
small external testing.

## Current Recommendation

Use direct distribution first:

1. Build `Release` in Xcode.
2. Sign with an Apple Development identity for personal machines, or Developer
   ID Application for external testers.
3. Notarize before sharing outside your own Macs.
4. Zip the `.app` bundle with `scripts/create_release_zip.sh`.

Do not add Sparkle or an installer package until there are real external
testers who need automatic updates. The app is currently small enough for
manual zip delivery.

## Create a Zip

After building a signed release app:

```sh
scripts/create_release_zip.sh /path/to/LinkRouter.app
```

The script writes a timestamped zip into `releases/`.

## Notarization Sketch

For a Developer ID build, the normal direct-distribution flow is:

```sh
codesign --verify --deep --strict --verbose=2 /path/to/LinkRouter.app
xcrun notarytool submit /path/to/LinkRouter.zip --keychain-profile PROFILE --wait
xcrun stapler staple /path/to/LinkRouter.app
spctl --assess --type execute --verbose=4 /path/to/LinkRouter.app
```

Keep this as a documented manual process until packaging needs become real.

## App Store Status

App Store distribution remains research, not the recommended path. Before
attempting it, verify:

- Sandbox compatibility with default-browser URL handling.
- Browser launching under sandbox restrictions.
- Review expectations for an app that asks to be the default browser.
- Whether the source-app detection approach remains acceptable.

## Lightweight Guardrails

- Do not bundle browser icons; read installed app icons at runtime.
- Do not persist full URL history by default.
- Do not add an updater framework until manual releases become painful.
- Prefer JSON configuration export/import over account-based sync.
- Keep release archives as a single `.app` zip unless testers need an
  installer.
