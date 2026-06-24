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
| Routing result explanation | Done | MVP | Latest result and recent history explain source, matched rule or fallback, recovery, and final browser |
| Broken rule warnings | Done | MVP | Compact warnings for missing browsers, self-routing destinations, invalid source bundle identifiers, and fallback issues |
| App picker from recent and installed apps | Done | Post-MVP | Rule editor can choose recent or installed apps without manual bundle identifier lookup |
| Drag `.app` into rule editor | Done | Post-MVP | Dropped app bundles fill source name and bundle identifier |
| Rule quick templates | Done | Post-MVP | Rule editor can quickly switch destination browser and rename the rule |
| Drag-to-reorder rule priority | Planned | Post-MVP | Current UI uses an explicit numeric priority |
| Menu bar pause/quick controls | Done | Post-MVP | Pause for ten minutes and route only the next link to a selected browser |
| Temporary browser chooser | Deferred | Later | Next-link override covers the lightweight case; modal queue is postponed |
| Domain rules | Done | Post-MVP | Exact host and wildcard subdomain matching through `hostPattern` |
| App plus domain rules | Done | Post-MVP | Reuses existing AND semantics and priority system |
| Rule conflict explanation | Done | Post-MVP | Routing explanations list skipped lower-priority matching rules |
| Recent link history | Done | MVP | In-memory last 20 routing results with sanitized URLs and rule actions |
| iCloud rule sync | Deferred | Later | Requires migration and conflict strategy |
| Import/export configuration | Done | Post-MVP | Versioned JSON import, export, and reset controls in Settings |
| Lightweight release size check | Done | Post-MVP | Release app bundle is approximately 1.7M with no extra asset packs or third-party frameworks |
| Onboarding | Done | Productization | First-run setup guide plus menu bar entry for re-opening it |
| Installed browser detection | Done | MVP | Launch Services handlers are listed in Settings by bundle identifier |
| Login at startup | Done | MVP | Settings toggle backed by `SMAppService` |
| Version update mechanism | Deferred | Distribution | Manual zip release is enough until external testers need automatic updates |
| Developer ID signing and notarization | Research | External beta | Distribution notes document the direct notarization flow; real Developer ID validation remains |
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
| 2026-06-24 | Explain routing results | Done | Settings and recent history show why each link used a rule, fallback, or recovery path |
| 2026-06-24 | Warn about broken rules | Done | Rules and fallback display compact warnings for unavailable destinations, LinkRouter loops, and invalid source bundle identifiers |
| 2026-06-24 | Add app picker and `.app` drop source filling | Done | Rule creation no longer requires manually finding bundle identifiers |
| 2026-06-24 | Expose domain and app-plus-domain rules | Done | Reused stored `hostPattern` and `urlScheme` fields with validation |
| 2026-06-24 | Add menu bar pause and next-link override | Done | Lightweight alternative to a heavier per-link chooser queue |
| 2026-06-24 | Add configuration import/export/reset | Done | Local JSON workflow for backup and tester sharing |
| 2026-06-24 | Check release app size | Done | Release bundle measured at about 1.7M |
| 2026-06-24 | Add first-run setup guide | Done | Settings explains default browser setup, test links, rule creation, privacy, and backups |
| 2026-06-24 | Add lightweight release zip flow | Done | Manual zip script verified against a Release app; zip measured about 424K |
