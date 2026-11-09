# Product requirements

ZeroCart v1 is a local-first shopping-list app for Android and iOS: capture items instantly into an Inbox, sort them later into named lists per store. Anything not listed here is out of scope.

## 1.1 Success criteria

- From a cold launch, an item is captured in two taps after typing its title (FAB, then Add).
- Every feature works in airplane mode. The release build requests no network permission and has no analytics or tracking.
- No operation can leave data half-changed (Part 1, section 3.4 invariants).
- A list of 500 items scrolls and reorders without visible jank on a mid-range device (verify on a real device).

## 1.2 Requirements

Each requirement has acceptance criteria (AC) that become tests in `docs/testing-strategy.md`.

**Stores (ST)**

- **ST-1 Create.** From the Stores tab ('New store') or inline in the assignment sheet; both use one bottom sheet: name (required, max 40), colour chips, optional address and note. AC: an empty name shows an inline error and keeps the sheet open; a new store gets the first unused palette colour; inline creation returns to the assignment sheet with the new store selected and the Inbox item untouched.
- **ST-2 View.** The Stores tab lists active stores alphabetically (case-insensitive) with colour dot, name and active-list count. Home shows one large card per active store (section 3.12), most recently active store first, with the number of items left to buy. AC: archived stores appear in neither.
- **ST-3 Edit** name, colour, address and note from store details. AC: changes show immediately everywhere the store appears.
- **ST-4 Archive and restore.** Archive from the store details menu. A dialog appears only when the store has active lists and names their count (D-14). Restore from the Archive screen. AC: lists, items, wishlist and notes survive an archive and restore round trip unchanged.
- **ST-5** No permanent deletion in v1.

**Shopping lists (LI)**

- **LI-1 Create** from store details, the assignment sheet, the wishlist copy sheet or carry-forward. Name required, max 60, not unique (D-09). AC: a new list is empty and active.
- **LI-2 Rename** from the list screen menu.
- **LI-3 Lifecycle.** Active, then Archived (manual or finished), then Active again via Restore (D-10, D-13). Manual 'Archive list' needs no dialog; a snackbar offers Undo. AC: an archived list is read-only (no checkbox, reorder, add row or edit); only Restore is available.
- **LI-4 Finish shopping** per D-11 and D-12. AC: with leftovers, a sheet shows their count and two actions (carry forward, archive without carrying); carry-forward creates the new list with unpurchased copies in the original relative order; with no leftovers the list archives at once and a snackbar offers Undo.
- **LI-5 Restore guard.** A list whose store is archived cannot be restored; Restore is disabled with the hint 'Restore the store first'. This closes a gap in the brief.

**Items (IT)**

- **IT-1 Add.** An inline row at the bottom of the list screen. AC: Enter adds the item, focus stays, the list scrolls to the new item; a detail toggle reveals the description field; whitespace-only titles are rejected.
- **IT-2 Row layout.** Left checkbox, middle title with the optional description beneath in smaller secondary text and no reserved space when empty, right drag handle (active items only). Titles wrap and are never ellipsised; descriptions wrap to two lines.
- **IT-3 Purchase.** The checkbox moves the item into the collapsible 'Purchased (n)' section, expanded by default, checked and subdued (muted colour plus strikethrough). Unchecking returns it to its original relative place (D-03). AC: check an item, reorder others, uncheck it, and it sits in the slot dictated by its stored position (ADR-0004).
- **IT-4 Edit.** Tapping the content (not the checkbox or handle) opens an edit sheet: title, description, Save, Remove.
- **IT-5 Reorder.** Drag from the handle; Move up and Move down as accessibility actions; purchased items are not reorderable (D-05).
- **IT-6 Remove.** Swipe left, the Remove button in the edit sheet, or the Remove accessibility action, with snackbar Undo (D-07). AC: Undo restores contents, purchased state and position.
- **IT-7 Limits** per D-08 (title 50, description 70).

**Inbox (IB)**

- **IB-1 Quick add** per D-02: a FAB on Home, Inbox and Stores opens a sheet with the keyboard up. 'Add' closes it; 'Add another' clears the fields and keeps it open.
- **IB-2 View, edit, remove.** The Inbox tab lists items newest first; tap edits; swipe left removes with Undo (D-19); long-press starts multi-select.
- **IB-3 Assign** per D-16 and D-17. Success removes the row or rows and shows a snackbar 'Added to \<list>' with an Open action. AC: a failure leaves the Inbox unchanged and the sheet open.
- **IB-4** The tab badge shows the count, capped at 99+. The empty state invites capture.

**Wishlist (WL)**

- **WL-1** One wishlist per store, reached from a card on store details (shows the count). Add (title, optional description), edit, remove with Undo.
- **WL-2 Add to list**, per item or multi-select: pick an active list of that store or create one. AC: the copy is independent, the wishlist entry stays (D-18).

**Sharing (SH)**

- **SH-1** A share icon in the list app bar opens the native share sheet with the D-20 text. AC: purchased items excluded, position order, empty case shows the snackbar and no sheet, no ids or app markers in the text. On iPad the share button's rect is passed as the source.

**Settings (SE)**

- **SE-1 Appearance.** System (default), Light, Dark as a segmented button. Applied instantly and stored in the database (D-21).
- **SE-2** Settings is reached only from the icon on Home's app bar (D-01).
- **SE-3 Backup and restore.** Export; Import with validation, confirmation and replace-all. Details in `docs/backup-format.md`.
- **SE-4 About.** App version, 'Open-source licences' (Flutter's licence page, including the two fonts), MIT notice, repository link (placeholder until the repository exists).

**Non-functional (NF)**

- **NF-1** Accessibility per design system section 3.9.
- **NF-2** English (default) and Serbian in Latin script. The locale follows the system language, any Serbian variant maps to Serbian Latin, and everything else falls back to English. All user-visible strings live in ARB files through Flutter's gen-l10n, never in widgets. Counts use ICU plurals, and Serbian needs the one, few and other forms (for example '3 of 8 left', 'Purchased (n)', the active-list count in the archive dialog). Text the user types or the app generates at creation time (store and list names, 'Leftovers: \<name>') is stored as written and never retranslated. Cyrillic is out of scope for v1. Serbian strings run longer, so no fixed-width labels; key screens are tested in both languages.
- **NF-3** v1 targets phones in portrait (iPhone-only device family on iOS). Landscape and tablet layouts are planned for v2. Orientation is not locked, so layouts must stay usable (scrollable, no overflow) in landscape without being polished.
- **NF-4** v1 is fully offline and account-free: no account, network access, analytics or notifications. All of these arrive in v2 with shared lists through a backend; v1 adds no architecture for them.

## 1.3 Out of scope for v1

Planned for v2 (not designed here): shared lists through a backend, which brings accounts, network access, sync, real-time collaboration, notifications and possibly analytics; landscape and tablet layouts. Not planned: location reminders, home-screen widgets, prices and budgets, product images, barcode scanning, a global product catalog, priority labels, ads and monetisation. Hands-free voice capture stays a future idea. v1 adds no architecture for any of these (ADR-0003 names the trigger for revisiting the architecture).
