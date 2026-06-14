# LinkRouter

LinkRouter is a personal macOS utility that routes web links to different
browsers based on the app that opened the link.

Examples:

- Codex -> Google Chrome
- WeChat -> Safari
- Telegram -> Arc
- Unmatched apps -> configured fallback browser

## Current Status

The project is in the product definition and technical validation phase.
No application code has been created yet.

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

Full Xcode is required before the app target can be created and built.

