# ZeroCart Planning Pack, Part 3: Implementation Plan

This is `docs/implementation-plan.md`: 27 tasks (APP-001 to APP-027) in 9 phases, ordered by dependency. Status: draft for your review. Part 4 supplies AGENTS.md, `.cursor/rules/`, `docs/testing-strategy.md` and `docs/backup-format.md`, which tasks below refer to.

Instruction to give Cursor for each task: 'Implement task APP-0NN according to the approved product specification, architecture, ADRs and acceptance criteria. Follow AGENTS.md and the project rules. Verify your work before proceeding.'

## 0. Rules that apply to every task

1. **Read first:** the task, the requirement IDs and decisions it cites (PRD, D-xx), the relevant ADRs, `docs/data-model.md` and the existing code. State the scope in a few lines before coding.
2. **Dependencies:** add a package only in the task that needs it. Before adding, check its current stable version, changelog and API on pub.dev; never take versions or API calls from memory. Report each added package with the version and the page checked.
3. **Strings:** every user-visible string goes through gen-l10n in `app_en.arb`, with ICU plurals for counts. Serbian is completed in APP-024; until then `app_sr_Latn.arb` may lag and the untranslated-messages report lists the gap.
4. **No hard-coded colours, sizes or fonts** outside `lib/app/theme/`. Use `Theme.of(context)` and the `AppTokens` extension.
5. **Business rules live in repositories** (ADR-0003); widgets only render and call. State follows ADR-0001; no other state mechanism.
6. **Generated files are not committed** (Drift, gen-l10n); Drift schema snapshots are.
7. **Quality gate:** `tool/check.sh` (created in APP-005; before that run the steps by hand): format check, `flutter analyze`, `flutter test`.
8. **Report** at the end: what was implemented; what was actually verified (commands run and results); what was not verified (for example no device available); deviations from the plan with reasons. Never claim a test passed that was not run.

**Global definition of done:** format and analysis clean, all tests pass, new behaviour covered by the tests the task names, listed docs updated, report delivered, no TODO without a task ID, nothing beyond the task's scope.

**Review gates (stop and wait for the owner):** after APP-008 (architecture checkpoint), after APP-014 (core list experience), after APP-022 (backup engine), before APP-027 (release).

| Phase | Tasks | Result |
| --- | --- | --- |
| 0 Foundation | 001-005 | Project, fonts, theme, navigation shell, CI |
| 1 Thin vertical slice | 006-008 | Database, pure logic, Inbox capture end to end |
| 2 Stores | 009-010 | Create, edit, archive, restore stores |
| 3 Lists and items | 011-014 | Lists, items, purchase, reorder, remove and Undo |
| 4 Assignment and wishlist | 015-016 | Inbox to list, wishlists |
| 5 Completion and sharing | 017-018 | Finish, carry-forward, archived lists, share |
| 6 Home and settings | 019-020 | Store card board, appearance, About |
| 7 Backup | 021-023 | Export, validated restore, UI |
| 8 Quality and release | 024-027 | Serbian, accessibility, goldens and integration, release readiness |

---

## Phase 0: Foundation

**Objective:** a runnable, linted, themed, navigable shell with CI before any feature code. **Depends on:** nothing. **ADRs:** 0003, 0006. **Files:** repo root, `lib/app/`, `lib/l10n/`, `assets/fonts/`, `tool/`, `.github/workflows/`. **Tests:** theme token and routing tests. **Phase done when:** the app launches on an Android and an iOS simulator into the three-tab shell in light and dark.

### APP-001 Create the project and repository skeleton

- **Context:** every later task assumes this structure.
- **Requirements:** create the Flutter project in a repo named `zero-cart` with Dart package `zero_cart`, Android and iOS only, placeholder bundle id `com.example.zerocart` (the owner sets the real one before release), iOS device family iPhone only. Remove the sample counter app. Create the folder skeleton from architecture 2.3 (empty files only where needed). Copy in the planning documents (`docs/`, `design/`, ADRs), AGENTS.md, `.cursor/rules/`, LICENSE, README, CONTRIBUTING from the planning pack. Add the Flutter `.gitignore` plus entries for generated Drift and gen-l10n output. `analysis_options.yaml`: flutter\_lints plus strict-casts, strict-inference, strict-raw-types, prefer\_const\_constructors, avoid\_print. No dependencies yet.
- **Components:** repo root, `pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart` (empty MaterialApp).
- **Depends on:** Part 4 documents available.
- **Acceptance:** `flutter run` shows an empty app on both platforms; analysis is clean; the iOS project targets iPhone only; the tree matches architecture 2.3.
- **Verify:** `flutter analyze`, `flutter test`, run on one simulator.
- **Docs:** README setup section (Flutter version used, commands).

