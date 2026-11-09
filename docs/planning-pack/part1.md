# ZeroCart Planning Pack, Part 1: Decisions, Architecture, Data Model, ADRs

**App name: ZeroCart. Repository: zero-cart. Dart package: zero\_cart**. Status: draft for your review.

Nothing here was executed or checked against live package documentation. Package versions are deliberately not specified; the implementation agent must verify them (see 2.1).

This part contains four repo documents in order: `docs/decisions-and-assumptions.md`, `docs/architecture.md`, `docs/data-model.md`, `docs/adr/0001` to `0006`. Later parts: (2) product requirements, user flows, design system, HTML prototype; (3) implementation plan; (4) testing strategy, backup format, AI workflow files, repository docs, final handoff.

---

## 1. docs/decisions-and-assumptions.md

Binding unless you override. Items marked \[REVIEW\] are the ones I most want you to look at.

### 1.1 Decisions where the spec was silent or ambiguous

**Navigation and capture**

- **D-01** Three-tab NavigationBar: **Home**, **Inbox** (badge with count), **Stores**. Home shows one large card per non-archived store with the number of items left to buy; tapping a card opens the store's details, where its lists live (Part 2a, 3.12). Contextual screens: store details, list details, wishlist, archives (entered from Stores), settings (app bar icon on the Home tab only). Material 3 guidance wants 3 to 5 destinations, and Inbox needs one-tap access with a visible count. \[REVIEW\]
- **D-02** A Quick add FAB on all three tabs opens a bottom sheet (title, optional description, buttons Add and Add another). The keyboard opens immediately and the item goes to Inbox. Inside a list screen the FAB is replaced by an inline add row at the bottom that writes directly to that list and keeps focus for rapid entry.

**Lists and items**

- **D-03** One `position` sequence per list covers active and purchased items. Purchasing never changes position; the two sections are filters. This makes 'uncheck returns to its original relative position' automatic.
- **D-04** New items (added, assigned, copied) get position = max + 1, so they land at the bottom of the active section.
- **D-05** Only active items are draggable. Purchased rows show no handle and are ordered by position.
- **D-06** Reorder renumbers the whole list densely (1..n). Active items take the existing active slots in their new order; purchased items keep their index. Purchased rows therefore never move relative to each other.
- **D-07** Removal is a hard delete. Undo re-inserts the snapshot (same id, position, purchased state). One Undo at a time: showing a new removal snackbar makes the previous removal final. Undo ends with the snackbar or an app restart.
- **D-08** Limits: store name 40, list name 60, item title 50, description 70 characters (sized for instant capture). Titles are single-line (newlines become spaces on input); descriptions are also single-line and wrap to at most 2 lines. All text is trimmed; an empty title or name is rejected inline, no dialog.
- **D-09** Names are not unique anywhere.

**Lifecycle**

- **D-10** List states: Active, Archived (reason `manual` or `finished`). Archived returns to Active via Restore for both reasons. No permanent deletion of lists or stores in v1. \[REVIEW\]
- **D-11** Finish shopping with no unpurchased items archives immediately with a snackbar (Undo = restore). With unpurchased items a bottom sheet shows the count and offers: carry forward into a new list (name field prefilled) or archive without carrying. An empty list can also be finished.
- **D-12** Carry-forward creates a new active list in the same store, default name `Leftovers: <original name>` (truncated to the limit), editable in the sheet. Items are copied with new ids, unpurchased, positions renumbered 1..n in the original relative order. The original is archived untouched, so unpurchased items stay unpurchased in the snapshot.
- **D-13** Archived lists are read-only except Restore. Restoring a finished list that was already carried forward may duplicate leftovers; accepted, no linkage tracking.
- **D-14** Archiving a store does not change its lists' own state. Its active lists stay active but disappear everywhere until restore. A dialog states the number of active lists. Archived stores are viewable read-only from Archives; restore to edit.
- **D-15** Home and all assignment pickers exclude archived stores and archived lists.

**Inbox and wishlist**

