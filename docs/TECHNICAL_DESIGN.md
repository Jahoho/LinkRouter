# LinkRouter Technical Design

## 1. Recommended Direction

Build the MVP as a native Swift application using SwiftUI for settings and
AppKit for lifecycle, Apple Event inspection, and workspace integration.

Use a menu bar presence with a settings window. Avoid Accessibility and Event
Tap in the first implementation. Source detection must return both a result and
its confidence because no single macOS signal is guaranteed.

## 2. Route A: Simple MVP

### Scope

- One app target.
- Register `http` and `https`.
- Receive URL Apple Events.
- Hard-coded seed rules loaded into local storage on first run.
- Match by source bundle identifier.
- Open a selected browser using `NSWorkspace`.
- Basic settings/status view and structured console logging.

### Advantages

- Small implementation surface.
- Fastest route to testing the critical source-detection assumption.
- No sensitive Accessibility permission.
- Easy to discard or revise detection code after real-world tests.

### Disadvantages

- Detection remains best-effort.
- Minimal rule editing and diagnostics.
- No automatic launch, import/export, or polished onboarding.

## 3. Route B: Productized Application

### Scope

- Full SwiftUI rule editor and installed-browser picker.
- Menu bar status and pause controls.
- Persistent structured logs with retention controls.
- Login item using `SMAppService`.
- Permission and default-browser onboarding.
- Import/export, conflict checking, and schema migration.
- Optional advanced source detector behind explicit permission.
- Signing, notarization, and update delivery.

### Advantages

- Better transparency and self-service configuration.
- Easier to support multiple testers.
- Better recovery from configuration and permission problems.

### Disadvantages

- More UI, migration, privacy, signing, and test work before the core
  detection strategy has been proven.
- Advanced monitoring can require sensitive permissions without guaranteeing
  perfect accuracy.

## 4. Recommendation

Start with Route A, but use the module boundaries and versioned rule model
described below. First collect a source-detection compatibility matrix for
Codex, WeChat, Telegram, Obsidian, Finder, and Terminal. Move to Route B only
after those measurements establish which signals are dependable.

## 5. Receiving Web URLs

### Registration

The app bundle must declare URL types for `http` and `https` in `Info.plist`.
The exact Xcode representation will be validated when the target exists:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Viewer</string>
    <key>CFBundleURLName</key>
    <string>Web URL</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>http</string>
      <string>https</string>
    </array>
  </dict>
