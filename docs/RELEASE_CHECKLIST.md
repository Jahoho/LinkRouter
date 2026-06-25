# LinkRouter Release Checklist

Use this checklist before treating a build as a release candidate.

## Personal Applications Build

Use this when installing LinkRouter on this Mac for daily use.

1. Quit any running LinkRouter instance.
2. Build and install the Release app:

   ```sh
   scripts/install_release_app.sh
   ```

3. Open `/Applications/LinkRouter.app`.
4. In macOS System Settings, set the default web browser to LinkRouter.
5. Open LinkRouter Settings and refresh setup health.
6. Run one real link test from Mail or Codex.

Expected checks:

- `/Applications/LinkRouter.app` exists.
- `codesign --verify --deep --strict --verbose=2 /Applications/LinkRouter.app`
  passes.
- LinkRouter appears in Activity Monitor or `pgrep -fl LinkRouter`.
- The app can receive a link after being selected as the default browser.

## Local Release Zip

Use this when saving a build artifact or sharing only with your own machine.

1. Confirm the `/Applications` build works.
2. Create a zip:

   ```sh
   scripts/create_release_zip.sh /Applications/LinkRouter.app
   ```

3. Confirm the zip appears in `releases/`.
4. Record the app size and zip size in local development notes if they change
   meaningfully.

## External Tester Build

Use this only when sharing with another person.

Personal Apple Development signing is not enough for a polished external
release. Gatekeeper may reject or warn on other Macs.

External tester requirements:

1. Build with a `Developer ID Application` certificate.
2. Verify code signing:

   ```sh
   codesign --verify --deep --strict --verbose=2 /path/to/LinkRouter.app
   ```

3. Zip the app.
4. Submit the zip to Apple notarization:

   ```sh
   xcrun notarytool submit /path/to/LinkRouter.zip --keychain-profile PROFILE --wait
   ```

5. Staple the notarization ticket:

   ```sh
   xcrun stapler staple /path/to/LinkRouter.app
   ```

6. Assess with Gatekeeper:

   ```sh
   spctl --assess --type execute --verbose=4 /path/to/LinkRouter.app
   ```

7. Test on a clean macOS user account or another Mac.

## Do Not Release If

- The app cannot be selected as the default browser.
- Setup health cannot confirm the installed app state.
- Source detection fails for the intended test app without a clear fallback.
- The fallback browser is missing.
- Code signing verification fails.
- External tester builds are not notarized.
