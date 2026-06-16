# LinkRouter

LinkRouter is a personal macOS utility that routes web links to different
browsers based on the app that opened the link.

Examples:

- Codex -> Google Chrome
- WeChat -> Safari
- Telegram -> Arc
- Unmatched apps -> configured fallback browser

## Current Status

The core routing pipeline is now executable:

- Native macOS SwiftUI project
- Menu bar app with a basic settings window
- `http` and `https` URL registration
- Apple Event URL receipt
- Best-effort source-app detection with method and confidence
- Launch Services browser discovery by bundle identifier
- Explicit destination-browser launch with loop prevention
- Deterministic source-app rule matching with stable priority
- Automatic Safari fallback when no rule matches
- One-time recovery fallback when a rule browser cannot be opened
- Versioned JSON configuration in Application Support
- Atomic configuration writes and non-destructive corruption recovery
- Graphical source-app rule add, edit, enable, disable, and delete controls
- Installed-browser pickers for rule destinations and fallback
- Settings controls for refreshing browsers and opening a test page
- Default-browser status display in Settings and the menu bar
- Routing decision and final-browser diagnostics
- Configuration path, schema, and recovery status diagnostics
- Privacy-conscious URL validation and logging
- Unit and integration tests for URL handling and browser launching

The initial persisted rules are:

- Codex -> Google Chrome
- WeChat -> Safari
- Unmatched or unknown source -> Safari

The configuration file is stored at:

```text
~/Library/Application Support/LinkRouter/routing-config.json
```

Onboarding and broader source-app compatibility testing are the next
development milestones.

## Editing Rules

Open LinkRouter Settings and use the **Routing rules** section:

1. Select **Add Rule**.
2. Enter a label and the source app's bundle identifier.
3. Choose an installed browser and priority.
4. Select **Save**.

Changes are validated and written atomically before the running router adopts
them. Delete actions require confirmation. Editing is disabled when LinkRouter
is protecting an unreadable configuration file.

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

- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md): setup, daily use, and manual verification
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

The browser-launch integration test is opt-in because it opens Safari. In
Xcode, temporarily add the `LINKROUTER_RUN_BROWSER_LAUNCH_TESTS=1`
environment variable to the scheme's Run action, run
`BrowserTests/testExplicitSafariLaunchWhenEnabled`, then remove the variable.

For a direct URL receipt check after running the app:

```sh
open -a LinkRouter 'https://example.com/private?token=secret'
```

The menu bar and settings window should display `https://example.com`. The
path and query are intentionally removed from default diagnostics.
