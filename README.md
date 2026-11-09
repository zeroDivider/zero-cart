# ZeroCart

> **Status: pre-alpha. Planning is complete; implementation has not started.** Nothing described under 'Planned' exists yet.

ZeroCart is an offline-first shopping-list app for Android and iOS, built with Flutter. The goal is to get your cart to zero: capture items the moment you think of them, sort them into per-store lists later, and shop with a simple checklist.

## Why

Items get forgotten because adding them is inconvenient: you remember dishwasher tablets while washing dishes, not while navigating menus. ZeroCart makes capture instant and organisation optional.

## Principles

Capture first, organise later. Minimal friction. Local-first and offline. Multiple named lists per store. Simple shopping interactions. Playful, accessible design. No registration, accounts or backend. Maintainable, not over-engineered. Your data stays on your device and can be exported as a JSON backup.

## Implemented

Nothing yet. See the roadmap in `docs/implementation-plan.md`.

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

Setup commands will be verified and finalised when the project is created (task APP-001). Expected: install the Flutter stable SDK (record the version here), Android Studio or the Android SDK, and Xcode for iOS; then `flutter pub get`, `dart run build_runner build --delete-conflicting-outputs`, `tool/check.sh`, `flutter run`.

## AI-assisted development

This project is planned with Claude and implemented with Cursor Agent, under human direction and review. The process, rules and guardrails are public in `AGENTS.md`, `.cursor/` and `docs/ai-development-workflow.md`. Commits carry an `Assisted-by` trailer. The maintainer reviews and is responsible for everything merged.

## Licence and credits

Source code: MIT, see `LICENSE`. Fonts are bundled under their own licences: **DynaPuff** (SIL Open Font License) for the wordmark and **Roboto** for the interface (licence to be confirmed from the downloaded files and recorded here and in the in-app licences page). Dependency licences are shown by the in-app licences page.

## Contributing

See `CONTRIBUTING.md`.
