# Product

## Register

product

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

## Accessibility & Inclusion

Use standard macOS controls, system fonts, clear labels, keyboard-reachable
buttons, and semantic warning/error colors paired with text. Avoid workflows
that rely on color alone. Motion should be minimal and should communicate state
rather than decorate the app.
