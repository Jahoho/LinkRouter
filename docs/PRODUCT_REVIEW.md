# LinkRouter Product Review

Date: 2026-06-24

## Verdict

LinkRouter is now past MVP and is suitable for continued personal daily use
and limited tester trials after proper signing/notarization. The product still
depends on best-effort macOS source detection, but the current UX explains that
uncertainty instead of hiding it.

No current P0 product blocker is visible in the codebase after the P4 pass.

## What Works Well

- The main workflow is clear: receive link, detect source, match rule, open
  browser, explain result.
- Rule creation no longer requires users to manually discover bundle
  identifiers.
- Domain and app-plus-domain rules reuse the existing rule model instead of
  adding a parallel system.
- Setup health, onboarding, and routing explanations reduce the support burden.
- Privacy defaults are appropriate: diagnostics use sanitized URLs by default.
- The app remains small: the verified release zip is about `424K`.
- Configuration import/export is local, readable, and testable.

## Hardening Completed In This Review

- First-run setup guide added and persisted through `UserDefaults`.
- Manual release zip flow added and verified.
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
| Rule editor is becoming dense | Medium | It is still acceptable, but future features should avoid adding more inline controls. |
| Installed app scan is shallow | Low | It covers the common app folders but does not recursively scan every nested app bundle. |
| No automatic updates | Low | Manual zip is appropriate until multiple external testers exist. |

## Suggested Next High-Value Features

1. **Source compatibility matrix completion**
   - Test real clicks from Codex, WeChat, Telegram, Obsidian, Finder, Terminal,
     Mail, and browsers.
   - This is the highest-value next step because routing quality depends on
     source identity quality.

2. **Compact rule detail drawer**
   - Keep the main rule row simple.
   - Put advanced fields, explanations, and warnings behind a disclosure.
   - This prevents the settings window from becoming crowded.

3. **Developer ID notarization trial**
   - Build a real signed/notarized zip.
   - Test on a clean macOS user account or a second Mac.

4. **Optional full URL debug mode**
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

Do not add more routing power immediately. The next best move is a real-world
compatibility and distribution pass:

1. Run the manual checklist from `docs/TEST_PLAN.md`.
2. Fill the source detection matrix.
3. Produce a Developer ID notarized build when external testing becomes real.
4. Then polish rule ordering and rule editor density.
