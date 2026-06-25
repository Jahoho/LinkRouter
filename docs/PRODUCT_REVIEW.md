# LinkRouter Product Review

Date: 2026-06-25

## Verdict

LinkRouter is suitable for personal daily use as a lightweight local macOS
utility. The product should move into the personal release flow rather than
adding more features immediately.

No current P0 or P1 product blocker is visible for personal release.

External tester distribution is not ready until Developer ID signing and
notarization are completed.

## What Works Well

- The main workflow is clear: receive link, detect source, match rule, open
  browser, explain result.
- Rule creation no longer requires users to manually discover bundle
  identifiers.
- Domain and app-plus-domain rules reuse the existing rule model instead of
  adding a parallel system.
- Setup health, onboarding, and routing explanations reduce the support burden.
- Privacy defaults are appropriate: diagnostics use sanitized URLs by default.
- The app remains small enough for manual direct distribution:
  - installed app: about `5.3M`
  - release zip: about `3.3M`
- Configuration import/export is local, readable, and testable.
- The app now has a recognizable native AppIcon instead of the blank default
  icon.
- The release flow now has a one-command personal install script and a release
  checklist.

## Hardening Completed In This Review

- First-run setup guide added and persisted through `UserDefaults`.
- Manual release zip flow added and verified.
- Personal `/Applications` install flow added and verified.
- Native AppIcon added and verified in the built app bundle.
- Configuration validation tightened:
  - Rejects LinkRouter as fallback.
  - Rejects malformed rule source identifiers.
  - Rejects malformed domain patterns.
  - Rejects unsupported URL schemes.
  - Preserves invalid saved files and runs safe defaults in memory.

## Remaining Risks

| Risk | Severity | Notes |
|---|---:|---|
| Source app detection is best-effort | High | macOS does not guarantee original source app identity. Continue filling the compatibility matrix with real clicks. |
| External distribution not notarized yet | Medium | Personal Team signing works locally; Developer ID notarization still needs a real account/test cycle. |
| Rule editor density | Low | Recent compaction and selected/drag ordering reduced visible controls. Future features should stay folded or contextual. |
| Installed app scan is shallow | Low | It covers the common app folders but does not recursively scan every nested app bundle. |
| No automatic updates | Low | Manual zip is appropriate until multiple external testers exist. |

## Suggested Next High-Value Features

1. **Source compatibility matrix completion**
   - Test real clicks from Codex, WeChat, Telegram, Obsidian, Finder, Terminal,
     Mail, and browsers.
   - This is the highest-value next step because routing quality depends on
     source identity quality.

2. **Developer ID notarization trial**
   - Build a real signed/notarized zip.
   - Test on a clean macOS user account or a second Mac.

3. **Optional full URL debug mode**
   - Disabled by default.
   - Time-limited and clearly labeled.
   - Useful only for diagnosing tricky domain/path workflows.

## Features To Avoid For Now

- Sparkle updater before there are external testers.
- iCloud sync before rule conflict and migration policies are mature.
- Accessibility-based detection unless real testing proves current detection is
  insufficient.
- Persistent full URL history by default.
- Complex browser tab automation through AppleScript.

## Product Manager Recommendation

Do not add more product features before the personal release. The next best
move is release validation:

1. Run the personal release checklist in `docs/RELEASE_CHECKLIST.md`.
2. Use the generated zip as the local personal release artifact.
3. Fill the source detection matrix through real daily use.
4. Produce a Developer ID notarized build only when external testing becomes
   real.