- **D-16** Inbox is ordered newest first. The assignment sheet offers store chips plus New store, then that store's active lists plus New list. It preselects the store/list with the most recent activity (`updated_at`). Long-press multi-select enables batch assignment to one target. \[REVIEW, small scope addition that serves capture-first\]
- **D-17** Assignment is one transaction including any new store/list; the Inbox row is deleted in the same transaction. On failure nothing changes, the sheet stays open, an error snackbar shows. Batches append in creation order (oldest first).
- **D-18** Wishlist is ordered by creation (no manual order in v1). 'Add to list' copies title and description to an active list of the same store (or a new one), multi-select supported. The wishlist entry stays. No link column, so copies are independent.
- **D-19** Inbox and wishlist items are edited in a sheet and removed by swipe-left with Undo, same pattern as list items.

**Sharing**

- **D-20** First line is the list name, then one line per unpurchased item in position order: `Title` or `Title - Description` (spaced hyphen). Lines are joined by newlines with no trailing newline. Nothing else is shared: no store name, checkboxes, count or blank lines. No escaping or markdown, UTF-8 as typed. Descriptions are single-line (D-08), so there is no line-break handling. If nothing is left, the Share button stays tappable, shows a snackbar 'Nothing left to share' and does not open the share sheet.

**Settings and accessibility**

- **D-21** Settings live in the SQLite database (key-value table), not SharedPreferences, so backup and restore of settings is atomic with the data. Only `theme_mode` (system, light, dark) in v1. The database opens before `runApp`. \[REVIEW\]
- **D-22** Every gesture has a non-gesture equivalent: Move up / Move down semantic actions for reorder; a Remove semantic action plus a Remove button in the edit sheet; checkbox rows at least 48dp.
- **D-23** Store colour never carries meaning alone; the name is always shown.

### 1.2 Conflicts and risks

- **Gestures:** vertical scroll, drag-to-reorder and swipe-to-dismiss compete. Resolution: Dismissible only end-to-start, drag only from a 48dp handle.
- **'Minimal confirmations' vs destructive actions:** only two dialogs exist, archiving a store with active lists and replace-all restore. Everything else is Undo or a reversible archive.
- **Restore is the highest-risk operation.** The confirmation dialog offers 'Export current data first'.
- **Fonts:** the prototype may load Google Fonts online, but the app bundles DynaPuff (OFL, wordmark only) and Roboto (confirm its licence from the downloaded files; Apache 2.0 in my recollection) because the app is offline-first.
- **iPad:** the share sheet needs a source rectangle on iPad. Always pass the Share button's rect to share\_plus.

### 1.3 Assumptions for your review

Three-tab navigation (D-01); no permanent deletion (D-10); batch assignment (D-16); settings in SQLite (D-21); Riverpod without code generation (ADR-0001); fonts bundled rather than fetched at runtime; generated Drift files not committed but schema snapshots committed (2.5); English plus Serbian Latin following the system language, no in-app language selector (Part 2a, NF-2).

---

## 2. docs/architecture.md

### 2.1 Stack

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

### 2.2 Layers and the domain-layer decision

```
ui (widgets) -> providers/controllers -> repositories -> Drift database
```

- **Presentation:** widgets only render `AsyncValue`s and call controller or repository methods. No business rules, no SQL.
- **Controllers:** Riverpod `Notifier`s for UI-only state (multi-select, add-row draft, expanded sections). Thin.
- **Repositories:** plain classes holding every business rule and transaction (section 3.5). One per area: stores, lists (lists and items, finish, carry-forward), inbox, wishlist, backup, settings. Operations spanning areas (assign, copy, finish, restore) live in the repository that owns the target and use `db.transaction`.
- **Data:** Drift tables and generated row classes.
- **Domain layer: not justified.** There is one data source, no rule shared across several stores, and the generated rows are adequate models. Rows are used directly in the UI (annotate with `@DataClassName` for clean names: `Store`, `ShoppingList`, `ListItem`, `InboxItem`, `WishlistItem`). No repository interfaces; tests use an in-memory Drift database instead. Pure logic (dense reorder computation, share-text formatting, backup validation) lives in plain functions under `core/` so it is unit-testable without a database.

### 2.3 Folder structure

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

### 2.4 Data flow

- **Reads:** `repository.watchX()` (Drift `watch()`) wrapped in a `StreamProvider` (a `.family` for per-id queries). Equivalent to collecting a Room `Flow` as state. One stream per screen; active and purchased sections are derived from one items query ordered by position.
- **Writes:** widget calls `ref.read(repoProvider).method()`, which runs a transaction; Drift re-emits and the UI rebuilds. No manual cache or invalidation.
- **Optimistic state only during drag:** the reorderable list holds a local order until the repository write completes, to avoid a flicker when the stream re-emits.

