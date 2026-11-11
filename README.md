# ZeroCart

> **Status: pre-alpha. Project skeleton exists (APP-001); features are not implemented yet.**

ZeroCart is an offline-first shopping-list app for Android and iOS, built with Flutter. The goal is to get your cart to zero: capture items the moment you think of them, sort them into per-store lists later, and shop with a simple checklist.

## Why

Items get forgotten because adding them is inconvenient: you remember dishwasher tablets while washing dishes, not while navigating menus. ZeroCart makes capture instant and organisation optional.

## Principles

Capture first, organise later. Minimal friction. Local-first and offline. Multiple named lists per store. Simple shopping interactions. Playful, accessible design. No registration, accounts or backend. Maintainable, not over-engineered. Your data stays on your device and can be exported as a JSON backup.

## Implemented

- Empty Flutter app shell for Android and iOS (package `zero_cart`, bundle id `com.zero.cart`). See the roadmap in `docs/implementation-plan.md`.
- Bundled fonts: Roboto (UI) and DynaPuff (wordmark), with licences registered for the in-app licences page.
- Drift SQLite schema v1 (`lib/data/`): six tables with foreign keys, CHECKs and indexes; file DB `zero_cart.sqlite` and in-memory constructor for tests.

## Planned for v1

- Inbox with instant quick-add, later assigned to a store and a named list
- Stores (colour, address, note) with several named lists each and one wishlist per store
- Items with title and optional description, check off, drag to reorder, swipe to remove with Undo, collapsible purchased section
- Finish shopping with carry-forward of leftovers; archived stores and lists with restore
- Plain-text sharing of a list through the system share sheet
- Home screen with a board of store cards
- Light, dark and system themes; English and Serbian (Latin)
- Versioned JSON backup and replace-all restore

## Planned for v2

Landscape and tablet layouts; shared lists through a backend (accounts, sync, notifications).

## Tech stack

Flutter and Dart, Material 3, Riverpod, Drift (SQLite), go_router, gen-l10n. Rationale in `docs/architecture.md` and `docs/adr/`.

## Documentation

| Topic | File |
|---|---|
| Product requirements and flows | `docs/product-requirements.md`, `docs/user-flows.md` |
| Decisions and assumptions | `docs/decisions-and-assumptions.md` |
| Architecture and ADRs | `docs/architecture.md`, `docs/adr/` |
| Data model and backup format | `docs/data-model.md`, `docs/backup-format.md` |
| Design system and prototype | `docs/design-system.md`, `design/shopping-app-prototype.html` |
| Implementation plan | `docs/implementation-plan.md` |
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
