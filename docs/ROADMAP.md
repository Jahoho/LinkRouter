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
| Source-app rule engine and fallback | Done | Seed rules, stable priority, serialized routing, and one-time recovery fallback verified |
| Versioned local configuration | Done | Schema v1 JSON, atomic writes, preserved corrupt files, and in-memory recovery verified |
| Menu bar and basic settings window | In Progress | Routing diagnostics, rule editing, and default-browser status are implemented; onboarding remains |
| MVP test cycle | Planned | Use `TEST_PLAN.md` and fill compatibility matrix |

## Feature Backlog

| Feature | Status | Target | Notes |
|---|---|---|---|
| Graphical source-app rule management | Done | MVP | Add, edit, enable, disable, delete, choose browser, and edit priority |
| Create rule from last detected source | Done | MVP | Avoids requiring users to manually type bundle identifiers for new apps |
| Recent source app list | Done | MVP | Keeps recently detected sources available for rule creation and editing |
| Setup health panel | Done | MVP | Compact health sheet for default browser, fallback, config, startup, and diagnostics |
| Drag-to-reorder rule priority | Planned | Post-MVP | Current UI uses an explicit numeric priority |
| Menu bar pause/quick controls | Planned | Post-MVP | Temporary bypass and status |
| Temporary browser chooser | Planned | Post-MVP | Useful when source confidence is low |
| Domain rules | Planned | Post-MVP | Exact host and subdomain matching |
| App plus domain rules | Planned | Post-MVP | Deterministic priority and conflict UI |
| Recent link history | Done | MVP | In-memory last 20 routing results with sanitized URLs and rule actions |
| iCloud rule sync | Deferred | Later | Requires migration and conflict strategy |
| Import/export configuration | Planned | Post-MVP | Versioned JSON with validation |
| Rule conflict detection | Planned | Post-MVP | Explain which rule wins |
| Onboarding | Planned | Productization | Default-browser and privacy guidance |
| Installed browser detection | Done | MVP | Launch Services handlers are listed in Settings by bundle identifier |
| Login at startup | Done | MVP | Settings toggle backed by `SMAppService` |
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
| 2026-06-15 | Add deterministic source-app RuleEngine | Done | Priority descending, stable order, enabled rules, and fallback covered by tests |
| 2026-06-15 | Serialize incoming routing jobs | Done | Browser launch requests are processed in arrival order |
| 2026-06-15 | Add one-time recovery fallback | Done | Missing or failed rule destination attempts configured fallback once without rematching |
| 2026-06-15 | Persist schema v1 routing configuration | Done | First launch writes seed JSON; later launches load without overwriting |
| 2026-06-15 | Preserve unreadable configuration | Done | Invalid JSON and unsupported schema remain untouched while safe defaults run in memory |
| 2026-06-15 | Expose configuration health | Done | Settings shows file path, schema version, load state, and recovery detail |
| 2026-06-15 | Add graphical source-app rule editor | Done | Explicit Save validates and persists before applying changes |
| 2026-06-15 | Protect hidden future rule fields | Done | Editing source-only fields preserves stored host and URL scheme conditions |
| 2026-06-15 | Confirm destructive rule deletion | Done | Settings requires a confirmation action before deleting |
| 2026-06-16 | Add default-browser candidate declarations | Done | Added display name, HTML document types, and app category so Launch Services can classify LinkRouter as a browser candidate |
| 2026-06-16 | Document macOS 26 signing requirement | Done | Ad-hoc builds can run but are rejected as trusted default-browser candidates; Xcode Personal Team signing is required |
| 2026-06-16 | Verify signed default-browser setup | Done | User confirmed Apple Development signed build can be selected and manually tested as the default browser |
| 2026-06-16 | Show current default-browser status | Done | Settings and menu bar read the current HTTPS handler without extra permissions |
| 2026-06-16 | Add Apple Mail seed rule | Done | `com.apple.mail` routes to Safari in the seed configuration and rule-engine tests |
| 2026-06-16 | Create or edit rules from last source | Done | Settings pre-fills rule fields from the last credible source app and edits existing source rules to avoid duplicates |
| 2026-06-16 | Add recent source app list | Done | Users can test several apps and then create or edit rules from a de-duplicated recent source list |
| 2026-06-24 | Add recent routing history sheet | Done | Last 20 in-memory sanitized routing results can create or edit source rules without crowding Settings |
| 2026-06-24 | Add launch at login setting | Done | Settings can register or unregister LinkRouter with `SMAppService` |
| 2026-06-24 | Add setup health panel | Done | Settings summarizes runtime health checks and opens detailed setup diagnostics in a sheet |