### 2.5 Flutter-specific rules the agent must follow

- Repository providers are app-lifetime (not autoDispose). Undo callbacks run from a SnackBar that can outlive the screen that created it, so capture the repository before navigating and never use a disposed widget's `ref` in the callback.
- Use `SliverReorderableList` for active items and a separate `SliverList` for purchased items inside one `CustomScrollView`. Reorder callbacks have a known index adjustment gotcha (`newIndex` shifts when moving down); check the current Flutter API and test it explicitly.
- Enable `PRAGMA foreign_keys = ON` in Drift's `beforeOpen`. SQLite does not enforce foreign keys by default.
- Generated `*.g.dart` files are not committed; CI and the agent run build\_runner. Drift schema snapshots in `drift_schemas/` are committed.
- No fixed heights on rows; layouts must survive 200% text scale. Use `const` widgets and narrow `ref.watch` scopes.

---

## 3. docs/data-model.md

### 3.1 Conventions

Ids are UUID v4 text generated in the app. Timestamps are UTC (`created_at`, `updated_at` on every entity; backups serialise ISO-8601 UTC). Enumerations are text with CHECK constraints. Empty descriptions are stored as NULL. Foreign keys are enforced.

### 3.2 Tables

**stores**: `id` TEXT PK; `name` TEXT NOT NULL, CHECK trimmed length 1..40; `color_key` TEXT NOT NULL (one of eight palette keys: tomato, tangerine, lemon, lime, teal, sky, grape, bubblegum; validated in app and on restore); `address` TEXT NULL; `note` TEXT NULL; `archived_at` NULL; `created_at`; `updated_at`. Index on `archived_at`. Default colour for a new store: first palette key not used by an active store, else cycle.

**shopping\_lists**: `id` PK; `store_id` FK to stores, ON DELETE CASCADE, NOT NULL; `name` CHECK 1..60; `archived_at` NULL; `archive_reason` TEXT NULL CHECK IN ('manual','finished'); CHECK `(archived_at IS NULL) = (archive_reason IS NULL)`; `created_at`; `updated_at` (touched on add, assign, copy and carry-forward, not on check toggles; used to preselect the most recent list). Index `(store_id, archived_at)`.

**list\_items**: `id` PK; `list_id` FK to shopping\_lists, ON DELETE CASCADE; `title` CHECK 1..50; `description` NULL (max 70); `is_purchased` BOOL default false; `position` INTEGER NOT NULL; `created_at`; `updated_at`. Index `(list_id, position)`. **No unique constraint on position**: an undo can legally recreate a tie, resolved by ordering on `(position, created_at, id)`; dense renumbering on reorder removes ties.

**inbox\_items**: `id` PK; `title`; `description`; `created_at`; `updated_at`. Index `created_at`.

**wishlist\_items**: `id` PK; `store_id` FK to stores, ON DELETE CASCADE; `title`; `description`; `created_at`; `updated_at`. Index `(store_id, created_at)`. A store has exactly one wishlist, so there is no wishlists table.

**app\_settings**: `key` TEXT PK; `value` TEXT NOT NULL. v1 key: `theme_mode` in (system, light, dark), absent means system.

Cascades exist for integrity and for restore; no UI path deletes a store or list in v1 (D-10).

### 3.3 Separate tables vs one shared items table

Separate tables. The three item kinds have different parents (none, store, list) and different columns (purchased state and position exist only on list items). A single table with a container discriminator would need a polymorphic parent, which gives up real foreign keys, and every query would filter on the discriminator. The duplicated columns (title, description, timestamps) are cheap, and a Drift column mixin can share the declarations. Independence of copies falls out for free.

### 3.4 Invariants

- **I1** Every list item has an existing list; every list has an existing store (foreign keys).
- **I2** `archived_at` and `archive_reason` are both set or both null.
- **I3** Add, assign, copy and carry-forward targets must be an active list in a non-archived store, checked inside the same transaction as the write.
- **I4** Titles and names are non-empty after trimming.
- **I5** Reorder never changes the relative order of purchased items.
- **I6** An inbox item is deleted if and only if its copy was inserted (same transaction).
- **I7** Wishlist rows are never modified by copying.

