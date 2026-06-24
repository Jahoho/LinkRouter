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

## Personal Standalone App

This is the path for running LinkRouter without pressing Run in Xcode.

Requirements:

- Xcode command line tools are still needed to build the app.
- An Apple Development signing identity should be selected in the project or
  available through local build settings.
- The generated `.app` can run on its own after it is built and copied to
  `/Applications`.

Build a standalone Release app:

```sh
scripts/build_release_app.sh
```

The script prints the generated app path, usually:

```text
/private/tmp/LinkRouterReleaseBuild/Build/Products/Release/LinkRouter.app
```

Install for personal use:

1. Quit LinkRouter if it is currently running from Xcode.
2. Copy the generated `LinkRouter.app` to `/Applications`.
3. Open `/Applications/LinkRouter.app`.
4. In macOS System Settings, set the default web browser to this installed
   LinkRouter app.
5. Open LinkRouter Settings and refresh the default-browser status.

After this, normal use does not require Xcode. Xcode is only needed when
building a new version.

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

## External Tester Build

For another Mac or another person, use Developer ID signing and notarization.
A Personal Team / Apple Development build is mainly for your own machine and
can be blocked or warned about on other Macs.

Recommended external-test flow:

1. Join Apple Developer Program.
2. Create or install a `Developer ID Application` certificate.
3. Build Release with that identity.
4. Zip the `.app`.
5. Submit the zip to Apple notarization.
6. Staple the notarization ticket.
7. Test on a clean macOS user account or another Mac.

Do this only when the product is stable enough for real testers.

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