### APP-002 Add fonts and register licences

- **Context:** offline-first, so fonts are bundled (design system 3.2). The owner downloads the files.
- **Requirements:** precondition: `assets/fonts/` contains Roboto Regular, Medium, Bold, DynaPuff Bold, and each family's licence file. If any is missing, stop and ask; do not download, generate or substitute fonts. Declare family `Roboto` (400, 500, 700) and `DynaPuff` (700) in `pubspec.yaml`. Register both licence texts with `LicenseRegistry`. Add a temporary debug screen (removed in this task) showing `Zeroč ćšžđ ČĆŠŽĐ` in Roboto Regular, Medium and Bold to check Serbian Latin glyphs, and the word ZeroCart in DynaPuff.
- **Components:** `assets/fonts/`, `pubspec.yaml`, `lib/main.dart` licence registration.
- **Depends on:** APP-001, owner-supplied font files.
- **Acceptance:** fonts render on a simulator; all five Serbian letters appear in all three Roboto weights without fallback glyphs; the licences page lists both fonts.
- **Verify:** manual screenshot check and report; if a glyph is missing, stop and report.
- **Docs:** README credits (font names, licences).

### APP-003 Implement theme and design tokens

- **Context:** the single source of visual values (design system 3.1 to 3.8).
- **Requirements:** explicit light and dark `ColorScheme`s with the exact hex values from design system 3.1 (not seed-generated). An `AppTokens` `ThemeExtension`: spacing scale, radii, store palette (key to colour, eight keys), success colours. `TextTheme` per 3.2 including a `wordmark` style (DynaPuff) and the large store-count style. Component themes: NavigationBar, FloatingActionButton (tertiary colour), filled Card, InputDecoration, floating SnackBar, bottom sheet (24 radius, drag handle), dialog (28 radius), Checkbox (6 radius), SegmentedButton, ChoiceChip, divider (outlineVariant).
- **Components:** `lib/app/theme/` (`app_theme.dart`, `app_tokens.dart`, `app_text.dart`).
- **Depends on:** APP-002.
- **Acceptance:** tests assert the ColorScheme values equal the design table and that the store palette has all eight keys; a test fails if `Color(0x` appears in `lib/` outside `lib/app/theme/`.
- **Verify:** unit tests; view light and dark on a simulator.
- **Docs:** none unless a token deviates (then update `docs/design-system.md`).

### APP-004 Localisation setup and navigation shell

- **Context:** routes and l10n must exist before screens (ADR-0006, PRD NF-2).
- **Requirements:** add go\_router, flutter\_localizations, intl. gen-l10n via `l10n.yaml`: template `app_en.arb`, a second file `app_sr_Latn.arb`, and an untranslated-messages report. `MaterialApp.router` with a locale resolution callback: any Serbian variant maps to `sr_Latn`, everything else to English. Router: `StatefulShellRoute.indexedStack` with branches `/home`, `/inbox`, `/stores`; contextual routes declared with string path constants and placeholder pages: `/stores/:id`, `/lists/:id`, `/stores/:id/wishlist`, `/archive`, `/settings`, `/settings/about`. NavigationBar with three destinations (Inbox has a badge slot). Home app bar: ZeroCart wordmark and a settings icon (Home only, D-01). A Quick add FAB on the three tab screens that does nothing yet.
- **Components:** `lib/app/app.dart`, `router.dart`, `lib/l10n/*.arb`, `l10n.yaml`, three placeholder screens under `features/home|inbox|stores/ui/`.
- **Depends on:** APP-003.
- **Acceptance:** tabs switch and keep their state; Back from `/settings` returns to Home; settings icon appears only on Home; locale resolution maps `sr`, `sr-RS`, `sr-Latn-RS` and `sr-Cyrl` to `sr_Latn`, and `de` to English.
- **Verify:** widget tests for tab switching, back behaviour and the resolution function; run on a simulator.
- **Docs:** none.

### APP-005 Add CI and the local check script

- **Context:** one quality gate for humans, agents and CI (testing strategy, Part 4).
- **Requirements:** `tool/check.sh` running: `dart pub get`, code generation (build\_runner once Drift exists, gen-l10n), `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`. A GitHub Actions workflow `.github/workflows/ci.yml` on push to main and on pull requests that runs the same script with the Flutter version pinned (read from one place and mirrored in README). Cache pub packages. Check the current setup action's documentation before using it.
- **Components:** `tool/check.sh`, `.github/workflows/ci.yml`.
- **Depends on:** APP-004.
- **Acceptance:** the script passes locally; the workflow file validates; the script fails when a file is badly formatted.
- **Verify:** run the script, then break formatting once to see it fail, then fix. CI itself can only be confirmed on GitHub; say so in the report.
- **Docs:** README quality-gate section.