### 3.5 Operations (pseudocode, transaction boundaries marked TX)

**1. Add / remove item**

```
addItem(listId, title, desc):
  TX { assertListActive(listId)
       pos = (max(position) where list_id = listId) ?? 0, then + 1
       insert item(newId, listId, title, desc, false, pos)
       touch list.updated_at }
removeItem(itemId):
  snapshot = select item; delete item; return snapshot   # single statement pair, TX
```

**2. Undo removal**

```
restoreItem(snapshot):
  TX { if list missing or archived: fail ListUnavailable (snackbar explains)
       insert snapshot unchanged (same id, position, is_purchased, timestamps) }
```

**3. Purchase / unpurchase**

```
setPurchased(id, bool): update is_purchased, updated_at.   # position untouched
```

**4. Reorder active items**

```
reorderActive(listId, orderedActiveIds):
  TX { all = items of list ordered by (position, created_at, id)
       activeNow = ids in all where not purchased
       abort StaleOrder if set(activeNow) != set(orderedActiveIds)
       newSeq = all, but each active index takes the next id from orderedActiveIds
       write position = index+1 for every row whose position changed }
```

The pure function `computeDenseReorder(all, orderedActiveIds)` does the middle steps. Move up / Move down actions call the same operation.

**5 and 6. Assign Inbox item(s), including new store/list**

```
assignInbox(inboxIds, target):
  # target = ExistingList(listId) | NewList(store, name)
  # store  = ExistingStore(id) | NewStore(name, colorKey?)
  TX { items = select inbox where id in inboxIds, ordered by created_at asc; abort if any missing
       store = resolve (insert if new; abort if archived)
       list  = resolve (insert if new in store; else assert active and in store)
       for each item: insert list item at max+1 (D-04)
       touch list.updated_at
       delete the inbox rows }
```

Any failure rolls back everything, including newly created store and list; the Inbox is unchanged.

**7. Copy wishlist item(s)**

```
copyWishlist(wishlistIds, target):   # target list must belong to the wishlist's store
  TX { resolve/create list in that store; insert copies at max+1 with new ids
       touch list.updated_at; wishlist rows untouched }
```

**8 and 9. Finish list and carry forward**

```
finishList(listId, carryForward, newName):
  TX { list must be active
       left = items where not purchased ordered by (position, created_at, id)
       set archived_at = now, archive_reason = 'finished'
       if carryForward and left not empty:
         newList = insert list(same store, newName)
         insert copies of left with new ids, is_purchased = false, positions 1..n
       return {archivedListId, newListId?, carriedCount} }
```

One transaction: either the list is archived and the leftovers exist, or neither. Undo of a finish without carry-forward is Restore.

**10. Archive and restore store**

```
countActiveLists(storeId)  # for the dialog
archiveStore(id): set archived_at = now, updated_at.   # lists untouched
restoreStore(id): set archived_at = null.
```

Both idempotent.

**11. Export**

```
export():
  TX(read) { read all six tables }      # consistent snapshot
  build map {format, schemaVersion, appVersion, exportedAt, data{...}}
  encode JSON, write to temp file, hand to share sheet
```

No partial files are shared; the format is specified in `docs/backup-format.md` (Part 4).

**12. Validate and restore**

```
restore(fileBytes):
  reject if larger than the size cap (20 MB) or not UTF-8 JSON      -> BackupError.corrupt
  check format id and schemaVersion: newer than supported           -> BackupError.incompatible
  upgrade older versions through explicit stepwise upgraders
  validate everything in memory: types, lengths, enums, color keys, unique ids,
    all foreign keys resolve, archive fields consistent, positions are integers
  any failure -> BackupError with a user-readable reason; database never touched
  user confirms (dialog offers 'Export current data first')
  TX { delete from list_items, wishlist_items, shopping_lists, stores, inbox_items, app_settings
       insert all rows, parents before children; verify inserted counts match the file }
  exception anywhere -> rollback, previous data intact
  success -> navigate Home; Drift streams refresh the UI
```

### 3.6 Migrations

