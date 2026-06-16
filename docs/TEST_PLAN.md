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
  - Unknown or unmatched sources select fallback `com.apple.Safari`.
- Ordering result: higher priority wins; equal priority preserves
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
  - Open Settings and confirm the two seed rules are visible.
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

- Automated result: 37 tests passed and 1 opt-in browser integration test
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

## Core Checklist

| ID | Scenario | Steps | Expected result |
|---|---|---|---|
| T01 | Codex opens a link | Click an external web link in Codex | URL reaches LinkRouter; source evidence identifies Codex with stated confidence; Chrome opens; sanitized log records matched rule |
| T02 | WeChat opens a link | Click an external web link in WeChat | URL reaches LinkRouter; credible WeChat source matches; Safari opens; sanitized log records matched rule |
| T03 | Telegram opens a link | Configure a Telegram rule, then click a link | Configured browser opens; source method and confidence are logged |
| T04 | Obsidian opens a link | Click an external link in Obsidian | If no rule exists, fallback Safari opens; any inferred source is recorded honestly |
| T05 | Finder opens a link | Open a `.webloc` file in Finder | URL reaches LinkRouter; Finder is detected when evidence supports it, otherwise fallback is used |
| T06 | Terminal opens a link | Run `open https://example.com` | URL reaches LinkRouter; Terminal may be detected or marked unknown; fallback opens without looping |
| T07 | App without rule | Open a link from an unconfigured app | Fallback Safari opens and log states that no rule matched |
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

## Source Detection Compatibility Matrix

Fill this with observed data during MVP testing:

| Source app | App version | Sender PID result | Frontmost result | Cache result | Recommended signal |
|---|---|---|---|---|---|
| Codex | Installed | Manual click required | Probe can resolve `com.openai.codex`; real click required | Manual click required | TBD |
| WeChat | Installed | Manual click required | TBD | Manual click required | TBD |
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
