# LinkRouter Release Notes

## 0.1.0 Personal Release Candidate

Date: 2026-06-26

This is the first practical personal-use release candidate. It is intended for
running LinkRouter from `/Applications` on the developer's Mac.

## Highlights

- Routes web links by source app, domain, URL scheme, and combined conditions.
- Uses a configured fallback browser when no rule matches or source detection
  is uncertain.
- Forwards local HTML files opened from Finder to the fallback browser, so
  LinkRouter can remain the default browser without blocking HTML preview.
- Provides a native menu bar app and compact Settings window.
- Creates rules from recent detected apps and installed app picker results.
- Supports browser profile routing for detected Chromium profiles.
- Includes recent routing history with sanitized diagnostics.
- Includes setup health checks and first-run onboarding.
- Includes Default Apps management for common and custom file extensions.
- Includes launch-at-login, pause routing, and next-link browser override.
- Includes English / Chinese interface switching.
- Includes a native macOS-style AppIcon.

## Build Artifacts

Current local release artifact:

```text
releases/LinkRouter-0.1.0-1-20260626-011409.zip
```

Current measured sizes:

- Installed app: about `5.3M`
- Release zip: about `3.4M`

SHA-256:

```text
a3450783a113dda8a9968a9638b17110bd79f7d817ff53fa40355fc06d1d745e
```

## Known Limits

- Source-app detection is best-effort because macOS does not always expose the
  original app that requested a URL open.
- Personal Apple Development signing is suitable for local use, but not for a
  polished external release.
- External testers should receive only a Developer ID signed and notarized
  build.
- `spctl` may reject the personal build because it is not notarized.
- No automatic updater is included; manual zip releases are intentional for
  this lightweight stage.

## Release Gate

Ready for personal daily use if:

- `/Applications/LinkRouter.app` launches.
- Code signing verification passes.
- LinkRouter can be selected as the default browser.
- Setup Health does not show a blocking error.
- At least one real app link routes correctly.

Not ready for external tester distribution until:

- Developer ID signing is configured.
- Notarization succeeds.
- Gatekeeper assessment passes on a clean user account or second Mac.
