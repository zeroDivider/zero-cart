# Codebase map

Facts verified against the tree as of APP-020. Prefer this over recreating shared code.

## Shared primitives

### `lib/core/ui/`
- `app_messenger.dart` — root snackbars: `info`, `error`, `action`, `undo` (capture repos/l10n, not `ref`).
- `write_runner.dart` — `runWrite(action, l10n:)` runs a write; on failure shows `messageFor` via `AppMessenger.error`.
- `error_messages.dart` — `messageFor(l10n, error)` maps `RepositoryException` subtypes; else generic.

### `lib/core/widgets/`
- `form_sheet.dart` — `FormSheetScaffold` scrolls its body when the sheet is taller than the space above the keyboard and shrink-wraps when the fields fit. Callers pad `viewInsets` once and do not add a second scroll view. Also `FormValidationAbort`, `FormSheetSecondaryAction` (submit/button).
- `async_body.dart` — `AsyncBody` loading / Retry / data for `AsyncValue`.
- `swipe_to_remove_row.dart` — end-to-start dismiss + semantic Remove.
- `quick_add_fab.dart` — coral Quick-add FAB shell.

### `lib/core/` logic
- `clock.dart` / `ids.dart` — injectable `Clock` / `IdGenerator` (`systemClock`, `generateUuidV4`).
- `limits.dart` / `text_normalize.dart` — D-08 lengths; `normalizeTitle` / name / description helpers.
- `ordering.dart` — `computeDenseReorder` (+ `StaleOrderException`).
- `share_text.dart` — `formatShareText` (D-20 plain text; unpurchased only).
- `share_service.dart` — `ShareService` / `PlatformShareService` / `shareServiceProvider` (wraps `share_plus`; fake in tests).
- `url_launcher.dart` — `UrlLauncher` / `PlatformUrlLauncher` / `urlLauncherProvider` (external browser; fake in tests).
- `repository_exceptions.dart` — sealed typed failures for `messageFor`.

## Repositories (public ops)

### `StoresRepository` — `lib/features/stores/stores_repository.dart`
- `watchActive` / `watchActiveWithListCounts` / `watchHomeStoreSummaries` / `watchArchived` / `watchById`
- `create` / `createFromDraft` / `update` / `updateFromDraft` — normalize name; validate colour
- `archive` / `restore` — soft archive; restore clears `archivedAt` only
- `countActiveLists` / `nextFreeColorKey`
- Home: `StoreSummary` in `lib/features/home/store_summary.dart` (list + item counts, last activity); do not reuse `ActiveStoreSummary`

### `ListsRepository` — `lib/features/lists/lists_repository.dart`
- `watchActiveForStore` / `watchById` / `watchActiveByRecency` / `watchItems`
- `watchFinishedListsForStore` / `watchFinishedCountForStore` — Past trips (`archiveReasonFinished`)
- `watchManualArchivedLists` — Archive Lists join → `ArchivedListWithStore` (store name, colour, `storeArchivedAt`)
- `create` / `rename` / `archive` (reason `manual`) / `restore` (fails if store archived)
- `finishList` — archives with `archiveReasonFinished`; optional carry-forward via `_insertNewList` (I3); returns `FinishListResult` (`lib/features/lists/finish_list_result.dart`)
- `addItem` / `updateItem` / `setPurchased` / `removeItem` / `restoreItem` / `reorderActive`
- `assignInbox` / `copyWishlistItems` — transactional move/copy; return list id+name

### `InboxRepository` — `lib/features/inbox/inbox_repository.dart`
- `watchAll` (newest first) / `add` / `update` / `remove` (snapshot) / `restore`

### `WishlistRepository` — `lib/features/wishlist/wishlist_repository.dart`
- `watch` / `watchCount` / `add` / `update` / `remove` (snapshot) / `restore` — rejects archived store

### `SettingsRepository` — `lib/features/settings/settings_repository.dart`
- `watchThemeMode` / `setThemeMode` — key `theme_mode` (`system`|`light`|`dark`); absent/unknown → system
- Upsert on write (stores explicit `system` for backup); helpers `themeModeFromStorage` / `themeModeToStorage`
- About: `kRepositoryUrl` in `repository_url.dart`; tap opens via `urlLauncherProvider` (external browser)

## Providers worth reusing

