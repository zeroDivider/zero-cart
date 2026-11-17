# Codebase map

Facts verified against the tree as of APP-017b. Prefer this over recreating shared code.

## Shared primitives

### `lib/core/ui/`
- `app_messenger.dart` — root snackbars: `info`, `error`, `action`, `undo` (capture repos/l10n, not `ref`).
- `write_runner.dart` — `runWrite(action, l10n:)` runs a write; on failure shows `messageFor` via `AppMessenger.error`.
- `error_messages.dart` — `messageFor(l10n, error)` maps `RepositoryException` subtypes; else generic.

### `lib/core/widgets/`
- `form_sheet.dart` — `FormSheetScaffold`, `FormValidationAbort`, `FormSheetSecondaryAction` (submit/button).
- `async_body.dart` — `AsyncBody` loading / Retry / data for `AsyncValue`.
- `swipe_to_remove_row.dart` — end-to-start dismiss + semantic Remove.
- `quick_add_fab.dart` — coral Quick-add FAB shell.

### `lib/core/` logic
- `clock.dart` / `ids.dart` — injectable `Clock` / `IdGenerator` (`systemClock`, `generateUuidV4`).
- `limits.dart` / `text_normalize.dart` — D-08 lengths; `normalizeTitle` / name / description helpers.
- `ordering.dart` — `computeDenseReorder` (+ `StaleOrderException`).
- `share_text.dart` — `formatShareText` (no UI caller yet).
- `repository_exceptions.dart` — sealed typed failures for `messageFor`.

## Repositories (public ops)

### `StoresRepository` — `lib/features/stores/stores_repository.dart`
- `watchActive` / `watchActiveWithListCounts` / `watchArchived` / `watchById`
- `create` / `createFromDraft` / `update` / `updateFromDraft` — normalize name; validate colour
- `archive` / `restore` — soft archive; restore clears `archivedAt` only
- `countActiveLists` / `nextFreeColorKey`

### `ListsRepository` — `lib/features/lists/lists_repository.dart`
- `watchActiveForStore` / `watchById` / `watchActiveByRecency` / `watchItems`
- `create` / `rename` / `archive` (reason `manual`) / `restore` (fails if store archived)
- `finishList` — archives with `archiveReasonFinished`; optional carry-forward via `_insertNewList` (I3); returns `FinishListResult` (`lib/features/lists/finish_list_result.dart`)
- `addItem` / `updateItem` / `setPurchased` / `removeItem` / `restoreItem` / `reorderActive`
- `assignInbox` / `copyWishlistItems` — transactional move/copy; return list id+name

### `InboxRepository` — `lib/features/inbox/inbox_repository.dart`
- `watchAll` (newest first) / `add` / `update` / `remove` (snapshot) / `restore`

### `WishlistRepository` — `lib/features/wishlist/wishlist_repository.dart`
- `watch` / `watchCount` / `add` / `update` / `remove` (snapshot) / `restore` — rejects archived store

## Providers worth reusing

- `lib/data/providers.dart` — `appDatabaseProvider` (must override), `nowProvider`, `idGeneratorProvider`
- Feature `*RepositoryProvider`s — app-lifetime; wire clock/ids from above
- Streams: `inboxItemsProvider`; `activeStoresProvider`, `activeStoreSummariesProvider`, `archivedStoresProvider`, `storeByIdProvider`; `activeListsForStoreProvider`, `listByIdProvider`, `activeListsByRecencyProvider`, `listItemsProvider`; `wishlistItemsProvider`, `wishlistCountProvider`
- UI Notifiers: `inboxSelectionProvider`; `wishlistSelectionProvider` (autoDispose); `purchasedExpandedProvider` / `addItemNotifierProvider` (autoDispose family)

## Patterns established

- **Writes / failures:** direct actions → `runWrite`; forms → `FormSheetScaffold.onSubmit` (inline error). No `ScaffoldMessenger.of(context)` outside `lib/core/ui/`.
- **Forms / sheets:** bottom sheets under `lib/features/<feature>/ui/sheets/`; wrap body in `FormSheetScaffold`.
- **Undo:** hard delete → snapshot → `AppMessenger.undo` with captured repository (`removeListItemWithUndo` in `lists/remove_item_undo.dart`; same pattern in inbox/wishlist). Zero-leftover Finish uses `finishListWithUndo` (`lists/finish_list_undo.dart`) the same way.
- **Errors:** throw `RepositoryException` subtypes; UI uses `messageFor` / `AsyncBody`.
- **Async loading:** screens wrap `AsyncValue` in `AsyncBody` + `ref.invalidate` Retry.
- **UI state:** ephemeral form fields in sheet `State`; cross-widget / navigation-surviving selection via `Notifier` (ADR-0007).
- **Cross-feature sheets:** a feature may import another’s `ui/sheets/`, never its screens.

## Test helpers and fakes

- `test/support/test_app.dart` — `pumpTestApp` / `TestAppHarness`: in-memory Drift, fixed clock/ids, bridged stream providers (FakeAsync caveat on Windows); `refresh*` after writes.
- No Fake repository classes; repository tests use real memory DB. Platform edges: override clock/ids.
- `test/guards/adr0007_scanner.dart` — static ADR-0007 source guards.

## Screens and routes done

Routes in `lib/app/router.dart` (`AppRoutes` / `AppRouter`):
- Tabs: `/home` `HomeScreen`, `/inbox` `InboxScreen`, `/stores` `StoresScreen`
- `/stores/:id` `StoreDetailsScreen`, `/stores/:id/wishlist` `WishlistScreen`
- `/lists/:id` `ListScreen`, `/archive` `ArchiveScreen` (stores segment live)
- `/settings` / `/settings/about` — placeholder screens only

Sheets: store form; list form; item edit; finish list; inbox quick-add / edit / assign; wishlist add / edit / copy-to-list.

List screen (`/lists/:id`): Finish (active) opens `finish_list_sheet` when leftovers remain, else `finishListWithUndo` then navigates to the store; Restore (archived) via `runWrite(restore)`. Read-only archived body already hides checkbox, handle, add row and edit.

## Known gaps (from code, not the plan)

- Home body is still a placeholder string.
- Archive **Lists** segment is `_ArchivedListsPlaceholder`; Past trips / finished browsing is APP-017c.
- `formatShareText` has no feature caller / share UI.
- No backup/export/import Dart code.
- Settings / About are placeholders (entry from Home settings icon exists).