---

## Phase 1: Thin vertical slice

**Objective:** prove the architecture end to end (Drift, Riverpod, UI, tests) on the smallest real feature. **Depends on:** phase 0. **ADRs:** 0001, 0002, 0003, 0004. **Files:** `lib/data/`, `lib/core/`, `lib/features/inbox/`. **Tests:** in-memory database tests, pure-logic tests, widget tests. **Phase done when:** you can capture items from the FAB, see them in the Inbox with a badge, edit, remove with Undo, and restart the app with the data intact.

### APP-006 Drift schema and database

- **Context:** the data model is the foundation for every feature (ADR-0002).
- **Requirements:** add drift, drift\_dev, build\_runner and the current recommended native opener. Implement all six tables from `docs/data-model.md` 3.2 exactly: columns, CHECK constraints (lengths use the limits 40, 60, 50, 70; archive consistency on lists), foreign keys with cascade, indexes, `@DataClassName` names (`Store`, `ShoppingList`, `ListItem`, `InboxItem`, `WishlistItem`). `AppDatabase` with `schemaVersion` 1, `PRAGMA foreign_keys = ON` in `beforeOpen`, a file connection (`zero_cart.sqlite`) and an in-memory constructor for tests. Generate the schema snapshot `drift_schemas/drift_schema_v1.json` and a migration test scaffold using Drift's schema tooling (check current docs). Add `build_runner` to `tool/check.sh`.
- **Components:** `lib/data/tables.dart`, `lib/data/database.dart`, `drift_schemas/`, `test/data/`.
- **Depends on:** APP-005.
- **Acceptance:** inserting an item for a missing list fails; an empty title fails; an archived list without a reason fails; deleting a store cascades to its lists, items and wishlist; items for a list read back ordered by `(position, created_at, id)`.
- **Verify:** database tests on the in-memory database; run the migration test scaffold.
- **Docs:** note the Drift DateTime storage choice in `docs/data-model.md`.

### APP-007 Core pure logic

- **Context:** small pure functions that tests can hit without a database.
- **Requirements:** `core/limits.dart` (title 50, description 70, list name 60, store name 40); `core/text_normalize.dart` (trim, newlines to spaces, clamp, empty description to null); `core/ids.dart` (UUID v4 wrapper); `core/clock.dart` (injectable now); `core/ordering.dart` with `computeDenseReorder(allItemsInOrder, orderedActiveIds)` per D-06, returning only changed positions and throwing a typed stale-order error when the id sets differ; `core/share_text.dart` with `formatShareText(listName, items)` per D-20.
- **Components:** `lib/core/`, `test/core/`.
- **Depends on:** APP-004.
- **Acceptance:** reorder tests cover purchased items in the middle, ties, a single item, no change, stale input; share text tests cover empty description, no unpurchased items, special characters and emoji (copied verbatim), and the exact format `List name` newline `Title - Description`.
- **Verify:** unit tests.
- **Docs:** none.

### APP-008 Inbox vertical slice (architecture checkpoint)

- **Context:** the first feature through every layer; the owner reviews the pattern before it is repeated.
- **Requirements:** add flutter\_riverpod and uuid. Providers: `appDatabaseProvider` (overridden in tests), `nowProvider`, `idGeneratorProvider`, `inboxRepositoryProvider` (app-lifetime), `inboxItemsProvider` (StreamProvider, newest first). `main.dart` opens the database before `runApp`. `InboxRepository`: watchAll, add, update, remove (returns a snapshot), restore(snapshot). Quick add sheet (D-02): title and optional description, Add and Add another, keyboard open immediately, counter from 40 characters, inline error for empty title. Inbox screen: rows, tap to edit in a sheet, empty state, badge on the tab (99+ cap). A reusable `SwipeToRemoveRow` in `core/widgets/` (swipe left, Undo snackbar through the root ScaffoldMessenger, one Undo at a time per D-07, semantic Remove action). The FAB on all three tabs opens Quick add.
- **Components:** `lib/data/`, `lib/core/widgets/`, `lib/features/inbox/` (repository, providers, `ui/`).
- **Depends on:** APP-006, APP-007.
- **Acceptance:** PRD IB-1, IB-2 (multi-select later), IB-4 and F1 pass; data survives an app restart; Undo restores the same row and position; a removed row stays gone after the snackbar ends.
- **Verify:** repository tests on an in-memory database; widget tests for add, Add another, edit, remove, Undo and the badge; manual F1 on a simulator including a restart.
- **Docs:** architecture 2.2 gets a short 'worked example: Inbox' paragraph naming the files. **Stop and report for owner review.**

---

## Phase 2: Stores