- `lib/data/providers.dart` — `appDatabaseProvider` (must override), `nowProvider`, `idGeneratorProvider`
- `lib/core/share_service.dart` — `shareServiceProvider` (override with `FakeShareService` in tests)
- Feature `*RepositoryProvider`s — app-lifetime; wire clock/ids from above
- Streams: `inboxItemsProvider`; `homeStoreSummariesProvider`; `activeStoresProvider`, `activeStoreSummariesProvider`, `archivedStoresProvider`, `storeByIdProvider`; `activeListsForStoreProvider`, `listByIdProvider`, `activeListsByRecencyProvider`, `finishedListsForStoreProvider`, `finishedCountForStoreProvider`, `manualArchivedListsProvider`, `listItemsProvider`; `wishlistItemsProvider`, `wishlistCountProvider`; `themeModeProvider`
- Settings: `settingsRepositoryProvider`; `packageInfoProvider` (About version)
- UI Notifiers: `inboxSelectionProvider`; `wishlistSelectionProvider` (autoDispose); `purchasedExpandedProvider` / `addItemNotifierProvider` (autoDispose family)

## Patterns established

- **Writes / failures:** direct actions → `runWrite`; forms → `FormSheetScaffold.onSubmit` (inline error). No `ScaffoldMessenger.of(context)` outside `lib/core/ui/`.
- **Forms / sheets:** bottom sheets under `lib/features/<feature>/ui/sheets/`; wrap body in `FormSheetScaffold`. The scaffold owns scrolling; sheet bodies are plain columns.
- **Undo:** hard delete → snapshot → `AppMessenger.undo` with captured repository (`removeListItemWithUndo` in `lists/remove_item_undo.dart`; same pattern in inbox/wishlist). Zero-leftover Finish uses `finishListWithUndo` (`lists/finish_list_undo.dart`) the same way.
- **Errors:** throw `RepositoryException` subtypes; UI uses `messageFor` / `AsyncBody`.
- **Async loading:** screens wrap `AsyncValue` in `AsyncBody` + `ref.invalidate` Retry.
- **UI state:** ephemeral form fields in sheet `State`; cross-widget / navigation-surviving selection via `Notifier` (ADR-0007).
- **Cross-feature sheets:** a feature may import another’s `ui/sheets/`, never its screens.

## Test helpers and fakes

- `test/support/test_app.dart` — `pumpTestApp` / `TestAppHarness`: in-memory Drift, fixed clock/ids, bridged stream providers including `themeModeProvider` (FakeAsync caveat on Windows); `refresh*` / `refreshThemeMode` after writes.
- `test/support/fake_share_service.dart` — records `shareText` calls; optional throw for failure paths.
- No Fake repository classes; repository tests use real memory DB. Platform edges: override clock/ids/share/url launcher.
- `test/support/fake_url_launcher.dart` — records `openExternal`; optional throw for failure paths.
- `test/guards/adr0007_scanner.dart` — static ADR-0007 source guards.

## Screens and routes done

Routes in `lib/app/router.dart` (`AppRoutes` / `AppRouter`):
- Tabs: `/home` `HomeScreen` (staggered `StoreCard` board + Inbox pill; empty → `showStoreFormSheet`), `/inbox` `InboxScreen`, `/stores` `StoresScreen`
- `/stores/:id` `StoreDetailsScreen`, `/stores/:id/wishlist` `WishlistScreen`, `/stores/:id/past-trips` `PastTripsScreen`
- `/lists/:id` `ListScreen`, `/archive` `ArchiveScreen` (Stores + manual Lists)
- `/settings` `SettingsScreen` — Appearance `SegmentedButton` via `runWrite(setThemeMode)`; Backup section placeholder (APP-023); About row → `/settings/about`
- `/settings/about` `AboutScreen` — version (`package_info_plus`), MIT notice, `showLicensePage`, `kRepositoryUrl`

`ZeroCartApp` is a `ConsumerWidget`: `themeMode` from `themeModeProvider` (fallback system while loading).

Sheets: store form; list form; item edit; finish list; inbox quick-add / edit / assign; wishlist add / edit / copy-to-list.

Store details: `StoreWishlistCard` then `StorePastTripsCard` (live counts; open child routes). Past trips / Archive Lists use lists providers only (never list screens); Restore via `runWrite`; LI-5 disables Restore when the store is archived.

List screen (`/lists/:id`): Share (active) builds D-20 text via `formatShareText`, gates empty with `AppMessenger.info`, else `ShareService` with button origin; Finish opens `finish_list_sheet` when leftovers remain, else `finishListWithUndo` then navigates to the store via `AppRouter.goToStoreDetails` (same helper after manual archive — `go(stores)` + `push(store)` so back returns to Stores); Restore (archived) via `runWrite(restore)`. Read-only archived body already hides checkbox, handle, add row and edit.

## Known gaps (from code, not the plan)

- No backup/export/import Dart code (`ShareService` is ready for APP-021 file share; Settings has a Backup section placeholder for APP-023).
