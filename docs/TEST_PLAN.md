# LinkRouter MVP Test Plan

## Test Environment Record

Record these before each test cycle:

- macOS version
- LinkRouter build and commit
- installed browser versions and bundle identifiers
- source app versions and bundle identifiers
- whether LinkRouter is the current default browser
- permissions granted to LinkRouter

## Milestone Verification

### 2026-06-15: URL Receipt

- Environment: macOS 26, Xcode 26.5, Apple Silicon
- Build: Debug, local signing
- Automated result: 4 unit tests passed
- Runtime result: LinkRouter launched as a menu bar app and received
  `https://example.com/private/path?token=secret#section`
- Privacy result: Unified Logging contained only
  `Received URL: https://example.com`
- Not covered yet: selecting LinkRouter as the system default browser, source
  detection, rule matching, and destination browser launch

### 2026-06-15: Source Detection Probe

- Automated result: 7 unit tests passed
- Implemented order: Apple Event sender PID, frontmost app, five-second
  recent-app cache, then unknown
- Confirmed installed bundle identifiers:
  - Codex: `com.openai.codex`
  - WeChat: `com.tencent.xinWeChat`
  - Obsidian: `md.obsidian`
- A command-line `open -a LinkRouter URL` request produced `unknown` when the
  sender exited and the command environment exposed no frontmost GUI app. This
  is expected fallback behavior, not a successful source-app compatibility
  result.
- A test attempt confirmed that `keySenderPIDAttr` is read-only and cannot be
  meaningfully fabricated on a local Apple Event descriptor. Sender behavior
  must be measured using real clicks from each source app.
- No Accessibility, Automation, Screen Recording, or Input Monitoring
  permission was requested.

### 2026-06-15: Browser Discovery and Explicit Launch

- Automated result: 11 tests passed and 1 opt-in integration test skipped
  during the normal test run.
- Runtime discovery result: Launch Services returned:
  - Safari: `com.apple.Safari`
  - Google Chrome: `com.google.Chrome`
- Loop-prevention result: LinkRouter is excluded as a browser destination.
- Explicit launch result: the opt-in integration test passed and opened
  `https://example.com` in Safari using its bundle identifier.
- No Accessibility or AppleScript Automation permission was requested.

### 2026-06-15: Rule Engine and Fallback Routing

- Automated result: 19 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Seed-rule result:
  - `com.openai.codex` selects `com.google.Chrome`.
  - `com.tencent.xinWeChat` selects `com.apple.Safari`.
  - `com.apple.mail` selects `com.apple.Safari`.
  - Unknown or unmatched sources select fallback `com.apple.Safari`.
- Ordering result: higher match order wins; equal match order preserves
  configuration order; disabled rules do not match.
- Runtime coordinator behavior: requests are queued and processed in arrival
  order; a failed matched destination attempts fallback once.
- Real fallback result: a direct URL event with unknown source selected
  `com.apple.Safari` and opened successfully. Unified Logging retained only
  `https://example.com`, excluding the test path and query token.
- Not covered yet: real source clicks from Codex and WeChat and
  missing-browser runtime recovery.

### 2026-06-15: Versioned Configuration Persistence

- Automated result: 25 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Temporary-directory coverage:
  - Missing configuration creates the schema v1 seed.
  - Existing valid configuration loads unchanged.
  - Saving replaces the previous configuration atomically.
  - Invalid JSON remains byte-for-byte unchanged while the seed runs in memory.
  - Unsupported schema remains byte-for-byte unchanged.
  - Saving an unsupported schema is rejected.
- Real storage result:
  - First host launch created
    `~/Library/Application Support/LinkRouter/routing-config.json`.
  - Second app launch logged `Loaded from disk`.
  - The file modification timestamp did not change on the second launch.
- T17 and the persistence portion of T18 are covered automatically.
- Rule editing coverage continues in the next milestone record.

### 2026-06-15: Graphical Source-App Rule Management

- Automated result: 34 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Editing coverage:
  - Draft values are trimmed and validated before conversion to a rule.
  - Invalid source bundle identifiers are rejected.
  - Rules can be added, updated, enabled, disabled, and deleted.
  - Duplicate rule identifiers are rejected.
  - Installed browsers can become the configured fallback.
  - Hidden future host and URL scheme conditions survive source-only edits.
  - AppState persists accepted edits before updating the active configuration.
  - Editing is blocked when an unreadable file is being preserved.
