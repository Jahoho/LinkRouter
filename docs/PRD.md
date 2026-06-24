# LinkRouter Product Requirements Document

## 1. Product Background

macOS normally uses one default browser for all web links. A user who works
across personal, communication, and development apps may want links from each
source to open in a different browser. LinkRouter becomes the system web-link
handler, evaluates a local rule, and forwards each URL to the selected browser.

## 2. User Pain Points

- One system default browser cannot represent different work contexts.
- Manually copying links between browsers interrupts the workflow.
- Existing routing tools may be too broad, cloud-dependent, or difficult to
  audit.
- The source app is not always exposed reliably by macOS, so routing must fail
  safely and transparently.

## 3. Core Goals

1. Route links by source app with minimal visible interruption.
2. Keep all rules and diagnostics on the local Mac.
3. Always have a predictable fallback when detection or launching fails.
4. Make uncertain source detection visible in diagnostics instead of hiding it.

## 4. User Scenarios

- A link opened from Codex launches Google Chrome.
- A link opened from WeChat launches Safari.
- A link opened from Telegram launches the configured browser.
- A link from an app without a rule launches the fallback browser.
- A source app cannot be identified, so LinkRouter uses the most recent
  credible app signal or the fallback browser.
- A configured browser is not installed, so LinkRouter reports the problem and
  opens the fallback browser when possible.

## 5. Core Features

- Register LinkRouter as an `http` and `https` handler.
- Show whether LinkRouter is currently the default web browser.
- Receive and validate incoming URLs.
- Detect the likely source app using multiple best-effort signals.
- Match enabled source-app rules in a deterministic order.
- Launch a specific installed browser by bundle identifier.
- Configure a fallback browser.
- Provide a menu bar item and settings window.
- Produce privacy-conscious local diagnostic logs.

## 6. MVP Scope

- macOS only, developed and tested initially on macOS 26.
- Menu bar app plus a basic settings window.
- Source-app rules only.
- Local persistence.
- Initial rules:
  - Codex -> Google Chrome
  - WeChat -> Safari
  - Default -> Safari
- Detection chain:
  - Apple Event sender metadata when credible
  - recently active app cache
  - unknown source and fallback browser
- Logs show timestamp, sanitized URL, detected source, detection method,
  matched rule, and selected browser.
- No Accessibility permission.

## 7. Non-MVP Features

- Domain, URL scheme, and combined app-plus-domain rules.
- Per-link browser chooser.
- Full browsing history.
- Login at startup.
- Import/export and iCloud synchronization.
- Rule conflict detection and drag-to-reorder match order UI.
- Automatic update mechanism.
- App Store distribution.

All deferred work is tracked in `docs/ROADMAP.md`.

## 8. User Flow

1. User launches LinkRouter.
2. LinkRouter explains that it must be the default browser to receive links.
3. User sets LinkRouter as the default browser in macOS.
4. User selects installed browsers and creates source-app rules.
5. Another app requests that macOS open an `http` or `https` URL.
6. LinkRouter receives and validates the URL.
7. Source detector returns an app identity, method, and confidence level.
8. Rule engine selects the first enabled matching rule.
9. If no rule matches, the configured fallback browser is selected.
10. Browser launcher opens the URL and records a sanitized diagnostic event.

## 9. Rule Logic

MVP rules match normalized bundle identifiers whenever possible. Display names
are labels only.

Proposed extensible model:

```json
{
  "schemaVersion": 1,
  "defaultBrowserBundleIdentifier": "com.apple.Safari",
  "rules": [
    {
      "id": "codex-to-chrome",
      "enabled": true,
      "priority": 100,
      "sourceAppBundleIdentifier": "TO_BE_CONFIRMED",
      "sourceAppName": "Codex",
      "hostPattern": null,
      "urlScheme": null,
      "browserBundleIdentifier": "com.google.Chrome",
      "action": "open",
      "openInBackground": false
    }
  ]
}
```

`priority` is the stored configuration field. The user-facing label should be
`Match order` / `匹配顺序`: higher numbers are checked first when more than one
rule can match.

MVP evaluation:

1. Reject unsupported or malformed URLs.
2. Sort enabled rules by descending match order, then stable creation order.
3. Match the detected source bundle identifier.
4. Use the first match.
5. If no match exists, use the fallback browser.
6. If the chosen browser is missing or is LinkRouter itself, attempt the
   fallback browser without re-entering the rule engine.
7. If fallback is also unavailable, show an actionable error and do not loop.

Future conditions may add host, URL scheme, combined conditions, an `ask`
action, and background-opening behavior without replacing the stored model.

## 10. Exceptional Scenarios

- **Unknown source:** use recent credible app signal, otherwise fallback.
- **Ambiguous helper process:** map known helpers to their owning app when the
  mapping is explicit; otherwise lower confidence and fall back.
- **Invalid URL:** refuse to launch and record a sanitized error.
- **Unsupported scheme:** MVP accepts only `http` and `https`.
- **Browser missing:** try fallback and show a settings warning.
- **Fallback missing:** show an error with a link to settings.
- **Routing loop:** reject LinkRouter as a destination browser.
- **Multiple URLs arrive quickly:** process each request independently and
  preserve arrival order.
- **Configuration unreadable:** use an in-memory safe default and preserve the
  damaged file for diagnosis.
- **LinkRouter is not default:** show setup status; do not claim routing is
  active.

## 11. Permission Requirements

MVP should not request Accessibility, Screen Recording, or Input Monitoring.
Normal URL receipt, `NSWorkspace` app lookup, browser launching, and workspace
activation notifications do not justify those permissions.

If App Sandbox is enabled later, the final entitlement set must be tested
against URL receipt, local settings storage, and browser launching. No network
entitlement is needed merely to forward a URL to another browser.

## 12. Technical Risks

- macOS does not provide a guaranteed high-level "original source app" field to
  a URL handler.
- Apple Event sender information may identify Launch Services or a helper
  process rather than the user-facing app.
- The frontmost app can change before the URL is handled.
- SwiftUI `onOpenURL` exposes the URL but not enough sender metadata for the
  strongest detection attempt.
- Browser bundle identifiers and source-app helper structures must be verified
  on the user's installed apps.
- Default-browser changes are user-controlled and behavior may vary by macOS
  release.
- App Store sandbox and review constraints may make a notarized direct
  distribution more practical for a productized version.

## 13. Acceptance Criteria

- LinkRouter appears as an eligible handler for `http` and `https`.
- After the user selects it as default, a link request reaches LinkRouter.
- The received URL is visible in debug output with sensitive parts removed.
- A credible Codex source signal routes to Google Chrome.
- A credible WeChat source signal routes to Safari.
- An unmatched or unknown source routes to Safari.
- Logs state the source identity, detection method, confidence, matched rule,
  and final browser.
- Missing browsers and invalid URLs do not crash or create routing loops.
- The app remains usable from the menu bar and can open its settings window.