Drift `schemaVersion` starts at 1 and uses stepwise migrations. Every PR that changes a table must bump the version, add the migration, commit the updated snapshot in `drift_schemas/`, and add a migration test generated with Drift's schema tooling. Destructive migrations are not allowed without a documented data-preservation step. The backup `schemaVersion` is independent of the database version; its upgraders are specified in `docs/backup-format.md`.

### 3.7 Example data

| table | rows |
| --- | --- |
| stores | Lidl (lime), DM (sky) |
| shopping\_lists | 'Weekend groceries' (Lidl, active), 'Party' (Lidl, active), 'Next week' (Lidl, active), 'Drugstore run' (DM, active), 'Easter' (Lidl, archived, finished) |
| list\_items (Weekend groceries) | Milk / 2L, lactose-free (pos 1, active); Pasta / Whole wheat, 500g (pos 2, purchased); Bread (pos 3, active) |
| inbox\_items | Dishwasher tablets; Lightbulb / E27 warm white |
| wishlist\_items (DM) | Electric toothbrush heads |

Share text of 'Weekend groceries' is three lines: `Weekend groceries`, `Milk - 2L, lactose-free`, `Bread`. Pasta is excluded because it is purchased.

---

## 4. docs/adr/

### ADR-0001: State management is Riverpod

**Status:** Accepted (provisional on a version check of the current Riverpod API).

**Context:** Data is a local relational database exposed as reactive streams. UI state is small: selection, drafts, expanded sections. Business operations are transactional methods. Undo is a one-shot action with a snapshot.

**Drivers:** native stream support, dependency injection, testability with an in-memory database, low ceremony for AI-written code, one consistent pattern.

**Alternatives:** BLoC (explicit events and states; each interaction costs an event class, a handler and a state field, and Undo becomes either state in the bloc or a BlocListener side effect). Cubit (less ceremony, but no dependency injection, so a second mechanism such as provider or get\_it is needed anyway). Riverpod (streams, injection and overrides in one tool).

**Decision:** Riverpod 'by hand', without code generation. DB reads are `StreamProvider`s; UI-only state is a `Notifier`; repositories are plain classes exposed through providers.

**Representative operation, remove with Undo (pseudocode):**

```
# Riverpod
listItemsProvider.family(listId) = StreamProvider(repo.watchItems(listId))
on swipe: snapshot = await repo.removeItem(id)
          messenger.showSnackBar(action: Undo -> repo.restoreItem(snapshot))

# BLoC
event RemoveItemRequested(id) -> handler: snapshot = await repo.removeItem(id)
                                          emit(state.copyWith(pendingUndo: snapshot))
BlocListener: shows snackbar when pendingUndo != null, Undo adds RestoreItemRequested(snapshot),
              handler clears pendingUndo
```

**Consequences:** Android mapping: StreamProvider is like collecting a Flow, a Notifier is a lightweight ViewModel without lifecycle ownership, overrides replace Hilt test modules. Convention: never `ref.read` inside `build`, repository providers are app-lifetime, widgets never hold business rules.

**Trade-offs:** less enforced structure than BLoC; discipline rests on AGENTS.md rules and review. Riverpod's API has changed between major versions, so agents must check current docs and not rely on older snippets.

**Reconsider if:** provider count passes \~60, or flows need event replay or complex concurrency semantics.

### ADR-0002: Local persistence is Drift (SQLite)

**Status:** Accepted (provisional on package version verification).

**Context:** Relational data with parents and children, atomic multi-row operations (assign, finish, restore), reactive reads, ordering, and migrations that must not lose user data.

**Drivers:** real foreign keys and transactions, streams, type-safe queries, testable in memory, straightforward export to JSON.