- Safety result: the real Application Support configuration retained its
  original size and modification timestamp throughout automated tests.
- Visual UI automation was attempted, but the desktop automation channel
  timed out before any click. Manual visual verification remains:
  - Open Settings and confirm the seed rules are visible.
  - Open Add Rule and confirm Safari and Chrome are available.
  - Confirm invalid input stays in the sheet with an error.
  - Confirm Delete presents a destructive confirmation.

### 2026-06-16: Default Browser Candidate Diagnostics

- Problem observed: LinkRouter could run, but did not appear in macOS 26
  `Default web browser` choices.
- Metadata fix: `Info.plist` now declares LinkRouter as an alternate handler
  for both `http` / `https` URL schemes and `public.html` / `public.xhtml`
  document types.
- Build artifact issue: a debug build product contained `com.apple.FinderInfo`,
  which caused `CodeSign failed: resource fork, Finder information, or similar
  detritus not allowed`. Cleaning extended attributes on the build product
  allowed signing to complete.
- Remaining requirement: macOS 26 rejected ad-hoc signed builds as trusted
  default-browser candidates. Diagnostics showed `Signature=adhoc`,
  `TeamIdentifier=not set`, `security find-identity` returned
  `0 valid identities found`, and Launch Services logged
  `Failed to register trusted: NSOSStatusErrorDomain/-67062`.
- Verification requirement: before T11 can pass, the installed app must be
  signed with an Apple Development identity from Xcode's `Personal Team`.
- Manual verification: after selecting an Apple Development signing identity
  in Xcode, the user confirmed LinkRouter appeared in the macOS default-browser
  flow and manual default-browser testing passed on 2026-06-16.

### 2026-06-16: Default Browser Status Display

- Automated result: 39 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Status behavior:
  - Settings and the menu bar show whether LinkRouter is the current HTTPS
    default handler.
  - The status is refreshed during browser discovery and by the
    `Refresh Default Browser Status` button.
  - Unit coverage confirms LinkRouter, another browser, and unknown handler
    states.
- Permission result: no Accessibility, Automation, or AppleScript permission
  was requested.

### 2026-06-16: Create Rule from Last Source

- Automated result: 39 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Rule creation behavior:
  - `RoutingRuleDraft` can prefill source app name, source bundle identifier,
    rule name, match order, and destination browser from a detected source app.
  - `Routing rules` shows the last detected credible source app.
  - If no rule exists for that source, Settings offers
    `Create Rule from This App`.
  - If a rule already exists, Settings offers `Edit Rule for This App` to avoid
    duplicate source rules.
  - Low- or medium-confidence source detection displays a warning before save.
- Product result: adding a new source app no longer requires hard-coding the
  app in the seed configuration.

### 2026-06-16: Recent Source App List

- Build result: app build and `build-for-testing` passed.
- Full test run: not completed in this cycle because the sandbox-external
  xcodebuild approval request timed out twice.
- Recent-source behavior:
  - AppState keeps the most recent credible source apps in memory.
  - Re-seeing the same bundle identifier moves it to the top instead of
    creating a duplicate.
  - Unknown and non-credible sources, including LinkRouter itself, are ignored.
  - Settings shows `Recent source apps`; each row can create a new rule or edit
    the existing rule for that source.
- Product result: users can test several apps first, then create rules from the
  recent source list without typing bundle identifiers.

### 2026-06-24: Recent Routing History and Launch at Login

- Automated result: 42 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Recent history behavior:
  - AppState keeps the most recent 20 routing results in memory.
  - The history sheet is opened from a button, so Settings does not become
    crowded.
  - Each history item stores sanitized URL, source app, detection method,
    confidence, matched rule, selected browser, final browser, and error state.
  - Unknown-source records are visible but cannot create rules.
  - Source-backed records can open the rule editor to create or edit a rule.
  - URL path, query, fragment, credentials, and tokens remain omitted.
