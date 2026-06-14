# AGENTS.md

## Project

LinkRouter is a native macOS app that receives `http` and `https` URLs and
routes them to a browser according to source-application rules.

Read these documents before changing behavior:

- `docs/PRD.md`
- `docs/TECHNICAL_DESIGN.md`
- `docs/ROADMAP.md`
- `docs/TEST_PLAN.md`

## Communication

- Communicate with the user in Chinese.
- Keep code identifiers, filenames, and code comments in English.
- Explain the plan and wait for confirmation before multi-file changes,
  dependency installation, deletion, or irreversible operations.
- Prefer simple, readable Swift suitable for a learner.

## Engineering Rules

- Use Swift, SwiftUI, and AppKit only where needed.
- Keep URL receipt, source detection, rule matching, browser launching,
  persistence, and logging in separate modules.
- Treat source-app detection as best-effort. Never present an inferred source
  as certain without recording the detection method and confidence.
- Avoid Accessibility permission in the MVP unless tests prove it necessary
  and the user approves the added permission.
- Match installed apps by bundle identifier, not localized display name.
- Prevent routing loops when the selected browser resolves to LinkRouter.
- Do not log full URLs by default. Store only scheme, host, timestamp, routing
  result, and non-sensitive diagnostics.
- Update `docs/ROADMAP.md` whenever a future feature or improvement is
  discovered, deferred, started, or completed.
- Update `docs/TEST_PLAN.md` when routing behavior or supported scenarios
  change.

## Git

- The default branch is `main`.
- Keep commits focused and use clear imperative commit messages.
- Do not commit build output, user-specific Xcode data, local configuration,
  or diagnostic logs.
- Never use destructive Git commands without explicit user approval.