**Objective:** stores can be created, edited, archived and restored. **Depends on:** phase 1. **ADRs:** 0003. **Files:** `lib/features/stores/`, `lib/features/archive/`. **Tests:** repository and widget tests. **Phase done when:** PRD ST-1 to ST-5 pass, F12 works, and archived stores vanish from the Stores tab.

### APP-009 Stores repository and Stores tab

- **Context:** stores are the parent of lists and wishlists.
- **Requirements:** `StoresRepository`: watchActive (alphabetical, case-insensitive), watchById, create, update, archive, restore, countActiveLists, `nextFreeColorKey()` (first palette key unused by active stores, else cycle). Stores tab: rows with colour dot, name and active-list count, 'New store' button, archive icon (opens `/archive`). Store form bottom sheet for create and edit: name required (max 40) with inline error, colour chips from the palette, optional address and note. The sheet returns a `StoreDraft` and does not write itself, so APP-015 can reuse it without side effects; the Stores tab and edit action perform the write.
- **Components:** `features/stores/` (repository, providers, `ui/store_form_sheet.dart`, `stores_screen.dart`).
- **Depends on:** APP-008.
- **Acceptance:** PRD ST-1, ST-2, ST-3; a new store gets the first unused colour; empty name keeps the sheet open with an error; editing updates everywhere at once.
- **Verify:** repository tests (ordering, free colour logic, cascade-free archive); widget tests for create and edit.
- **Docs:** none.

### APP-010 Store details, archive and restore

- **Context:** archiving is the only way to remove a store (D-10, D-14).
- **Requirements:** Store details screen at `/stores/:id`: header (colour dot, name, address, note), Edit and Archive in the app bar, sections for lists and wishlist as placeholders that later tasks fill. Archive shows a dialog only when active lists exist, naming the count with ICU plurals; otherwise it archives immediately. Archived stores open read-only with Restore. Archive screen at `/archive` with a Stores / Lists segmented control; the Stores segment works now, the Lists segment shows an empty placeholder until APP-017.
- **Components:** `features/stores/ui/store_details_screen.dart`, `features/archive/`.
- **Depends on:** APP-009.
- **Acceptance:** PRD ST-4 and F12; lists, items and notes are untouched by archive and restore; the dialog appears only with active lists.
- **Verify:** repository and widget tests including the dialog condition and read-only mode.
- **Docs:** none.

---

## Phase 3: Lists and items

**Objective:** the core shopping experience. **Depends on:** phase 2. **ADRs:** 0001, 0004. **Files:** `lib/features/lists/`. **Tests:** database tests for every operation in data model 3.5, widget tests for each interaction. **Phase done when:** PRD LI-1, LI-2, IT-1 to IT-7 pass and you can shop a list end to end.

### APP-011 Lists repository and store details lists

- **Context:** lists belong to a store; item operations come next.
- **Requirements:** `ListsRepository` list operations: watchActiveForStore with progress (left and total counts), watchById, create, rename, archive (manual), restore with the guard from LI-5 (typed error when the store is archived). Store details shows active list cards (name, items left) and a 'New list' action. List form sheet for create and rename (name required, max 60, not unique).
- **Components:** `features/lists/` (repository, providers, `ui/list_form_sheet.dart`), `store_details_screen.dart`.
- **Depends on:** APP-010.
- **Acceptance:** PRD LI-1, LI-2; creating a list in an archived store is rejected at the repository level; counts update live.
- **Verify:** repository tests for create, rename, archive, restore guard; widget test for creating a list.
- **Docs:** none.

### APP-012 Items and the list screen