- Launch at login behavior:
  - Settings includes a `Launch at login` toggle backed by `SMAppService`.
  - The UI shows enabled, disabled, requires-approval, and unavailable states.
  - No Accessibility, Automation, or AppleScript permission was requested.

### 2026-06-24: Setup Health Panel

- Automated result: 44 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Health behavior:
  - Settings shows a compact `View Setup Health` button and summary.
  - The health sheet checks URL listener, default browser, configuration
    storage, fallback browser, source detection, routing history, and launch at
    login.
  - Missing runtime signals are warnings rather than hard failures.
  - Broken configuration or unavailable fallback browser appears as an error.
- Product result: setup and debugging state are visible without making the main
  Settings page crowded.

### 2026-06-24: Routing Explanations and Rule Health Warnings

- Automated result: 50 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Explanation behavior:
  - The latest routing result explains detected source app, matched rule or
    fallback, recovery fallback, final browser, and error state.
  - Recent routing history stores the same explanation lines for each
    sanitized record.
- Rule health behavior:
  - Rules warn when their destination browser is unavailable.
  - Rules warn when their destination points back to LinkRouter.
  - Rules warn when a stored source bundle identifier is malformed.
  - The fallback browser warns when it is unavailable or points back to
    LinkRouter.
- Product result: diagnostics became more understandable without adding a heavy
  always-visible table or changing the configuration schema.

### 2026-06-24: P1-P3 Lightweight Feature Pass

- Automated result: 58 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Release size result:
  - Release `.app` bundle: approximately `1.7M`
  - Main executable: approximately `1.7M`
  - No bundled third-party frameworks, image packs, scripts, or large assets.
- Rule creation behavior:
  - Rule editor can choose a source app from recent or installed apps.
  - Rule editor accepts dropped `.app` bundles to fill source name and bundle
    identifier.
  - Quick templates can switch the destination browser without exposing bundle
    identifiers.
- Smarter routing behavior:
  - Domain-only rules are supported through `hostPattern`.
  - App-plus-domain rules use existing AND semantics.
  - Other matching rules checked later are stored in the routing explanation.
- Daily control behavior:
  - Menu bar can pause routing for ten minutes.
  - Menu bar can route only the next link to a selected browser.
  - Configuration can be exported, imported, or reset from Settings.
- Product result: P1-P3 are covered with lightweight local UI and no new
  runtime dependency.

### 2026-06-24: P4 Productization Pass

- Automated result: 62 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Release result:
  - Release `.app` build succeeded.
  - Release `.app` bundle measured approximately `1.8M`.
  - Main executable measured approximately `1.7M`.
  - Manual zip created successfully and measured approximately `424K`.
- Onboarding behavior:
  - First launch attempts to open Settings.
  - Settings shows a compact setup guide until marked complete.
  - Setup guide can be reopened from the menu bar.
  - Completion state persists in `UserDefaults`.
- Distribution behavior:
  - Added lightweight direct-distribution notes.
  - Added `scripts/create_release_zip.sh` for manual zipped app releases.
- Configuration hardening:
  - Import and save reject LinkRouter as the fallback browser.
  - Import and save reject malformed rule conditions.
  - Invalid saved configurations are preserved and replaced by safe in-memory
    defaults at runtime.
- Product result: P4 is covered without adding an updater framework or
  installer package.

### 2026-06-24: Bilingual and Compact Settings Pass

- Automated result: 63 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Release size result:
  - Release `.app` bundle measured approximately `1.9M`.
  - Main executable measured approximately `1.9M`.
- Language behavior:
  - Settings can switch the interface between English and Chinese.
  - The language preference persists through `UserDefaults`.
  - Menu bar, onboarding, setup health, settings sections, rule editor, and
    routing history cover the main bilingual user paths.
- Settings layout behavior:
  - Settings is now split into Overview, Rules, Diagnostics, and Advanced tabs.
  - The layout remains native SwiftUI/AppKit without custom visual framework or
    bundled assets.
- Product result: the interface is more compact while keeping the app
  lightweight.

### 2026-06-24: Source Compatibility Report

