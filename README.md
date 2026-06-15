# LinkRouter

LinkRouter is a personal macOS utility that routes web links to different
browsers based on the app that opened the link.

Examples:

- Codex -> Google Chrome
- WeChat -> Safari
- Telegram -> Arc
- Unmatched apps -> configured fallback browser

## Current Status

The first executable milestone is complete:

- Native macOS SwiftUI project
- Menu bar app with a basic settings window
- `http` and `https` URL registration
- Apple Event URL receipt
- Privacy-conscious URL validation and logging
- Unit tests for URL validation and sanitization

Source-app detection and browser routing are the next development milestones.

## MVP Scope

- Run as a menu bar app with a settings window.
- Register as the handler for `http` and `https` URLs.
- Detect the likely source app using best-effort signals.
- Match source-app rules and launch the selected browser.
- Fall back to a configured browser when detection or matching fails.
- Keep privacy-conscious local diagnostic logs.

Source-app detection is inherently best-effort on macOS. See
[`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md) for the limitations and
fallback strategy.

## Documentation

- [`docs/PRD.md`](docs/PRD.md): product requirements
- [`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md): architecture and technical decisions
- [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md): MVP test checklist
- [`docs/ROADMAP.md`](docs/ROADMAP.md): future features and improvement tracker

## Development Environment

- Development machine: macOS 26
- Language: Swift 6
- UI: SwiftUI with AppKit where macOS integration requires it
- Version control: Git
- Xcode: 26.5

## Build and Test

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

For a direct URL receipt check after running the app:

```sh
open -a LinkRouter 'https://example.com/private?token=secret'
```

The menu bar and settings window should display `https://example.com`. The
path and query are intentionally removed from default diagnostics.
