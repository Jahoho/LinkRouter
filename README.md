# LinkRouter

LinkRouter is a lightweight macOS menu bar utility that routes web links to
different browsers based on where the link came from.

It runs locally, becomes your default web browser, receives `http` and `https`
open requests from macOS, detects the likely source app, applies your rules,
and forwards the link to the browser you chose.

Example rules:

- Codex -> Google Chrome
- WeChat -> Safari
- Mail -> Safari
- Telegram -> Arc
- Everything else -> fallback browser

## Why

macOS normally gives you one default browser for every link. That is awkward if
you use different browsers for different contexts: development, messaging,
email, personal browsing, or work profiles.

LinkRouter keeps that decision automatic and local. The goal is not to become a
large browser suite. The goal is a small, understandable system utility that
quietly sends each link to the right place and explains what happened when a
decision is surprising.

## Current Status

LinkRouter is a personal-use release candidate for macOS. It is usable from
`/Applications`, has a native menu bar interface, and includes tests for the
core routing, configuration, browser discovery, and source detection paths.

Current local release artifact:

```text
releases/LinkRouter-0.1.0-1-20260628-022453.zip
```

Measured size:

- Installed app: about `5.4M`
- Release zip: about `3.4M`

## Features

- Route links by source app, domain, URL scheme, or combined conditions.
- Use a configured fallback browser when no rule matches.
- Detect source apps with best-effort macOS signals and confidence reporting.
- Infer source apps from helper executable paths, which improves Codex and
  Electron-style helper process routing.
- Open links in specific installed browsers by bundle identifier.
- Support detected Chromium browser profiles for destination rules.
- Forward local `.html`, `.htm`, and `.xhtml` files from Finder to the fallback
  browser so local preview workflows still work.
- Manage common file default apps in a separate compact `Default Apps` tab.
- Prevent routing loops, including destinations that point back to LinkRouter.
- Create rules from recently detected apps or installed app picker results.
- Keep a recent in-memory routing history with sanitized diagnostics.
- Explain the latest routing decision and show broken-rule warnings.
- Import, export, and reset JSON configuration.
- Pause routing temporarily or route only the next link to a selected browser.
- Launch at login.
- Switch the interface between English and Chinese.
- Keep all configuration and diagnostics local.

## Privacy

LinkRouter is local-first. It does not require an account, a cloud service, or
telemetry.

Default diagnostics intentionally avoid full URLs. Logs and recent history keep
only sanitized routing information such as scheme, host, source app, detection
method, matched rule, and final browser. URL paths, query strings, fragments,
credentials, and tokens are omitted by default.

## Important Limitations

Source-app detection on macOS is inherently best-effort. macOS does not always
provide a guaranteed "original app that opened this URL" field to the default
browser. LinkRouter combines several signals:

- Apple Event sender metadata
- frontmost app
- recently active app cache
- helper executable path inference
- fallback browser when the source is unknown

When detection is uncertain or unavailable, LinkRouter fails safely to the
configured fallback browser.

Personal Apple Development signing is suitable for local use. External tester
distribution should use Developer ID signing and notarization.

## Install for Personal Use

Build and install the standalone app:

```sh
scripts/install_release_app.sh
```

The script builds a Release app, installs it to:

```text
/Applications/LinkRouter.app
```

Then open LinkRouter from `/Applications` and set it as the macOS default web
browser:

1. Open System Settings.
2. Go to Desktop & Dock.
3. Find Default web browser.
4. Choose LinkRouter.
5. Return to LinkRouter Settings and refresh the default-browser status.

After this, normal use does not require Xcode.

## Quick Start

1. Launch LinkRouter from `/Applications`.
2. Open Settings from the menu bar icon.
3. Choose a fallback browser.
4. Add or edit routing rules in the `Rules` tab.
5. Open a link from Codex, Mail, WeChat, Telegram, Obsidian, or another app.
6. Check `Diagnostics` if a link opens somewhere unexpected.

The configuration file is stored at:

```text
~/Library/Application Support/LinkRouter/routing-config.json
```

## Development

Requirements:

- macOS 26
- Xcode 26.5
- Swift 6

Open `LinkRouter.xcodeproj` in Xcode, select the `LinkRouter` scheme and
`My Mac`, then press Run. LinkRouter runs as a menu bar app and does not show a
Dock icon.

Command-line build:

```sh
xcodebuild \
  -project LinkRouter.xcodeproj \
  -scheme LinkRouter \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Command-line tests:

```sh
xcodebuild \
  -project LinkRouter.xcodeproj \
  -scheme LinkRouter \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /private/tmp/LinkRouterDerivedDataTests \
  test
```

The browser-launch integration test is opt-in because it opens Safari. In
Xcode, temporarily add `LINKROUTER_RUN_BROWSER_LAUNCH_TESTS=1` to the scheme's
Run environment, run `BrowserTests/testExplicitSafariLaunchWhenEnabled`, then
remove the variable.

For a direct URL receipt check after running the app:

```sh
open -a LinkRouter 'https://example.com/private?token=secret'
```

The UI and diagnostics should display only:

```text
https://example.com
```

The path and query are intentionally removed.

## Documentation

- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md): setup, daily use, and manual verification
- [`docs/PRD.md`](docs/PRD.md): product requirements
- [`docs/PRODUCT.md`](docs/PRODUCT.md): product principles and positioning
- [`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md): architecture and technical decisions
- [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md): test checklist and compatibility notes
- [`docs/ROADMAP.md`](docs/ROADMAP.md): future features and improvement tracker
- [`docs/REPOSITORY_STRUCTURE.md`](docs/REPOSITORY_STRUCTURE.md): public/private file boundaries
- [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md): direct distribution and notarization notes
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md): release gate checklist
- [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md): current release notes
- [`docs/PRODUCT_REVIEW.md`](docs/PRODUCT_REVIEW.md): product and engineering review

## Repository Notes

Generated release archives live in `releases/` and are ignored by git. Private
developer notes live in `local/` and are also ignored.

Local signing settings such as `DEVELOPMENT_TEAM` should not be committed.

## License

LinkRouter is released under the MIT License. See [`LICENSE`](LICENSE).