- Automated result: 64 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Diagnostics behavior:
  - The Diagnostics tab shows a compact `Source compatibility` section.
  - The report is folded behind a disclosure control so Settings stays light.
  - Recent sanitized routing history is grouped by source app.
  - Each source app shows sample count, confidence mix, detection methods, and
    a reliability label.
  - Unknown-source samples are counted separately.
- Privacy result:
  - No new permanent history store was added.
  - The report is derived from the existing last 20 sanitized routing results.
- Product result:
  - LinkRouter now helps the user decide which source-app rules are
    trustworthy before adding more automation.

### 2026-06-24: P1-P2 Differentiated Feature Pass

- Automated result: 69 tests passed and 1 opt-in browser integration test
  skipped during the normal test run.
- Browser profile behavior:
  - LinkRouter discovers Chromium-family browser profiles from local profile
    metadata when available.
  - Rule editor shows a `Browser profile` picker only for browsers with
    detected profiles.
  - Saved rules can target a specific profile through `--profile-directory`
    without AppleScript permissions.
  - Switching the destination browser clears incompatible profile selections.
- Default Apps behavior:
  - Settings includes a separate `Default Apps` tab.
  - `.md`, `.pdf`, `.csv`, `.json`, and `.txt` defaults are shown through
    user-friendly extensions instead of raw UTI identifiers.
  - Changes use Launch Services and affect global macOS defaults.
  - The module remains separate from link routing rules to keep the core app
    lightweight.
- Product result:
  - P1 adds a clear differentiator for work/personal browser contexts.
  - P2 addresses an adjacent user pain without turning LinkRouter into a broad
    default-app suite.
- Lightweight result:
  - Release `.app` bundle measured approximately `2.2M`.

### 2026-06-25: Match Order and Repository Boundaries

- Copy behavior:
  - User-facing UI says `Match order` / `匹配顺序`.
  - Settings explains that higher numbers are checked first only when multiple
    rules match.
  - The stored `priority` field remains unchanged for configuration
    compatibility.
- Repository behavior:
  - Public product principles now live in `docs/PRODUCT.md`.
  - Public/private/generated file boundaries are documented in
    `docs/REPOSITORY_STRUCTURE.md`.
  - `local/` remains ignored and now contains a local-only README.
  - `releases/` is ignored because release zips are generated artifacts.
- Distribution behavior:
  - `scripts/build_release_app.sh` builds a standalone Release `.app`.
  - `scripts/install_release_app.sh` builds, installs, and registers
    `/Applications/LinkRouter.app`.
  - `docs/RELEASE_CHECKLIST.md` tracks personal install, local zip, and
    external tester release gates.
  - `docs/DISTRIBUTION.md` distinguishes personal `/Applications` installs
    from Developer ID notarized external tester builds.
- Automated verification:
  - Full test run passed with 69 passing tests and 1 opt-in browser launch
    test skipped.
  - `scripts/build_release_app.sh /private/tmp/LinkRouterStandaloneBuild`
    produced a Release `LinkRouter.app`.
  - Release `.app` bundle measured approximately `2.2M`.

## Core Checklist

| ID | Scenario | Steps | Expected result |
|---|---|---|---|
| T01 | Codex opens a link | Click an external web link in Codex | URL reaches LinkRouter; source evidence identifies Codex with stated confidence; Chrome opens; sanitized log records matched rule |
| T02 | WeChat opens a link | Click an external web link in WeChat | URL reaches LinkRouter; credible WeChat source matches; Safari opens; sanitized log records matched rule |
| T03 | Mail opens a link | Click an external web link in Mail | URL reaches LinkRouter; credible Mail source matches; Safari opens; sanitized log records matched rule |
| T04 | Telegram opens a link | Configure a Telegram rule, then click a link | Configured browser opens; source method and confidence are logged |
| T05 | Obsidian opens a link | Click an external link in Obsidian | If no rule exists, fallback Safari opens; any inferred source is recorded honestly |
| T06 | Finder opens a link | Open a `.webloc` file in Finder | URL reaches LinkRouter; Finder is detected when evidence supports it, otherwise fallback is used |
| T07 | Terminal opens a link | Run `open https://example.com` | URL reaches LinkRouter; Terminal may be detected or marked unknown; fallback opens without looping |
| T08 | Destination browser missing | Configure a rule for an unavailable browser and trigger it | LinkRouter reports destination unavailable and attempts fallback once |
| T09 | Invalid URL | Send malformed or unsupported URL input in a debug test | No browser launches; app stays running; sanitized validation error is logged |
| T10 | Permission denied | Run without optional permissions | MVP still routes because it requires no Accessibility permission; no repeated permission prompts appear |
| T11 | Not default browser | Select another default browser and launch LinkRouter | Settings and menu bar show the current default handler; direct test events may work, but LinkRouter does not claim system-wide routing unless it is default |
| T12 | Multiple browsers installed | Install/select Safari, Chrome, and Arc | Browser discovery lists installed browsers by bundle identifier and launches the exact selected app |

