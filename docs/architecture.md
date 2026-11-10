# Architecture

## 2.1 Stack

Verify the current stable version and changelog of every package before adding it. Do not copy versions from memory.

- **Flutter stable + Dart 3**, SDK version recorded in README and CI.
- **flutter\_riverpod**: state management and dependency injection (ADR-0001). No riverpod\_generator.
- **drift, drift\_dev, build\_runner** (+ **drift\_flutter** or the current recommended native opener; verify whether it bundles SQLite): persistence (ADR-0002).
- **go\_router**: navigation, StatefulShellRoute for tabs (ADR-0006).
- **uuid**: client-generated ids, needed for portable backups.
- **share\_plus**: plain-text list sharing and backup file export through the native sheet.
- **file\_picker**: backup import. Verify iOS JSON handling; fall back to any-type picking plus content validation.
- **path\_provider**: temp file for export. **package\_info\_plus**: About screen version. flutter\_localizations and intl with the SDK's gen-l10n tool and ARB files in lib/l10n: English and Serbian (Latin), ICU plurals (Serbian has one, few and other forms); see Part 2a, NF-2.
- **Licences page:** Flutter's built-in `showLicensePage`, with the two font licences registered through `LicenseRegistry`.
- **Dev:** flutter\_lints (plus a short stricter rule list), flutter\_test, integration\_test (SDK), drift schema tooling for migration tests. mocktail only if a fake is impractical.
- **Deliberately absent:** freezed, json\_serializable, hive, isar, get\_it, auto\_route, google\_fonts, bloc. Each would add codegen or a second state/DI mechanism without a demonstrated need.

Reason for no provider codegen: Drift already requires build\_runner. Adding riverpod\_generator doubles the generated surface, which agents handle poorly, and the app has roughly 30 providers. Reconsider if that grows past \~60.

## 2.2 Layers and the domain-layer decision

```
ui (widgets) -> providers/controllers -> repositories -> Drift database
```

- **Presentation:** widgets only render `AsyncValue`s and call controller or repository methods. No business rules, no SQL.
- **Controllers:** Riverpod `Notifier`s for UI-only state (multi-select, add-row draft, expanded sections). Thin.
- **Repositories:** plain classes holding every business rule and transaction (section 3.5). One per area: stores, lists (lists and items, finish, carry-forward), inbox, wishlist, backup, settings. Operations spanning areas (assign, copy, finish, restore) live in the repository that owns the target and use `db.transaction`.
- **Data:** Drift tables and generated row classes.
- **Domain layer: not justified.** There is one data source, no rule shared across several stores, and the generated rows are adequate models. Rows are used directly in the UI (annotate with `@DataClassName` for clean names: `Store`, `ShoppingList`, `ListItem`, `InboxItem`, `WishlistItem`). No repository interfaces; tests use an in-memory Drift database instead. Pure logic (dense reorder computation, share-text formatting, backup validation) lives in plain functions under `core/` so it is unit-testable without a database.

**Worked example: Inbox.** Capture flows through every layer once: `main.dart` opens `AppDatabase` and wraps the app in `ProviderScope` with `appDatabaseProvider` (plus `nowProvider` / `idGeneratorProvider` in `lib/data/providers.dart`). `InboxRepository` in `lib/features/inbox/inbox_repository.dart` owns normalize/reject, insert, update, hard-delete snapshot, and restore; `inbox_providers.dart` exposes the app-lifetime repository and `inboxItemsProvider` (`StreamProvider`, newest first). UI in `lib/features/inbox/ui/` (`quick_add_sheet.dart`, `inbox_edit_sheet.dart`, `inbox_screen.dart`) renders the stream and calls the repository; the shell FAB and badge live in `lib/app/scaffold_with_nav_bar.dart`. Shared swipe-Undo uses `lib/core/widgets/swipe_to_remove_row.dart` and `remove_undo_snackbar.dart` with `rootScaffoldMessengerKey`.

## 2.3 Folder structure

```
lib/
  main.dart                 # open DB, ProviderScope, runApp
  app/
    app.dart                # MaterialApp.router, theme mode from settings
    router.dart             # go_router config, route path constants
    theme/                  # tokens, ColorScheme light/dark, TextTheme, component themes
  core/
    ordering.dart           # computeDenseReorder (pure)
    share_text.dart         # formatShareText (pure)
    clock.dart, ids.dart    # injectable now() and uuid wrapper
    widgets/                # shared UI: sheets, empty states, swipe-to-remove row
  data/
    database.dart           # AppDatabase, migrations, foreign_keys pragma
    tables.dart             # Drift table definitions
  features/
    home/  inbox/  stores/  lists/  wishlist/  archive/  settings/  backup/
      <feature>_repository.dart
      <feature>_providers.dart
      ui/                   # screens and feature widgets
test/                       # mirrors lib/
integration_test/
drift_schemas/              # committed schema snapshots for migration tests
```

Rule: a feature may import `core/`, `data/` and other features' providers, never another feature's `ui/`.

## 2.4 Data flow

- **Reads:** `repository.watchX()` (Drift `watch()`) wrapped in a `StreamProvider` (a `.family` for per-id queries). Equivalent to collecting a Room `Flow` as state. One stream per screen; active and purchased sections are derived from one items query ordered by position.
- **Writes:** widget calls `ref.read(repoProvider).method()`, which runs a transaction; Drift re-emits and the UI rebuilds. No manual cache or invalidation.
- **Optimistic state only during drag:** the reorderable list holds a local order until the repository write completes, to avoid a flicker when the stream re-emits.

## 2.5 Flutter-specific rules the agent must follow

- Repository providers are app-lifetime (not autoDispose). Undo callbacks run from a SnackBar that can outlive the screen that created it, so capture the repository before navigating and never use a disposed widget's `ref` in the callback.
- Use `SliverReorderableList` for active items and a separate `SliverList` for purchased items inside one `CustomScrollView`. Reorder callbacks have a known index adjustment gotcha (`newIndex` shifts when moving down); check the current Flutter API and test it explicitly.
- Enable `PRAGMA foreign_keys = ON` in Drift's `beforeOpen`. SQLite does not enforce foreign keys by default.
- Generated `*.g.dart` files are not committed; CI and the agent run build\_runner. Drift schema snapshots in `drift_schemas/` are committed.
- No fixed heights on rows; layouts must survive 200% text scale. Use `const` widgets and narrow `ref.watch` scopes.