- **Context:** the screen people use most (PRD IT-1 to IT-4, D-03 to D-05).
- **Requirements:** item operations in `ListsRepository`: watchItems ordered by `(position, created_at, id)`, addItem (position max + 1, touches the list's `updated_at`, rejects archived lists inside the transaction), updateItem, setPurchased (position untouched). List screen at `/lists/:id`: app bar with the list name and a menu (rename, archive; share and finish come later); active items and a collapsible 'Purchased (n)' section (expanded by default) derived from one items stream; item row (checkbox 48dp target, content, handle placeholder for active items), no reserved space for empty descriptions; inline add row (Enter adds, keeps focus, scrolls to the new item); edit sheet (title, description, Save); empty state. Semantic labels such as 'Milk, 2L lactose-free, not purchased'.
- **Components:** `features/lists/` (repository additions, providers, `ui/list_screen.dart`, `item_row.dart`, `item_edit_sheet.dart`).
- **Depends on:** APP-011.
- **Acceptance:** IT-1 to IT-4, IT-7; checking moves an item into Purchased and unchecking returns it to its original relative place; archived lists have no add row.
- **Verify:** database tests (max + 1 position, purchased flag leaves position alone, archived rejection); widget tests for add, check, uncheck, edit, collapse; manual F2, F5, F8.
- **Docs:** none.

### APP-013 Reorder

- **Context:** manual order is the only ordering mechanism (ADR-0004, D-06).
- **Requirements:** `ListsRepository.reorderActive(listId, orderedActiveIds)` implemented with `computeDenseReorder` in one transaction (abort on a stale order). Use a sliver reorderable list for active items and a separate sliver list for purchased items in one `CustomScrollView`. Handle drag target 48dp, light haptic on drag start, optimistic local order until the write completes. Handle the index adjustment of the reorder callback explicitly and check the current Flutter API. Move up and Move down as semantic actions. Purchased rows show no handle.
- **Components:** `features/lists/` (repository, `ui/list_screen.dart`).
- **Depends on:** APP-012, APP-007.
- **Acceptance:** IT-5; drag any active item to the top, middle and bottom and the order persists across restart; purchased items never move relative to each other; check, reorder others, uncheck returns the item to the slot given by its stored position.
- **Verify:** database tests (ties, purchased in the middle, stale input); widget drag test; semantics test for the move actions.
- **Docs:** none.

### APP-014 Remove and Undo for items (review gate)

- **Context:** destructive actions use Undo, not dialogs (D-07).
- **Requirements:** repository `removeItem` returns a snapshot and `restoreItem(snapshot)` re-inserts it unchanged inside a transaction (typed error if the list is missing or archived). Swipe left on active and purchased rows through `SwipeToRemoveRow`, a Remove button in the edit sheet, and a Remove semantic action. Snackbar 'Removed \<title>' with Undo for about 5 seconds; a second removal makes the first final. The Undo callback must capture the repository before any navigation so it works after leaving the screen; a failed Undo shows 'Could not restore'.
- **Components:** `features/lists/`, `core/widgets/swipe_to_remove_row.dart`.
- **Depends on:** APP-013.
- **Acceptance:** IT-6 and F7; Undo restores title, description, purchased state and position, including after other items were reordered; Undo works after navigating away from the list.
- **Verify:** database tests (restore with a position tie, restore into an archived list); widget tests for swipe, button, Undo, double removal, Undo after navigation.
- **Docs:** none. **Stop and report for owner review.**

---

## Phase 4: Assignment and wishlist

**Objective:** items flow from Inbox into lists, and wishlists work. **Depends on:** phases 1 to 3. **ADRs:** 0003, 0004. **Files:** `lib/features/inbox/`, `lib/features/wishlist/`, `lib/features/lists/`. **Tests:** transaction tests for every multi-row operation. **Phase done when:** PRD IB-2, IB-3, WL-1, WL-2 and flows F3, F4, F13 pass.

### APP-015 Assign Inbox items

- **Context:** capture-first needs a fast, atomic assignment (D-16, D-17, data model operations 5 and 6).
- **Requirements:** in `ListsRepository` add `assignInbox(inboxIds, target)` with sealed target types: existing or new store (`NewStore(StoreDraft)`), existing or new list (`NewList(name)`). One transaction: load the inbox rows (abort if any is missing), resolve or create the store (reject archived), resolve or create the list (existing must be active and in that store), insert items at max + 1 in creation order (oldest first), touch the list's `updated_at`, delete the inbox rows. Assignment sheet: store chips plus 'New store' (reuses the store form as a draft, nothing written until Confirm), list chips plus 'New list', the most recently active store and list preselected, Confirm. Inbox multi-select via long-press with an 'Assign selected' action. Success snackbar 'Added to \<list>' with Open; failure keeps the sheet open and the Inbox unchanged.
- **Components:** `features/lists/` (repository), `features/inbox/ui/assign_sheet.dart`, `inbox_screen.dart`, `features/stores/ui/store_form_sheet.dart` (draft mode).
- **Depends on:** APP-009, APP-012.
- **Acceptance:** F3 and F4; a failure at any step leaves no new store, no new list, no new item and the Inbox rows still present; batch order is oldest first; archived targets are rejected.
- **Verify:** database tests including forced failure mid-transaction (for example a list name that violates a constraint after the store was created); widget tests for the sheet, new store and new list paths, and multi-select.
- **Docs:** none.

### APP-016 Wishlists

- **Context:** one persistent wishlist per store (D-18, data model operation 7).
- **Requirements:** `WishlistRepository`: watch(storeId) ordered by creation, add, update, remove (snapshot) and restore. `ListsRepository.copyWishlistItems(ids, target)` in one transaction, target a list of the same store or a new list, copies with new ids at max + 1, wishlist rows untouched. Wishlist screen at `/stores/:id/wishlist`: rows, add and edit sheets (same limits and pattern as quick add), swipe remove with Undo, 'Add to list' per item and via multi-select with a list picker offering 'New list'. Store details shows a wishlist card with the count that opens the screen; archived stores show the wishlist read-only.
- **Components:** `features/wishlist/`, `features/lists/` (repository), `features/stores/ui/store_details_screen.dart`.
- **Depends on:** APP-012, APP-014.
- **Acceptance:** WL-1, WL-2, F13; editing or removing a copy never changes the wishlist entry and vice versa; copying never removes the entry.
- **Verify:** database tests (independence, new list creation in the same transaction, rollback); widget tests.
- **Docs:** none.

---

## Phase 5: Completion and sharing

**Objective:** finish a trip, keep history, share a list. **Depends on:** phases 3 and 4. **ADRs:** 0004. **Files:** `lib/features/lists/`, `lib/features/archive/`, `lib/core/`. **Tests:** transaction tests, widget tests. **Phase done when:** LI-3 to LI-5, SH-1 and flows F10, F11, F14 pass.

### APP-017 Finish shopping, archived lists, restore

- **Context:** the list lifecycle (D-10 to D-13, data model operations 8 and 9).
- **Requirements:** `ListsRepository.finishList(listId, carryForward, newName)` in one transaction: require an active list, collect unpurchased items in order, archive with reason `finished`, and when requested and non-empty create the new list in the same store with copies (new ids, unpurchased, positions 1..n); return the ids and the carried count. List screen app bar: Finish, which finishes at once with an Undo snackbar when nothing is left, otherwise opens a sheet with the count (ICU plural), a name field prefilled with the localised 'Leftovers: \<name>' (truncated to 60), 'Carry forward' and 'Archive without carrying'. Manual 'Archive list' with Undo. Archived list view is read-only (no checkbox, handle, add row or edit) with Restore. Archive screen Lists segment: archived lists grouped by store with a Finished or Archived label; Restore disabled with the hint 'Restore the store first' when the store is archived. Store details shows the archived-lists count and a link to the Archive screen.
- **Components:** `features/lists/` (repository, finish sheet, list screen), `features/archive/`.
- **Depends on:** APP-014, APP-010.
- **Acceptance:** LI-3, LI-4, LI-5; carry-forward keeps the original relative order and resets purchased state; the original stays archived with its items exactly as they were; a failure leaves the list active and creates no new list; an empty list can be finished; restoring a finished list works.
- **Verify:** database tests for every case above including forced rollback; widget tests for the sheet, no-leftover path, read-only view and the restore guard; manual F10 and F11.
- **Docs:** none.

### APP-018 Share a list

- **Context:** plain-text sharing (D-20, PRD SH-1).
- **Requirements:** add share\_plus. A thin `ShareService` wraps the platform call so tests can fake it. List screen share icon builds the text with `formatShareText` (list name first line, then unpurchased items in position order as `Title` or `Title - Description`). With nothing to share, show the snackbar 'Nothing left to share' and do not open the share sheet. Always pass the button's rectangle as the share origin (required on iPad, harmless elsewhere).
- **Components:** `core/share_service.dart`, `features/lists/ui/list_screen.dart`.
- **Depends on:** APP-017, APP-007.
- **Acceptance:** SH-1; purchased items and store metadata are never included; the text matches the data model example exactly.
- **Verify:** widget test with a fake `ShareService` asserting the exact text and the empty case; manual share to a notes app on a device or simulator.
- **Docs:** none.

---

## Phase 6: Home and settings

**Objective:** the Home store board and the Settings screen. **Depends on:** phases 3 to 5. **ADRs:** 0001, 0002, 0006. **Files:** `lib/features/home/`, `lib/features/settings/`. **Tests:** widget and golden tests. **Phase done when:** the Home board matches design system 3.12 and the prototype, and theme changes persist.

### APP-019 Home store cards

- **Context:** Home is a board of large store cards, with no list shortcuts (D-01, design system 3.12).
- **Requirements:** a `StoreSummary` query: per active store the number of active lists, unpurchased and total item counts across active lists, and last activity (the latest active-list `updated_at`, falling back to the store's own). Order by last activity, newest first. Home body: an Inbox pill when the Inbox has items (opens the Inbox tab), then the two-column staggered board per 3.12 (right column offset 26dp, every third card taller, alternating tilt of about 1 degree, fill from mixing the store colour 38% into the background with `Color.lerp`, a solid corner circle, large count, name, thin progress bar, list count, states 'left to buy', 'cart is empty', 'no lists yet'). Above 1.3x text scale use one column and no tilt. Tapping a card opens store details. Empty state with a 'Create a store' action. Semantic label: store name, items left, list count.
- **Components:** `features/home/` (`store_summary.dart`, providers, `ui/home_screen.dart`, `store_card.dart`).
- **Depends on:** APP-017, APP-003.
- **Acceptance:** counts and order update live; layouts survive 200% text without clipping; no list shortcuts on Home; contrast of text on every palette fill is checked in both themes and fixed in the theme if needed.
- **Verify:** repository query tests; widget tests; golden images for Home in light and dark with fixture data (generated and compared on the CI platform only); compare against the prototype.
- **Docs:** update design system 3.12 if the implementation changes anything.

### APP-020 Settings and About

- **Context:** appearance and information (D-21, PRD SE-1, SE-2, SE-4).
- **Requirements:** `SettingsRepository` over `app_settings` with `watchThemeMode` and `setThemeMode` (absent means system). Wire the theme mode into the app. Settings screen at `/settings`: Appearance segmented button (System, Light, Dark), a 'Backup and restore' section placeholder (wired in APP-023), About: version via package\_info\_plus, MIT notice, 'Open-source licences' via Flutter's licence page, and a repository link constant defined in one file.
- **Components:** `features/settings/`, `app/app.dart`.
- **Depends on:** APP-006, APP-004.
- **Acceptance:** the theme switches instantly and survives restart; first launch follows the system.
- **Verify:** repository tests; widget tests for the three modes and persistence.
- **Docs:** none.

---

## Phase 7: Backup and restore

**Objective:** portable, validated, atomic backup (ADR-0005). **Depends on:** phases 1 to 6 and `docs/backup-format.md`. **Files:** `lib/features/backup/`. **Tests:** fixtures, round trips, forced-failure rollback. **Phase done when:** PRD SE-3 and flows F15, F16 pass and no failure path loses data.

### APP-021 Backup export

- **Context:** data ownership (data model operation 11).
- **Requirements:** add path\_provider if not yet present. `BackupService.buildBackup()` reads all six tables in one consistent snapshot and maps them to the JSON structure in `docs/backup-format.md` with hand-written mapping (no serialisation codegen). `exportToFile()` writes `zero-cart-backup-YYYYMMDD-HHmm.json` to the temp directory and hands it to `ShareService`. Includes archived stores and lists, items with order and purchased state, wishlists, the Inbox and the theme setting; never device paths or derived data.
- **Components:** `features/backup/` (service, mappers).
- **Depends on:** APP-020, APP-018.
- **Acceptance:** output for a fixed sample database equals a committed fixture byte for byte (stable key and row order); timestamps are ISO-8601 UTC.
- **Verify:** unit tests against the fixture; a manual export to Files on a device.
- **Docs:** if the implementation forces a format change, update `docs/backup-format.md` and bump nothing silently.

### APP-022 Backup validation and restore engine (review gate)

- **Context:** the riskiest operation in the app (data model operation 12).
- **Requirements:** a pure `BackupValidator` that checks size cap (20 MB), UTF-8 JSON, format id, schema version (newer is incompatible, older goes through an upgrader chain that is empty for version 1 but present), types, lengths, enums, colour keys, unique ids, all foreign keys, archive consistency, integer positions; it returns a validated model or a typed `BackupError` with a user-readable reason. `BackupService.restore(validated)` in one transaction: delete all rows (children first), insert parents before children, verify row counts against the file, roll back on any exception. The database is untouched on every validation failure.
- **Components:** `features/backup/` (validator, errors, restore).
- **Depends on:** APP-021.
- **Acceptance:** every error class is covered; a restore of an exported backup reproduces the data exactly; a forced failure mid-insert leaves the previous data intact.
- **Verify:** fixtures for corrupted JSON, truncated file, wrong format id, newer version, missing foreign key, duplicate id, bad enum, over-length text, unknown colour key, inconsistent archive fields, oversized file; round trip equality test; rollback test with an injected failing insert.
- **Docs:** `docs/backup-format.md` error table if anything was refined. **Stop and report for owner review.**

### APP-023 Backup UI

- **Context:** exposing export and import safely (F15, F16, D-17 spirit: no data loss).
- **Requirements:** add file\_picker (check the current API and iOS JSON handling; fall back to any file type with content validation). Settings: 'Export backup' and 'Import backup'. Import flow: pick file, validate (show a clear message per `BackupError`), confirmation dialog stating that all current data is replaced with an 'Export current data first' option that runs the export then returns to the dialog, progress indicator, then on success go to Home with a snackbar. Cancelling anywhere changes nothing.
- **Components:** `features/settings/ui/`, `features/backup/`.
- **Depends on:** APP-022.
- **Acceptance:** F15 and F16; every error path shows a readable message; a backup made on one platform restores on the other where both are available.
- **Verify:** widget tests with fake picker and service; manual export and import on Android and iOS, including a corrupted file.
- **Docs:** README 'Backups' section.

---

## Phase 8: Quality and release

**Objective:** Serbian, accessibility, regression tests and release readiness. **Depends on:** all earlier phases. **Files:** `lib/l10n/`, `test/`, `integration_test/`, platform folders. **Phase done when:** the release checklist in APP-027 is complete and signed off by the owner.

### APP-024 Serbian translation

- **Context:** PRD NF-2.
- **Requirements:** complete `app_sr_Latn.arb` for every key, with ICU plurals using one, few and other. Add a check to `tool/check.sh` that fails on untranslated keys and on hard-coded user-visible strings in `lib/features/` (a simple scripted search for `Text('` and similar). The owner reviews the Serbian wording.
- **Components:** `lib/l10n/`, `tool/check.sh`.
- **Depends on:** APP-023.
- **Acceptance:** no untranslated keys; plural tests for counts 1, 2, 5, 11, 12, 21, 22 and 25 return the right forms; key screens render in Serbian at 200% text without clipping.
- **Verify:** unit tests on the plural messages; widget tests in both locales; owner review.
- **Docs:** none.

### APP-025 Accessibility pass

- **Context:** design system 3.9, PRD NF-1, D-22, D-23.
- **Requirements:** audit every screen. Add widget tests using Flutter's accessibility guideline matchers for tap target size, labelled targets and text contrast, in both themes. Verify semantics: item rows, checkbox state, Move up, Move down and Remove actions, live announcements for Undo, focus order, sheet and dialog focus. 200% text on all screens. Reduce-motion respected. Write `docs/accessibility-checklist.md` with a TalkBack and VoiceOver script and record the results.
- **Components:** across `features/` and `core/widgets/`; new doc.
- **Depends on:** APP-024.
- **Acceptance:** guideline tests pass on the main screens; the manual checklist is completed and recorded; fixes are made where it fails.
- **Verify:** automated guideline tests; manual run on one Android and one iOS device or simulators (state what was and was not covered).
- **Docs:** `docs/accessibility-checklist.md`.

### APP-026 Golden and integration tests

- **Context:** regression safety for the most visual and the most important flows (testing strategy).
- **Requirements:** goldens (light and dark) for the item row states, Home board, store form sheet and the finish sheet, tagged so they run only on the CI platform. Integration tests (`integration_test`) for: capture, assign to a new store and list, shop, reorder, finish with carry-forward; and backup export then restore. Document how to run them locally.
- **Components:** `test/goldens/`, `integration_test/`.
- **Depends on:** APP-025.
- **Acceptance:** goldens are stable across runs; integration tests pass on an Android emulator or simulator.
- **Verify:** run both suites; CI runs the unit, widget and golden tests; integration tests are run locally unless a stable CI setup is added.
- **Docs:** `docs/testing-strategy.md` run instructions.

### APP-027 Release readiness (review gate before)

- **Context:** a public, honest first release.
- **Requirements:** launcher icon and native splash using the theme background in light and dark; app display name ZeroCart; Android: confirm the release merged manifest has no INTERNET permission and set minimum SDK from the current Flutter default; iOS: iPhone only, no extra permissions beyond what packages require; versioning scheme; README split into 'implemented' and 'planned'; CONTRIBUTING and AI-development transparency updated; licences page complete including Roboto and DynaPuff; a manual QA script covering F1 to F18; release builds smoke-tested on both platforms; a short privacy statement ('no data leaves the device').
- **Components:** `android/`, `ios/`, `README.md`, `CONTRIBUTING.md`, `docs/`.
- **Depends on:** APP-026.
- **Acceptance:** the QA script passes; the owner signs off. Store publishing is outside this plan.
- **Verify:** release builds, manifest inspection, QA script results recorded.
- **Docs:** README, CONTRIBUTING.

---

## Dependency overview

```
001 -> 002 -> 003 -> 004 -> 005
005 -> 006 ; 004 -> 007 ; (006, 007) -> 008 [gate]
008 -> 009 -> 010 -> 011 -> 012 -> 013 -> 014 [gate]
(009, 012) -> 015 ; (012, 014) -> 016
(014, 010) -> 017 -> 018
(017, 003) -> 019 ; (006, 004) -> 020
(020, 018) -> 021 -> 022 [gate] -> 023
023 -> 024 -> 025 -> 026 -> 027 [gate]
```

Parallelism is possible but not recommended with a single agent: 019 and 020 can swap, and 015 and 016 can swap. Keep everything else in ID order.

**Recommended first task:** APP-001, after you have placed the Part 4 documents and (for APP-002) the four font files and licences in `assets/fonts/`.