## Reliability Tests

| ID | Scenario | Expected result |
|---|---|---|
| T13 | Ten rapid links from one app | All valid URLs are handled once and in arrival order; no crashes or duplicate launches |
| T14 | Links from two apps in quick succession | Each request carries its own detection evidence; the recent-app cache does not leak one decision into all requests |
| T15 | LinkRouter selected as destination | Configuration is rejected or launcher blocks it; no recursive loop |
| T16 | Fallback browser missing | A clear error appears; no repeated launch attempts |
| T17 | Corrupted configuration | App preserves the bad file, loads a safe in-memory default, and explains the recovery state |
| T18 | Relaunch after configuration | Rules and fallback persist and produce the same result |
| T19 | URL with query token | Default logs omit path, query, fragment, credentials, and token |
| T20 | App helper sends event | Detector either maps a tested helper to its owner or lowers confidence; it does not invent a high-confidence source |
| T21 | Create rule from recent source | Open a link from a source without a rule, then click `Create Rule from This App` in `Recent source apps` | The editor is prefilled with the detected app and lets the user choose a browser without manually typing a bundle identifier |
| T22 | Edit rule from recent source | Open a link from a source with an existing rule, then click `Edit Rule for This App` | The existing rule opens for editing instead of creating a duplicate |
| T23 | Multiple recent sources | Open links from several apps before creating a rule | Each credible source appears once in `Recent source apps`, with the newest source first |
| T24 | View recent routing history | Route several links, then click `View Recent Routing History` | A sheet opens with the most recent sanitized routing records; Settings main page stays compact |
| T25 | Create rule from history | Open a history item with a detected source app and click `Create or Edit Rule` | The rule editor opens for that source app without manually typing a bundle identifier |
| T26 | Unknown history item | Route a link with unknown source and open history | The item is visible for debugging, but rule creation is disabled for that row |
| T27 | Launch at login | Toggle `Launch at login` in Settings | LinkRouter registers or unregisters with `SMAppService` and shows the current status |
| T28 | Setup health panel | Click `View Setup Health` in Settings | A compact sheet shows setup checks with OK, warning, or error states |
| T29 | Latest routing explanation | Route a link, then inspect `Last routing result` | Settings explains the detected source, matched rule or fallback, final browser, and recovery/error state |
| T30 | Broken rule warning | Create or load a rule whose destination browser is unavailable or LinkRouter itself | Routing rules show a compact warning before the user discovers the problem through a failed click |
| T31 | Choose source app from picker | Add a rule and click `Choose Source App` | Recent and installed apps can fill source app name and bundle identifier |
| T32 | Drop `.app` into rule editor | Drag an app bundle into the rule editor | Source app name and bundle identifier are filled automatically |
| T33 | Domain-only rule | Create `*.github.com -> Chrome`, then open a GitHub URL from an unmatched app | Domain rule opens the configured browser |
| T34 | App plus domain rule | Create `Mail + *.github.com -> Chrome`, then open GitHub and non-GitHub links from Mail | Only matching Mail GitHub links use the combined rule |
| T35 | Conflict explanation | Create two matching rules with different match-order values | The higher match order wins and `Why this happened` lists other matching rules checked later |
| T36 | Pause routing | Click `Pause Routing for 10 Minutes`, then open a link | Rules are bypassed and the fallback browser opens |
| T37 | Next-link override | Choose `Open Next Link With`, then open two links | First link uses selected browser; second link returns to normal rules |
| T38 | Export/import config | Export JSON, reset defaults, import JSON | Exported rules return after import |
| T39 | First-run setup guide | Launch with onboarding incomplete | Settings opens and the setup guide explains default browser, testing, privacy, and backup |
| T40 | Reopen setup guide | Click menu bar `Setup Guide` | Settings opens and the setup guide is shown again |
| T41 | Manual release zip | Run `scripts/create_release_zip.sh` against a Release `.app` | A timestamped zip is created and keeps the app bundle structure |
| T42 | Switch interface language | Change `Language` in Overview | Main Settings, menu bar, onboarding, and setup health switch between English and Chinese |
| T43 | Compact settings navigation | Open each Settings tab | Overview, Rules, Diagnostics, and Advanced each show focused content without one long crowded page |
| T44 | Source compatibility report | Open links from several apps, then expand `Source compatibility` in Diagnostics | Apps are grouped by source, unknown samples are counted, and reliability labels reflect recent confidence |
| T45 | Browser profile rule | Open a rule whose destination browser has detected profiles, choose a profile, save, then route a matching link | The destination browser opens with the selected profile and diagnostics show the profile name |
| T46 | Default Apps tab | Open `Default Apps`, change `.md` to a candidate editor, then refresh | macOS reports the new current default app for `.md`; link routing rules are unchanged |
| T47 | Rule check order controls | Select a rule, move it with `Move Up` / `Move Down`, then route a link that matches multiple rules | The moved rule is checked in the new position and the result explanation lists other matching rules checked later |
| T48 | Standalone app install | Quit LinkRouter, run `scripts/install_release_app.sh`, then launch `/Applications/LinkRouter.app` | LinkRouter runs without Xcode and can be selected as the default browser |
| T49 | Compact rule details | Open Rules and expand a rule's `Details` disclosure | Main row stays compact, while check position, internal order value, profile, and warnings appear only in Details |
| T50 | Drag rule ordering | Drag one rule onto another rule in the Rules tab | The dragged rule is checked immediately before the target rule |
| T51 | Custom Default Apps extension | Add `plist` in `Default Apps`, choose a default app if candidates exist, then remove it | `.plist` appears under Custom, persists across refresh, and `Remove` only removes it from LinkRouter's tracked list |