**Alternatives:** sqflite (no typed queries or reactive streams, hand-written plumbing). Isar and Hive (object stores without relational integrity; Isar's maintenance status should be re-checked before relying on it, and I have not verified it here). ObjectBox (relations exist but a heavier commercial-flavoured stack). Plain JSON file (no transactions, whole-file rewrites). Drift (closest to Room: typed SQL, migrations, streams).

**Decision:** Drift with SQLite, foreign keys enforced, stepwise migrations with committed schema snapshots.

**Consequences:** build\_runner is required; the schema and invariants live in SQL constraints as well as Dart. Tests use in-memory databases. Backup maps row-for-row.

**Trade-offs:** codegen friction and SQLite knowledge needed, in exchange for integrity and testability.

**Reconsider if:** a platform target appears that Drift does not support, or the package becomes unmaintained.

### ADR-0003: Feature-first architecture without a domain layer

**Status:** Accepted.

**Context:** Small app, single local data source, no shared rules across sources, one developer plus coding agents.

**Drivers:** minimal indirection, rules in one findable place, agent-friendly consistency.

**Alternatives:** Clean Architecture with entities, use cases and repository interfaces (maps to your modular background but adds mapping and interface layers with nothing to swap). Layer-first folders (spreads one feature across the tree). Multi-package modules (build and tooling cost with no team-scale benefit).

**Decision:** Feature-first folders; repositories own business rules and transactions; pure helpers in `core/`; Drift rows are the models; no repository interfaces.

**Consequences:** UI depends on Drift row types. Tests use real in-memory Drift instead of mocks, which exercises the actual SQL.

**Trade-offs:** swapping the database later would touch more files; accepted.

**Reconsider if:** a second data source (sync) or a rule shared by several features appears.

### ADR-0004: Item ordering and Undo

**Status:** Accepted.

**Context:** Manual order must persist; purchased items must return to their original place; removal must be undoable with original order.

**Drivers:** simplest model that makes the three guarantees hold by construction, small lists, easy backup.

**Alternatives:** Fractional indexing or LexoRank strings (avoid renumbering writes, which only matter for very large lists, at the cost of opaque keys and rebalancing). Separate position per section (uncheck then needs its original place remembered). Soft delete with `deleted_at` (trivial Undo, but every query and the backup must filter deleted rows). Persisted undo stack (over-built).

**Decision:** Dense integer `position` in one sequence per list covering all items; purchase is a flag only. Reorder renumbers densely under D-06. Removal is a hard delete with an in-memory snapshot for Undo (D-07). Order by `(position, created_at, id)` to tolerate ties.

**Consequences:** Uncheck, carry-forward and Undo need no ordering code. Lists of hundreds of items renumber in one transaction without noticeable cost.

**Trade-offs:** a reorder writes several rows; Undo is lost on app restart.

**Reconsider if:** lists routinely exceed thousands of items, or Undo must survive restarts.

### ADR-0005: Backup and restore

**Status:** Accepted.

**Context:** Data ownership with no cloud. Restore must be safe, portable across Android and iOS, and survive app and schema evolution.

**Drivers:** no data loss on failure, human-inspectable file, versioning, no extra permissions.

**Alternatives:** Copying the SQLite file (binary, tied to the database schema version, hard to validate, platform paths). Merge-on-import (conflict rules out of scope for v1). Cloud backup (excluded). JSON with generated serializers (adds codegen for a flat format).

**Decision:** Versioned JSON mirroring the tables, hand-written mapping, validate fully in memory before touching the database, replace-all in one transaction, export through share\_plus, import through file\_picker. Settings are included.

**Consequences:** A new table or column requires updating the exporter, validator and upgraders and adding a round-trip test. The backup version is independent of the database version.

**Trade-offs:** hand-written mapping is more code than generated serialisation but keeps validation explicit. Replace-all can discard newer local data; mitigated by the 'Export current data first' option.

**Reconsider if:** merging across devices is wanted.

### ADR-0006: Navigation is go\_router with a stateful shell

**Status:** Accepted, provisional on checking the current go\_router API.

**Context:** Three tabs that should keep their own stack and scroll position, contextual detail screens, and many modal sheets.

**Drivers:** preserved tab state, correct back behaviour, declarative routes, no codegen, maintained by the Flutter team.

**Alternatives:** Plain Navigator with nested navigators (workable, tab state is manual). auto\_route (extra codegen). Hand-rolled Router API (too much code).

**Decision:** go\_router with `StatefulShellRoute` for Home, Inbox, Stores. Detail screens (store, list, wishlist, archives, settings) are routes with plain string path constants. Bottom sheets and dialogs are not routes: they use `showModalBottomSheet` and `showDialog`.

**Consequences:** Back button, predictive back on Android and iOS swipe-back follow standard route behaviour. No deep links in v1.

**Trade-offs:** string paths are not type-safe; acceptable at this size.

**Reconsider if:** deep links or a larger route tree are added.
