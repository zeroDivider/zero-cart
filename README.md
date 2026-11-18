# ZeroCart

> **Status: pre-alpha.** Phases 0–5 of the implementation plan are in place (through APP-018). Home store cards, Settings/About, backup, Serbian and release polish are still ahead.

ZeroCart is an offline-first shopping-list app for Android and iOS, built with Flutter. The goal is to get your cart to zero: capture items the moment you think of them, sort them into per-store lists later, and shop with a simple checklist.

## Why

Items get forgotten because adding them is inconvenient: you remember dishwasher tablets while washing dishes, not while navigating menus. ZeroCart makes capture instant and organisation optional.

## Principles

Capture first, organise later. Minimal friction. Local-first and offline. Multiple named lists per store. Simple shopping interactions. Playful, accessible design. No registration, accounts or backend. Maintainable, not over-engineered. Your data stays on your device and can be exported as a JSON backup.

## Implemented

Foundation and shared shell (APP-001–005, APP-014a):

- Flutter app for Android and iOS (package `zero_cart`, bundle id `com.zero.cart`), three-tab navigation (Home / Inbox / Stores), theme tokens, gen-l10n (English), CI and `tool/check.sh`.
- Bundled fonts: Roboto (UI) and DynaPuff (wordmark), with licences registered for the in-app licences page.
- Shared UI primitives (`AppMessenger`, `runWrite`, `FormSheetScaffold`, `AsyncBody`, swipe-to-remove, Quick-add FAB) per ADR-0007.

Data and core features (APP-006–018):

- Drift SQLite schema v1 (`lib/data/`): six tables with foreign keys, CHECKs and indexes; file DB `zero_cart.sqlite` and in-memory constructor for tests.
- Repositories for Inbox, Stores, Lists/items, Wishlists; typed failures and Undo for hard deletes.
- Inbox quick-add, edit, remove with Undo, and assign into a store/list (creates store/list when needed).
- Stores tab: create/edit (colour, address, note), archive and restore; store details with active lists.
- Per-store wishlist: add/edit/remove with Undo, copy items into a list.
- List screen: add/edit items, check off, drag reorder, swipe remove with Undo, collapsible purchased section.
- Finish shopping with optional carry-forward of leftovers; Past trips on the store; Archive for manually archived stores and lists (restore gated when the store is archived).
- Share an active list as plain text through the system share sheet.

Still placeholder in the UI: Home body, Settings and About. Verified layout facts live in `docs/codebase-map.md`.

## Planned for v1

- Home store-card board (counts, progress, Inbox pill)
- Settings (theme persistence) and About
- Versioned JSON backup export and replace-all restore
- Serbian (Latin) localisation
- Accessibility pass, goldens/integration tests, release readiness

## Planned for v2

Landscape and tablet layouts; shared lists through a backend (accounts, sync, notifications).

## Tech stack

Flutter and Dart, Material 3, Riverpod, Drift (SQLite), go_router, gen-l10n, share_plus. Rationale in `docs/architecture.md` and `docs/adr/`.

## Documentation

| Topic | File |
|---|---|
| Product requirements and flows | `docs/product-requirements.md`, `docs/user-flows.md` |
| Decisions and assumptions | `docs/decisions-and-assumptions.md` |
| Architecture and ADRs | `docs/architecture.md`, `docs/adr/` |
| Data model and backup format | `docs/data-model.md`, `docs/backup-format.md` |
| Design system and prototype | `docs/design-system.md`, `design/shopping-app-prototype.html` |
| Implementation plan | `docs/implementation-plan.md` |
| Codebase map (reuse facts) | `docs/codebase-map.md` |
| Deviations | `docs/deviations.md` |
| Testing | `docs/testing-strategy.md` |
| AI-assisted workflow | `docs/ai-development-workflow.md`, `AGENTS.md` |

Open `design/shopping-app-prototype.html` in a browser to see the intended design (sample data only).

## Getting started

Verified with **Flutter 3.47.9** (stable channel, Dart 3.13.7). The Flutter version is pinned in `pubspec.yaml` (`environment.flutter`) and CI reads that same value.

1. Install the Flutter stable SDK matching the pin above, Android Studio or the Android SDK, and Xcode (macOS) for iOS.
2. From the repo root: `flutter pub get`
3. Quality gate: `bash tool/check.sh` (pub get, gen-l10n, Drift `build_runner`, format, analyze, tests). GitHub Actions runs the same script on every pull request and on pushes to `main`.
4. Coverage (optional, not a gate): `bash tool/coverage.sh` writes `coverage/lcov.info` and a filtered `coverage/lcov.filtered.info`. CI uploads the filtered report to Codecov when `CODECOV_TOKEN` is set.
5. Run: `flutter run` (Android emulator/device now; iOS requires macOS)

Drift generates `lib/data/database.g.dart` (not committed). After changing tables, run `dart run build_runner build`, then dump the schema with `dart run drift_dev schema dump lib/data/database.dart drift_schemas/drift_schema_v1.json` when the version changes, and regenerate migration helpers with `dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/`.

## AI-assisted development

This project is planned with Claude and implemented with Cursor Agent, under human direction and review. The process, rules and guardrails are public in `AGENTS.md`, `.cursor/` and `docs/ai-development-workflow.md`. Commits carry an `Assisted-by` trailer. The maintainer reviews and is responsible for everything merged.

## Licence and credits

Source code: MIT, see `LICENSE`. Fonts are bundled under their own licences (texts in `assets/fonts/`): **DynaPuff** (SIL Open Font License 1.1) for the wordmark and **Roboto** (Apache License 2.0) for the interface. Both are registered with Flutter's `LicenseRegistry` and appear on the in-app licences page. Dependency licences are shown there as well.

## Contributing

See `CONTRIBUTING.md`.
