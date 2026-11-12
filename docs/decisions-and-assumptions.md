# Decisions and assumptions

Binding unless you override. Items marked \[REVIEW\] are the ones I most want you to look at.

## 1.1 Decisions where the spec was silent or ambiguous

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

**Architecture assumptions**

- **D-24** Write operations from widgets fall into two categories. (a) *One-shot
  actions* (archive, restore, setPurchased, rename): the database is local and
  fast (< 10 ms via Drift/SQLite). No loading spinner is shown; the stream
  reacts before the next frame and the UI updates automatically. Failure shows
  a snackbar. The widget calls the repository directly via `ref.read(repo)`.
  (b) *Form submissions* (addItem, save, updateItem, quickAdd): the widget
  shows a disabled button and inline error text during and after the async gap.
  These use an `AutoDispose Notifier`; the widget calls the notifier, not the
  repository. The distinction rests on whether the widget itself must show a
  busy or error state.

- **D-25** The one-shot pattern (D-24a) is valid only while the database is
  local. When a backend is introduced all write operations must be reviewed:
  each will likely need a Notifier with an optimistic-update or loading-state
  pattern. ADR-0003 already flags "a second data source" as a reconsider
  trigger.

## 1.2 Conflicts and risks

- **Gestures:** vertical scroll, drag-to-reorder and swipe-to-dismiss compete. Resolution: Dismissible only end-to-start, drag only from a 48dp handle.
- **'Minimal confirmations' vs destructive actions:** only two dialogs exist, archiving a store with active lists and replace-all restore. Everything else is Undo or a reversible archive.
- **Restore is the highest-risk operation.** The confirmation dialog offers 'Export current data first'.
- **Fonts:** the prototype may load Google Fonts online, but the app bundles DynaPuff (OFL, wordmark only) and Roboto (confirm its licence from the downloaded files; Apache 2.0 in my recollection) because the app is offline-first.
- **iPad:** the share sheet needs a source rectangle on iPad. Always pass the Share button's rect to share\_plus.

## 1.3 Assumptions for your review

Three-tab navigation (D-01); no permanent deletion (D-10); batch assignment (D-16); settings in SQLite (D-21); Riverpod without code generation (ADR-0001); fonts bundled rather than fetched at runtime; generated Drift files not committed but schema snapshots committed (2.5); English plus Serbian Latin following the system language, no in-app language selector (Part 2a, NF-2).
