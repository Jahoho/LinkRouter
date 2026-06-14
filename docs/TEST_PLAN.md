# LinkRouter MVP Test Plan

## Test Environment Record

Record these before each test cycle:

- macOS version
- LinkRouter build and commit
- installed browser versions and bundle identifiers
- source app versions and bundle identifiers
- whether LinkRouter is the current default browser
- permissions granted to LinkRouter

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
| T11 | Not default browser | Select another default browser and launch LinkRouter | Settings clearly show inactive default status; direct test events may work, but LinkRouter does not claim system-wide routing |
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
| Codex | TBD | TBD | TBD | TBD | TBD |
| WeChat | TBD | TBD | TBD | TBD | TBD |
| Telegram | TBD | TBD | TBD | TBD | TBD |
| Obsidian | TBD | TBD | TBD | TBD | TBD |
| Finder | macOS 26 | TBD | TBD | TBD | TBD |
| Terminal | macOS 26 | TBD | TBD | TBD | TBD |

## MVP Exit Criteria

- T01 through T12 pass, with documented source-detection limitations.
- T15, T16, and T19 pass.
- No crash or routing loop occurs during reliability tests.
- Codex and WeChat behavior is measured on the user's installed versions.
- Unknown-source behavior always reaches the configured fallback.

