# LinkRouter Product Principles

## Users

LinkRouter is primarily for one macOS power user who works across development,
communication, notes, and email apps. The user wants web links to open in the
right browser without copying URLs manually or thinking about browser context.
Future testers may be technical friends or collaborators, but the product
should remain small, local, and understandable.

## Product Purpose

LinkRouter is a local macOS menu bar utility that becomes the default web-link
handler, detects the likely source app, evaluates local routing rules, and
forwards each link to the selected browser. Success means the app quietly does
the right thing, explains surprising decisions, and fails safely to a fallback
browser when macOS source detection is uncertain.

## Market Positioning

Mature tools such as Velja, Choosy, Browserosaurus, SwiftDefaultApps, and
`duti` validate that users want more control over browser and default-app
behavior. LinkRouter should not try to become a heavy all-purpose launcher.
Its differentiated position is:

1. Source-aware link routing for a small set of personally important apps.
2. Local-first rules and diagnostics with no cloud account or telemetry.
3. Explicit confidence reporting for macOS source detection.
4. A lightweight native menu bar experience that stays quiet until needed.

The product should win by being understandable and trustworthy, not by
matching every advanced feature in existing browser managers.

## Brand Personality

Calm, precise, lightweight. The product should feel like a reliable system
utility rather than a flashy browser manager. It can be friendly in copy, but
the interface should stay compact and task-focused.

## Anti-references

Avoid heavy browser-suite aesthetics, noisy dashboards, persistent full-history
surveillance, decorative motion, and interfaces that require users to know
technical identifiers before they can finish a normal task.

## Design Principles

1. Hide technical complexity until it is useful for diagnosis.
2. Prefer compact progressive disclosure over always-visible management UI.
3. Preserve privacy by default; sanitized hosts are enough for normal history.
4. Make every automatic routing decision explainable.
5. Extend the existing rule model instead of adding special-case flows.
6. Prefer trust-building diagnostics over broad feature accumulation.
7. Treat file default-app management as an adjacent module, not the core
   identity of the product.

## Accessibility & Inclusion

Use standard macOS controls, system fonts, clear labels, keyboard-reachable
buttons, and semantic warning/error colors paired with text. Avoid workflows
that rely on color alone. Motion should be minimal and should communicate state
rather than decorate the app.
