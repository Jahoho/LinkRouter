# LinkRouter Repository Structure

This document defines what belongs in the public repository, what stays local,
and where generated files should go.

## Public Repository

These files are safe to commit and share:

| Path | Audience | Purpose |
|---|---|---|
| `README.md` | Users and developers | Project overview, features, build/test basics |
| `docs/USER_GUIDE.md` | Users and testers | Setup, daily use, and manual verification |
| `docs/PRODUCT.md` | Users and developers | Product principles, positioning, and design rules |
| `docs/PRD.md` | Developers and reviewers | Product requirements |
| `docs/TECHNICAL_DESIGN.md` | Developers | Architecture and macOS implementation notes |
| `docs/ROADMAP.md` | Developers and testers | Public backlog and status |
| `docs/TEST_PLAN.md` | Developers and testers | Manual and automated verification checklist |
| `docs/DISTRIBUTION.md` | Maintainers | Release, signing, notarization, and install notes |
| `docs/RELEASE_CHECKLIST.md` | Maintainers | Personal install, local zip, and external tester release gates |
| `docs/RELEASE_NOTES.md` | Users and maintainers | Current release highlights, known limits, and release gate |
| `docs/PRODUCT_REVIEW.md` | Developers and product reviewers | Product/engineering audit notes |
| `docs/REPOSITORY_STRUCTURE.md` | Maintainers | Public/private file boundaries |
| `LinkRouter/` | Developers | App source code |
| `LinkRouterTests/` | Developers | Automated tests |
| `scripts/` | Maintainers | Reusable local release helpers |
| `LinkRouter.xcodeproj/xcshareddata/` | Developers | Shared Xcode scheme |

## Local-Only Files

These files are intentionally not committed:

| Path | Why local-only |
|---|---|
| `local/DEVELOPMENT_LOG.md` | Personal development notes, rough product thinking, and private iteration history |
| `local/README.md` | Local-only guide for what can be stored in `local/` |
| `LinkRouter.local.json` | Machine-specific local configuration |
| `*.log` | Diagnostic logs |
| `.DS_Store` | macOS Finder metadata |

The `local/` directory is ignored by Git. It is the right place for notes that
help the owner develop the app but should not appear in a public GitHub repo.

## Generated Files

These should be reproducible and should not be committed:

| Path | Purpose |
|---|---|
| `build/` | Local command-line build output |
| `DerivedData/` | Xcode build cache if created inside the repo |
| `releases/` | Local zipped app builds produced by release scripts |
| `.build/`, `.swiftpm/` | Swift Package Manager caches if introduced later |
| `LinkRouter.xcodeproj/project.xcworkspace/` | User-specific Xcode workspace state |

## Signing Configuration

`LinkRouter.xcodeproj/project.pbxproj` is a tracked project file, but local
signing changes can appear inside it, such as:

- `DEVELOPMENT_TEAM`
- `CODE_SIGN_IDENTITY`

For a public repository, avoid committing a personal Team ID unless the project
intentionally standardizes on a shared signing setup. Personal signing changes
can stay as local uncommitted changes while developing.

## Naming Rules

- Public docs live in `docs/` and use descriptive names.
- Personal notes live in `local/`.
- Reproducible automation lives in `scripts/`.
- Build and release artifacts live in ignored directories.
- Keep the repository root small: `README.md`, `.gitignore`, project files,
  source folders, docs, tests, and scripts.
