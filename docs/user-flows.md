# User flows

## 2.1 Navigation map

```
Shell with NavigationBar (state kept per tab)
  Home    /home     settings icon -> /settings -> /settings/about
                    store card    -> /stores/:id
  Inbox   /inbox
  Stores  /stores   store row -> /stores/:id -> /lists/:id
                                              -> /stores/:id/wishlist
                    archive icon -> /archive -> /stores/:id, /lists/:id (read-only)
Modal, not routes: quick add, assign, store form, list form, item edit,
                   finish shopping, copy to list, dialogs
```

Quick-add FAB shows on Home, Inbox and Stores only. List screens use the inline add row instead.

## 2.2 Screens

| Screen | Route | Purpose | Key elements |
| --- | --- | --- | --- |
| Home | /home | Go-shopping view | Wordmark, settings icon, Inbox pill, staggered board of large store cards, empty state |
| Inbox | /inbox | Capture backlog | Newest-first rows, multi-select, Assign action, empty state |
| Stores | /stores | Manage stores | Store rows, New store, archive icon |
| Store details | /stores/:id | One store | Header, active lists, wishlist card, archived lists section, edit and archive in menu |
| List details | /lists/:id | Shopping | Active items, add row, Purchased section, share, Finish, menu (rename, archive) |
| Wishlist | /stores/:id/wishlist | Someday items | Rows, add, Add to list |
| Archive | /archive | History | Segments: Stores, Lists; Restore actions |
| Settings | /settings | Preferences | Appearance, Backup and restore, About |
| About | /settings/about | Info | Version, licences, MIT notice |

## 2.3 Flows

Each flow gives the entry point, the steps and state change, the resulting UI, and the error and edge behaviour.

- **F1 Quick capture.** Entry: FAB on Home, Inbox or Stores. Type a title (keyboard already open), optionally open the detail field, tap Add or Add another. State: one inbox row inserted. UI: sheet closes (or clears), badge increments. Errors: empty title disables Add; a write failure shows inline text and keeps the input. Edge: a counter appears from 40 characters; hardware Enter adds.
- **F2 Add inside a list.** Entry: add row on the list screen. Type, Enter. State: list item at max position + 1 (D-04). UI: row appears at the bottom of the active section, focus stays. Errors: as F1. Edge: archived lists have no add row.
- **F3 Assign an Inbox item.** Entry: tap Assign on a row (or select several, then Assign). Pick a store chip, then a list; the most recently active pair is preselected. Confirm. State: one transaction inserts the list item and deletes the Inbox row (D-17). UI: row leaves the Inbox, snackbar with Open. Errors: failure keeps the sheet open and the row in the Inbox. Edge: if the Inbox is empty afterwards, the empty state shows.
- **F4 Assign with a new store or list.** Entry: 'New store' chip or 'New list' option inside the assignment sheet. A compact form replaces the step, then returns with the new entry selected. State: nothing is written until Confirm; store, list and item are created in one transaction. Errors: if the transaction fails, no store or list is left behind. Edge: backing out of the sheet discards the draft store and list.
- **F5 Check and uncheck.** Entry: checkbox. State: `is_purchased` toggles, position unchanged. UI: the item animates into or out of the Purchased section and a light haptic fires. Errors: none expected; a failed write reverts the checkbox with a snackbar. Edge: unchecking restores the original relative place (D-03).
- **F6 Reorder.** Entry: press and drag the handle (Move up and Move down via accessibility actions). State: one transaction renumbers positions (D-06). UI: row lifts, others shift; the order is held locally until the write completes. Errors: a stale order aborts the write and the list reloads. Edge: purchased rows are not draggable.
- **F7 Remove and Undo.** Entry: swipe left, or Remove in the edit sheet. State: row deleted, snapshot kept in memory. UI: row collapses, snackbar 'Removed \<title>' with Undo for about 5 seconds. Errors: Undo failing because the list was archived shows 'Couldn't restore'. Edge: a second removal makes the first final (D-07).
- **F8 Edit an item.** Entry: tap the row content. State: title and description update on Save. UI: bottom sheet with Save and Remove. Errors: empty title blocks Save. Edge: dismissing the sheet discards the change.
- **F9 Create a list.** Entry: 'New list' on store details. Enter a name, Create. State: empty active list. UI: opens the new list screen. Errors: empty name blocks Create.
- **F10 Finish shopping.** Entry: Finish in the list app bar. With no leftovers: archived at once, snackbar Undo. With leftovers: sheet shows the count, a name field (default 'Leftovers: \<name>'), 'Carry forward' and 'Archive without carrying'. State: one transaction (data model operation 8 and 9). UI: back to store details, the new list highlighted. Errors: failure leaves the list active. Edge: an empty list can still be finished.
- **F11 Archive and restore a list.** Entry: list menu 'Archive list', or Restore in Archive. State: `archived_at` and reason set or cleared. UI: snackbar with Undo on archive. Errors: Restore on a list of an archived store is disabled with a hint (LI-5).
- **F12 Archive and restore a store.** Entry: store menu. If active lists exist, a dialog names their count. State: `archived_at` set; lists untouched. UI: the store leaves Home, Stores and all pickers. Restore from Archive. Edge: archived stores open read-only.
- **F13 Wishlist add and copy.** Entry: wishlist card on store details. Add items in the same sheet pattern as F1. 'Add to list' (single or multi-select) opens the list picker with a 'New list' option. State: copies inserted at max + 1; wishlist rows unchanged (D-18). UI: snackbar with Open. Errors: as F3.
- **F14 Share.** Entry: share icon on the list screen. State: none. UI: native sheet with the D-20 text. Errors: nothing to share shows a snackbar and no sheet.
- **F15 Export backup.** Entry: Settings, Export. State: read-only snapshot written to a temp file. UI: native share sheet (save to Files, send, and so on). Errors: failure to write shows a snackbar; nothing partial is shared.
- **F16 Restore backup.** Entry: Settings, Import, pick a file. Validation runs first and any problem shows a clear message. A confirmation dialog warns that all current data is replaced and offers 'Export current data first'. State: one replace-all transaction. UI: success returns to Home. Errors: corrupt or incompatible files are rejected before any write; a failure mid-restore rolls back (ADR-0005).
- **F17 Change theme.** Entry: Settings, segmented button. State: `theme_mode` saved. UI: switches instantly, no restart.
- **F18 First launch and empty states.** Home shows a short welcome with 'Add your first item' and 'Create a store'; Inbox, Stores and wishlist each have a one-line prompt and a primary action. No onboarding screens.