### 2026-06-25: Rule Ordering

- Automated result:
  - Full test run passed with 74 passing tests and 1 opt-in browser launch
    test skipped.
- Rule ordering behavior:
  - Rules are displayed in the same effective order used by the rule engine.
  - Selecting a rule enables `Move Up` and `Move Down`.
  - Dragging one rule onto another places it before the target rule.
  - Boundary buttons are disabled in the UI and guarded in the editor layer.
  - Internal `priority` values are normalized after a move, preserving schema
    compatibility while avoiding user-facing number editing.

### 2026-06-25: Compact Rule Details

- UI behavior:
  - Rule rows show name, condition summary, destination, warning icon, and
    primary actions by default.
  - Detailed warning text, check position, internal order value, and selected
    browser profile are inside `Details`.
  - Healthy rules remain visually quiet.

## Source Detection Compatibility Matrix

Fill this with observed data during MVP testing:

| Source app | App version | Sender PID result | Frontmost result | Cache result | Recommended signal |
|---|---|---|---|---|---|
| Codex | Installed | Manual click required | Probe can resolve `com.openai.codex`; real click required | Manual click required | TBD |
| WeChat | Installed | Manual click required | TBD | Manual click required | TBD |
| Mail | macOS 26 | Manual click required | TBD | Manual click required | TBD |
| Telegram | TBD | TBD | TBD | TBD | TBD |
| Obsidian | Installed | Manual click required | TBD | Manual click required | TBD |
| Finder | macOS 26 | TBD | TBD | TBD | TBD |
| Terminal | macOS 26 | TBD | TBD | TBD | TBD |

## MVP Exit Criteria

- T01 through T12 pass, with documented source-detection limitations.
- T15, T16, and T19 pass.
- No crash or routing loop occurs during reliability tests.
- Codex and WeChat behavior is measured on the user's installed versions.
- Unknown-source behavior always reaches the configured fallback.
