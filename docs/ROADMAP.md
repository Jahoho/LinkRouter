# LinkRouter Roadmap

This is the single source of truth for future features, deferred improvements,
and product follow-ups. Add new ideas here instead of leaving them only in
chat. Update status and notes whenever work begins or behavior changes.

Status values:

- `Planned`: accepted, not started
- `Research`: needs validation or a technical spike
- `In Progress`: currently being implemented
- `Done`: implemented and verified
- `Deferred`: intentionally postponed

## MVP Milestones

| Item | Status | Notes |
|---|---|---|
| Product requirements and technical design | Done | Initial baseline created 2026-06-15 |
| Install or select full Xcode | Done | Xcode 26.5 selected and license accepted |
| Create signed macOS app target | Done | SwiftUI menu bar app plus AppKit lifecycle bridge |
| Register and receive `http` / `https` URLs | Done | Apple Event handler verified with a real URL on 2026-06-15 |
| Source-detection probe | Done | Sender PID, frontmost app, recent-app cache, confidence, and diagnostics implemented |
| Source-app compatibility testing | In Progress | Real clicks from Codex, WeChat, Telegram, Obsidian, Finder, and Terminal remain |
| Browser discovery and explicit launch | Done | Safari and Chrome discovered; explicit Safari launch verified 2026-06-15 |
| Source-app rule engine and fallback | Planned | Pure Swift with unit tests |
| Versioned local configuration | Planned | Atomic JSON in Application Support |
| Menu bar and basic settings window | In Progress | Listener status and sanitized last URL implemented; rules and fallback remain |
| MVP test cycle | Planned | Use `TEST_PLAN.md` and fill compatibility matrix |

## Feature Backlog

| Feature | Status | Target | Notes |
|---|---|---|---|
| Graphical rule management | Planned | Post-MVP | Add, edit, enable, disable, reorder |
| Menu bar pause/quick controls | Planned | Post-MVP | Temporary bypass and status |
| Temporary browser chooser | Planned | Post-MVP | Useful when source confidence is low |
| Domain rules | Planned | Post-MVP | Exact host and subdomain matching |
| App plus domain rules | Planned | Post-MVP | Deterministic priority and conflict UI |
| Recent link history | Planned | Post-MVP | Sanitized by default with retention limit |
| iCloud rule sync | Deferred | Later | Requires migration and conflict strategy |
| Import/export configuration | Planned | Post-MVP | Versioned JSON with validation |
| Rule conflict detection | Planned | Post-MVP | Explain which rule wins |
| Onboarding | Planned | Productization | Default-browser and privacy guidance |
| Installed browser detection | Done | MVP | Launch Services handlers are listed in Settings by bundle identifier |
| Login at startup | Planned | Post-MVP | Use `SMAppService` |
| Version update mechanism | Deferred | Distribution | Evaluate Sparkle or managed delivery |
| Developer ID signing and notarization | Planned | External beta | Needed for smooth tester installation |
| App Store feasibility review | Research | Later | Reassess sandbox and review constraints |

## Technical Research

| Topic | Status | Question |
|---|---|---|
| Apple Event sender identity | Research | Which target apps preserve a useful sender PID? |
| Helper-process normalization | Research | Can Codex, WeChat, Telegram, and Obsidian helpers be mapped safely? |
| Recent-app cache window | Research | What time window improves recall without causing false matches? |
| Accessibility detector | Deferred | Does it materially improve accuracy enough to justify permission? |
| Lower deployment target | Deferred | After MVP, should support extend below macOS 26? |
| App Sandbox | Research | Can all required behavior pass tests with sandbox enabled? |

## Improvement Log

| Date | Improvement | Status | Notes |
|---|---|---|---|
| 2026-06-15 | Keep full URLs out of default logs | Done | Log only scheme and host plus routing metadata |
| 2026-06-15 | Record detection method and confidence | Done | Requirement added before implementation |
| 2026-06-15 | Prevent self-routing loops | Done | Added to architecture and acceptance criteria |
| 2026-06-15 | Validate incoming URL before routing | Done | MVP accepts only HTTP and HTTPS URLs with a host |
| 2026-06-15 | Add executable URL-receipt milestone | Done | Real Apple Event test logged only `https://example.com` |
| 2026-06-15 | Add layered source-app detection | Done | Sender PID -> frontmost app -> five-second recent-app cache -> unknown |
| 2026-06-15 | Expose detection confidence and reason | Done | Menu bar, settings, and Unified Logging show diagnostics |
| 2026-06-15 | Discover installed HTTPS handlers | Done | Safari and Chrome found through Launch Services |
| 2026-06-15 | Launch an explicit browser safely | Done | Modern `NSWorkspace` API, completion errors, and self-loop prevention |
| 2026-06-15 | Add opt-in browser integration test | Done | Safari launch test stays skipped during normal test runs |