</array>
```

Launch Services discovers handlers from installed app bundles. LinkRouter
should guide the user to choose it as the default browser and verify the
current handler with Launch Services. It must not silently take over the
default without clear user action.

### URL Delivery

SwiftUI `onOpenURL` is suitable for receiving a URL but does not expose useful
sender metadata. The preferred MVP path is an AppKit lifecycle bridge using
`NSAppleEventManager` for the `kInternetEventClass` / `kAEGetURL` event, while
also inspecting the current Apple Event before that context disappears.

The handler should:

1. Read the URL string from the direct object.
2. Inspect sender-related Apple Event attributes.
3. Validate and normalize the URL.
4. Capture detection evidence immediately.
5. Hand an immutable request to the routing pipeline.

## 6. Source-App Detection

There is no fully reliable, documented high-level API that says "this URL was
clicked in app X." Detection is an evidence-ranking problem.

| Signal | Reliability | Permission | Main weakness | MVP |
|---|---|---|---|---|
| Apple Event sender PID | Medium when present | None expected | May be Launch Services or a helper | Yes, primary |
| `NSWorkspace.frontmostApplication` | Low to medium | None | Focus may change before handling | Yes, supporting |
| Workspace activation cache | Medium | None | Recency does not prove causation | Yes, fallback |
| AppleScript frontmost process | Low to medium | Automation may be requested | Same timing problem; extra permission friction | No |
| Accessibility focused app/window | Medium | Accessibility | Sensitive permission; still timing-dependent | Later experiment |
| Event Tap click/key monitoring | Low for causation | Input Monitoring or Accessibility | Cannot reliably connect an input event to a later URL | No |
| Unified logs/process inference | Low | Varies | Fragile, private implementation details | No |
| User chooser | High user correctness | None | Interrupts every uncertain link | Later optional fallback |

### Detection Pipeline

1. Extract sender PID from the incoming Apple Event when available.
2. Resolve PID to `NSRunningApplication`.
3. Normalize helper processes only through tested mappings.
4. Reject LinkRouter itself and explicit system proxy processes as source
   candidates. Browsers remain valid sources until browser-to-browser routing
   behavior is designed and tested.
5. If the sender is unavailable, inspect `NSWorkspace.frontmostApplication`
   and report it with medium confidence.
6. Compare with a short-lived cache populated from
   `NSWorkspace.didActivateApplicationNotification`.
7. Return:
   - bundle identifier
   - display name
   - detection method
   - confidence (`high`, `medium`, `low`, `unknown`)
   - optional diagnostic reason
8. If no credible identity remains, return `unknown`; the rule engine uses the
   fallback browser.

The cache window must be measured rather than guessed. Initial experiments
should capture timestamps without storing full URLs.

Current implementation uses a five-second cache window. This value remains a
test assumption and must be revisited after the compatibility matrix contains
real clicks from the target source apps.

## 7. Browser Launching

Preferred implementation:

1. Resolve the destination with
   `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`.
2. Open using the modern `NSWorkspace` API that accepts application URL,
   URL list, and `NSWorkspace.OpenConfiguration`.
3. Observe completion and report launch errors.

Why this method:

- Bundle identifiers are stable across localized app names.
- No shell process or quoting risk.
- No AppleScript Automation permission.
- Completion gives an explicit error path.

Alternatives:

- `NSWorkspace.shared.open(url)` uses the system default and would loop back to
  LinkRouter, so it is unsuitable for the selected destination.
- `open -a "Google Chrome" URL` is useful for manual debugging but relies on
  display names and a subprocess.
- AppleScript adds Automation permission prompts and browser-specific syntax;
  reserve it for future features that require browser tab control.

Initial destination identifiers:

| Browser | Bundle identifier |
|---|---|
| Safari | `com.apple.Safari` |
| Google Chrome | `com.google.Chrome` |
| Arc | `company.thebrowser.Browser` |

All identifiers must also be checked against installed app bundles at runtime.

Current implementation asks Launch Services for every installed application
capable of opening an HTTPS probe URL. Results are deduplicated by bundle
identifier, LinkRouter itself is removed, and common browsers receive a stable
display order. Launching resolves the application URL again from its bundle
identifier so a stale stored path is not trusted.

The settings window exposes an explicit test button for each discovered
browser. Browser tests that create external UI are opt-in so the normal unit
test suite remains non-disruptive.

## 8. Configuration and Storage

Use `Codable` models with an explicit `schemaVersion`. For the MVP, persist the
small configuration as JSON in the app's Application Support directory.
`UserDefaults` may hold UI preferences, but rule data should remain in a
readable, migratable file.

Writes should be atomic. Decode failure must not overwrite the damaged file.
Seed defaults are created only when no configuration exists.

## 9. Logging and Privacy

Use Apple's unified logging through `Logger` for live diagnostics. A later
local history store can keep a bounded number of sanitized events.

Default URL logging:

- include timestamp, scheme, and host
- exclude path, query, fragment, credentials, and full URL
- include source bundle identifier, detection method, confidence, rule ID,
  destination browser, and error category

Debug-only full URL logging must require an explicit opt-in and should never be
enabled by default.

## 10. Menu Bar and Settings

Use SwiftUI's menu bar scene where it supports the required lifecycle cleanly,
with an AppKit application delegate bridge for URL Apple Events. The menu
should expose:

- routing status
- current default-browser status
- open settings
- recent sanitized result
- quit

The settings window initially contains default-browser status, fallback
browser, source rules, and diagnostics. UI state must not own routing state;
shared services should be injected into both scenes.

## 11. Sandbox and Distribution

### Self-use MVP

Use normal local development signing. Keep the entitlement set minimal. Do not
enable Accessibility or Automation permissions.

### External Testers

Prefer Developer ID signing plus Apple notarization. This gives a normal
Gatekeeper experience while retaining flexibility for system integration.

### App Store

Potentially possible, but not the initial recommendation. Sandbox behavior,
default-browser positioning, source inference, and any future Accessibility or
event-monitoring feature need dedicated review. App Store constraints should
not shape the MVP before source detection is proven.

## 12. Proposed Project Structure

```text
LinkRouter/
├── LinkRouterApp/
│   ├── App/
│   │   ├── LinkRouterApp.swift
│   │   └── AppDelegate.swift
│   ├── URLHandling/
│   │   ├── URLRequestReceiver.swift
│   │   └── IncomingURLRequest.swift
│   ├── SourceDetection/
│   │   ├── AppSourceDetector.swift
│   │   ├── AppleEventSourceDetector.swift
│   │   └── RecentApplicationTracker.swift
│   ├── Rules/
│   │   ├── RoutingRule.swift
│   │   ├── RoutingConfiguration.swift
│   │   └── RuleEngine.swift
│   ├── Browsers/
│   │   ├── Browser.swift
│   │   ├── BrowserDiscovery.swift
│   │   └── BrowserLauncher.swift
│   ├── Storage/
│   │   └── ConfigurationStore.swift
│   ├── Logging/
│   │   └── RoutingLogger.swift
│   ├── UI/
│   │   ├── MenuBarView.swift
│   │   └── SettingsView.swift
│   └── Resources/
│       └── Assets.xcassets
├── LinkRouterTests/
├── docs/
└── README.md
```

Module responsibilities:

- **App:** lifecycle and dependency assembly.
- **URLHandling:** capture and validate incoming requests.
- **SourceDetection:** collect evidence and report confidence.
- **Rules:** pure deterministic matching, independent from AppKit.
- **Browsers:** discover and launch apps by bundle identifier.
- **Storage:** versioned, atomic configuration persistence.
- **Logging:** sanitize and record routing decisions.
- **UI:** display and edit state without implementing routing logic.

## 13. Implementation Stages

1. Install/select full Xcode and create the macOS app target.
2. Prove URL registration and receipt with sanitized logging.
3. Build a source-detection probe and test the target source apps.
4. Implement browser discovery and explicit launch.
5. Add rule engine and fallback behavior with unit tests.
6. Add configuration persistence.
7. Add menu bar and basic settings UI.
8. Run the full MVP checklist and update the compatibility matrix.

## 14. Reference Documentation

- Apple: [Defining a custom URL scheme for your app](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app)
- Apple: [`NSAppleEventManager`](https://developer.apple.com/documentation/foundation/nsappleeventmanager)
- Apple: [`NSWorkspace`](https://developer.apple.com/documentation/appkit/nsworkspace)
- Apple: [Responding to the launch of your app](https://developer.apple.com/documentation/appkit/responding-to-the-launch-of-your-app)
- Apple: [`onOpenURL`](https://developer.apple.com/documentation/swiftui/view/onopenurl%28perform%3A%29)
