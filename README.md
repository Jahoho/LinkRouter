# LinkRouter

LinkRouter is a personal macOS utility that routes web links to different
browsers based on the app that opened the link.

Examples:

- Codex -> Google Chrome
- WeChat -> Safari
- Mail -> Safari
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
- Deterministic source-app rule matching with clear match order
- Automatic Safari fallback when no rule matches
- One-time recovery fallback when a rule browser cannot be opened
- Versioned JSON configuration in Application Support
- Atomic configuration writes and non-destructive corruption recovery
- Graphical source-app rule add, edit, enable, disable, and delete controls
- Installed-browser pickers for rule destinations and fallback
- Source app picker from recent and installed apps
- `.app` drag-and-drop source filling in the rule editor
- Source-app, domain, URL-scheme, and app-plus-domain rule conditions
- Optional Chromium browser profile selection for rules
- Conflict explanation when more than one rule matches
- Compact Default Apps tab for common file extensions
- Menu bar pause and next-link browser override controls
- JSON configuration import, export, and reset controls
- First-run setup guide with default-browser, rule creation, privacy, and backup guidance
- English / Chinese interface switch in Settings
- Compact native settings layout with Overview, Rules, Diagnostics, Default Apps, and Advanced tabs
- Native macOS-style application icon
- Lightweight personal install and manual release zip scripts
- Settings controls for refreshing browsers and opening a test page
- Default-browser status display in Settings and the menu bar
- One-click rule creation or editing from the last detected source app
- Recent source app list for creating or editing rules after testing several apps
- Recent routing history sheet with sanitized diagnostics and rule actions
- Launch at login setting
- Setup health sheet for default-browser, fallback, storage, startup, and diagnostics checks
- Routing decision and final-browser diagnostics
- Human-readable routing explanations for the latest decision and recent history
- Broken-rule warnings for missing browsers, invalid source bundle identifiers, and self-routing destinations
- Configuration path, schema, and recovery status diagnostics
- Privacy-conscious URL validation and logging
- Unit and integration tests for URL handling and browser launching

The initial persisted rules are:

- Codex -> Google Chrome
- WeChat -> Safari
- Mail -> Safari
- Unmatched or unknown source -> Safari

The configuration file is stored at:

```text
~/Library/Application Support/LinkRouter/routing-config.json
```

Broader source-app compatibility testing and external beta distribution are
the next development milestones.

## Editing Rules

Open LinkRouter Settings and use the **Routing rules** section:

1. Select **Add Rule**.
2. Enter a label and the source app's bundle identifier.
3. Choose an installed browser and match order.
4. Select **Save**.

Changes are validated and written atomically before the running router adopts
them. Delete actions require confirmation. Editing is disabled when LinkRouter
is protecting an unreadable configuration file.

Rules and the fallback browser show compact warnings when the destination
browser is unavailable, the destination points back to LinkRouter, or a stored
source bundle identifier is invalid. Healthy rules stay visually quiet.

Rule conditions are combined with AND semantics. For example, a rule can match
only Mail links to `*.github.com`, while a separate domain-only rule can match
GitHub links from any source app.

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
- [`docs/PRODUCT.md`](docs/PRODUCT.md): public product principles
- [`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md): architecture and technical decisions
- [`docs/TEST_PLAN.md`](docs/TEST_PLAN.md): MVP test checklist
- [`docs/ROADMAP.md`](docs/ROADMAP.md): future features and improvement tracker
- [`docs/REPOSITORY_STRUCTURE.md`](docs/REPOSITORY_STRUCTURE.md): public/private file boundaries
- [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md): direct distribution and notarization notes
- [`docs/RELEASE_CHECKLIST.md`](docs/RELEASE_CHECKLIST.md): release gate checklist
- [`docs/RELEASE_NOTES.md`](docs/RELEASE_NOTES.md): current release notes
- [`docs/PRODUCT_REVIEW.md`](docs/PRODUCT_REVIEW.md): product and engineering review after P4

## Development Environment

- Development machine: macOS 26
- Language: Swift 6
- UI: SwiftUI with AppKit where macOS integration requires it
- Version control: Git
- Xcode: 26.5

## Build and Test

For development:

Open `LinkRouter.xcodeproj` in Xcode, select the `LinkRouter` scheme and
`My Mac`, then press Run. LinkRouter runs as a menu bar app and does not show a
Dock icon.

For standalone personal use:

```sh
scripts/install_release_app.sh
```

The script builds a Release app, installs it to `/Applications/LinkRouter.app`,
and registers it with Launch Services. Open it from `/Applications`, then set
that installed app as the macOS default web browser. After that, normal use
does not require Xcode.

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
