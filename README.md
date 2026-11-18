# ZeroCart

**Get your cart to zero.**

Capture groceries the moment you think of them. Sort them into per-store lists later. Shop with a simple checklist. Everything stays on your phone — no accounts, no cloud, no ads.

> **Pre-alpha** · Android & iOS · Flutter · Offline-first  
> Core shopping loop works today (through APP-018). Home board, Settings, backup and Serbian are next.

---

## Why it exists

You remember dishwasher tablets while washing dishes — not while hunting through menus. Adding an item should take a second; organising it can wait.

**Capture first, organise later.**

## What you can do today

- ⚡ **Quick-add Inbox** — dump items instantly from a FAB; edit or remove with Undo
- 🏪 **Stores** — coloured cards with address & note; archive / restore
- 📝 **Named lists per store** — several lists, one wishlist each
- ✅ **Shop a list** — check off, drag to reorder, swipe to remove + Undo, collapse purchased
- 🎯 **Assign from Inbox** — pick a store & list (or create them) and move items in
- ⭐ **Wishlist** — keep “maybe later” items, then copy into a real list
- 🏁 **Finish shopping** — archive the trip; optionally carry leftovers into a new list
- 🕘 **Past trips & Archive** — history on the store; manual archives with restore
- 📤 **Share a list** — plain text via the system share sheet

Still stubs in the UI: **Home** board, **Settings** / **About**. Data already lives in local SQLite and survives restarts.

Peek at the intended look: open [`design/shopping-app-prototype.html`](design/shopping-app-prototype.html) in a browser (sample data only).

## Coming soon (v1)

- 🏠 Home store-card board (counts, progress, Inbox pill)
- ⚙️ Settings — light / dark / system theme that sticks
- 💾 Versioned JSON backup — export & replace-all restore
- 🇷🇸 Serbian (Latin) localisation
- ♿️ Accessibility pass, goldens, release polish

**Later (v2):** tablet / landscape layouts; shared lists via a real backend.

## Principles

- Minimal friction — no registration, no backend in v1  
- Local-first — your data stays on the device  
- Playful & accessible — 48dp targets, scalable text, semantics  
- Maintainable — deliberate architecture, not over-engineered  

## Run it

Verified on **Flutter 3.47.9** (Dart 3.13.7) — pinned in `pubspec.yaml` and mirrored in CI.

```bash
flutter pub get
bash tool/check.sh          # format, analyze, tests (also runs on every PR)
flutter run                 # Android emulator/device; iOS needs macOS
```

Optional coverage: `bash tool/coverage.sh` → `coverage/lcov.filtered.info` (Codecov when `CODECOV_TOKEN` is set).

**Drift codegen** (after schema changes):

```bash
dart run build_runner build
dart run drift_dev schema dump lib/data/database.dart drift_schemas/drift_schema_v1.json
dart run drift_dev schema generate drift_schemas/ test/data/generated_migrations/
```

`lib/data/database.g.dart` is generated and not committed.

## Stack

Flutter · Material 3 · Riverpod · Drift (SQLite) · go_router · gen-l10n · share_plus  

Why these choices: [`docs/architecture.md`](docs/architecture.md) and [`docs/adr/`](docs/adr/).

## Docs map

- 🗺️ **What exists in code** — [`docs/codebase-map.md`](docs/codebase-map.md)
- 📋 **Task roadmap** — [`docs/implementation-plan.md`](docs/implementation-plan.md)
- 📐 **Product & flows** — [`docs/product-requirements.md`](docs/product-requirements.md), [`docs/user-flows.md`](docs/user-flows.md)
- 🧭 **Decisions** — [`docs/decisions-and-assumptions.md`](docs/decisions-and-assumptions.md), [`docs/deviations.md`](docs/deviations.md)
- 🗄️ **Data & backup format** — [`docs/data-model.md`](docs/data-model.md), [`docs/backup-format.md`](docs/backup-format.md)
- 🎨 **Design** — [`docs/design-system.md`](docs/design-system.md), prototype HTML above
- 🧪 **Testing & AI workflow** — [`docs/testing-strategy.md`](docs/testing-strategy.md), [`AGENTS.md`](AGENTS.md)

## Built with AI (on purpose)

Planned with Claude, implemented with Cursor Agent, directed and reviewed by a human. Rules live in `AGENTS.md`, `.cursor/` and `docs/ai-development-workflow.md`. Commits carry an `Assisted-by` trailer; the maintainer owns everything merged.

## Licence & fonts

MIT — see [`LICENSE`](LICENSE).  
Fonts in `assets/fonts/`: **DynaPuff** (SIL OFL 1.1, wordmark) and **Roboto** (Apache 2.0, UI). Both show up on the in-app licences page via `LicenseRegistry`.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Until the first release, issues and discussion help most.
