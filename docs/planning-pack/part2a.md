# ZeroCart Planning Pack, Part 2a: Requirements, User Flows, Design System

App name: **ZeroCart** (repository zero-cart, Dart package zero\_cart). Status: draft for review. Builds on Part 1 (decision IDs D-xx and ADRs refer to it).

This part contains `docs/product-requirements.md`, `docs/user-flows.md` and `docs/design-system.md`. Part 2b is the HTML prototype (`design/shopping-app-prototype.html` and `design/README.md`). Contrast ratios and sizes below are design targets; the implementation must verify them with a contrast checker and on devices, and nothing here was machine-verified.

---

## 1. docs/product-requirements.md

ZeroCart v1 is a local-first shopping-list app for Android and iOS: capture items instantly into an Inbox, sort them later into named lists per store. Anything not listed here is out of scope.

### 1.1 Success criteria

- From a cold launch, an item is captured in two taps after typing its title (FAB, then Add).
- Every feature works in airplane mode. The release build requests no network permission and has no analytics or tracking.
- No operation can leave data half-changed (Part 1, section 3.4 invariants).
- A list of 500 items scrolls and reorders without visible jank on a mid-range device (verify on a real device).

### 1.2 Requirements

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

### 1.3 Out of scope for v1

Planned for v2 (not designed here): shared lists through a backend, which brings accounts, network access, sync, real-time collaboration, notifications and possibly analytics; landscape and tablet layouts. Not planned: location reminders, home-screen widgets, prices and budgets, product images, barcode scanning, a global product catalog, priority labels, ads and monetisation. Hands-free voice capture stays a future idea. v1 adds no architecture for any of these (ADR-0003 names the trigger for revisiting the architecture).

---

## 2. docs/user-flows.md

### 2.1 Navigation map

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

### 2.2 Screens

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

### 2.3 Flows

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

---

## 3. docs/design-system.md

Direction: **Colorful Notebook**. Clean off-white paper with cool blue-tinted surfaces, ruled-line dividers, rounded friendly shapes, a little expressiveness in headlines and empty states, and dense readable rows. No dashboard look, no decoration for its own sake. Tokens live in code as `ColorScheme` plus one `ThemeExtension` (store palette, spacing, success colours); widgets never hard-code values.

### 3.1 Colour tokens

Both schemes are written out explicitly rather than generated from a seed, to keep the brand colours exact. Brand inputs: deep blue #334E8C, periwinkle #A5BDF4, coral #F67583, mint #A5D5B6, off-white #FFFDF5.

| Role | Light | Dark |
| --- | --- | --- |
| background, surface | #FFFDF5 | #14171F |
| surfaceContainerLowest | #FFFFFF | #0F1218 |
| surfaceContainerLow | #F7F9FE | #191D26 |
| surfaceContainer | #F0F4FC | #1D212C |
| surfaceContainerHigh | #E6ECF8 | #262B38 |
| onSurface | #1E2230 | #E8E9F0 |
| onSurfaceVariant | #4D5368 | #B4B8C8 |
| outline | #7B8094 | #8A8FA3 |
| outlineVariant (ruled lines) | #D8DFEE | #3A3F4E |
| primary / onPrimary | #334E8C / #FFFFFF | #A5BDF4 / #14264F |
| primaryContainer / on | #DDE6FC / #14264F | #334E8C / #DDE6FC |
| secondary / onSecondary | #A5BDF4 / #1B2C55 | #B9C6E8 / #1B2C55 |
| secondaryContainer / on (nav indicator) | #C9D8F9 / #1B2C55 | #3A4A78 / #DCE5FB |
| tertiary (coral, FAB) / on | #F67583 / #3A0910 | #FF9AA4 / #3A0910 |
| tertiaryContainer / on | #FFD9DD / #5A1420 | #6B2230 / #FFD9DD |
| success (mint) / on | #A5D5B6 / #123B24 | #A5D5B6 / #123B24 |
| successContainer / on | #D9EEE0 / #123B24 | #1F4A33 / #D9EEE0 |
| error / onError | #B3261E / #FFFFFF | #F2B8B5 / #601410 |
| errorContainer / on | #F9DEDC / #410E0B | #8C1D18 / #F9DEDC |

Usage: primary for filled buttons, checked checkboxes, links and the wordmark; coral only for the Quick add FAB and the odd accent; mint for 'finished' and success states; errorContainer behind the swipe-to-remove action. Dark mode uses lifted surfaces, never pure black, and the same hues.

**Store palette** (separate from the brand palette; decorative dot or stripe, the name is always shown):

| Key | Hex | Key | Hex |
| --- | --- | --- | --- |
| tomato | #E5604F | teal | #2BA6A0 |
| tangerine | #F2994A | sky | #4A9BE0 |
| lemon | #D9A400 | grape | #8E6CCB |
| lime | #7DB84A | bubblegum | #E96FA6 |

On Home, store cards are filled with the store colour mixed about 38% into the theme background, with normal theme text on top (verify contrast for every palette colour in both themes). Elsewhere a store shows only its dot. The same hexes serve both themes; check each against the dark surface when building.

### 3.2 Typography

Bundled static fonts (offline-first, no runtime download): **Roboto** Regular 400, Medium 500, Bold 700 for all UI text, and **DynaPuff** Bold 700 for the wordmark only. Roboto is the Android default, so Android looks unchanged and iOS gets the same typeface instead of SF. Roboto covers Latin Extended (Serbian Latin) and Cyrillic in my understanding, but I have not checked it: verify after download. DynaPuff only has to render 'ZeroCart'. Licences: DynaPuff is OFL; Roboto's licence (Apache 2.0 in my recollection) must be confirmed from the downloaded files and credited on the licences page.

| Style | Font and weight | Size / line (sp) | Use |
| --- | --- | --- | --- |
| wordmark | DynaPuff Bold | 28 / 32 | Home app bar |
| storeCount | Roboto Bold | 52 / 52 | Items-left number on Home store cards |
| displaySmall | Roboto Bold | 24 / 30 | Empty-state headlines |
| headlineSmall | Roboto Medium | 24 / 32 | Large screen titles |
| titleLarge | Roboto Medium | 20 / 28 | App bar and sheet titles, store card names (Bold) |
| titleMedium | Roboto Medium | 16 / 24 | Section headers, card titles |
| bodyLarge | Roboto Medium | 16 / 24 | Item titles, inputs |
| bodyMedium | Roboto Regular | 14 / 20 | Descriptions, secondary text |
| labelLarge | Roboto Medium | 14 / 20 | Buttons |
| labelMedium | Roboto Medium | 12 / 16 | Chips, badges, nav labels |

Purchased item titles switch to Regular with a strikethrough. All text honours the system text scale; nothing is clamped except navigation bar labels, which may cap at 1.3x.

### 3.3 Spacing and layout

Base unit 4dp; scale 4, 8, 12, 16, 24, 32, 48. Screen side padding 16. List row: minimum height 56, vertical padding 12, gap between checkbox and text 12. Every tappable target is at least 48 x 48dp. Rows never use fixed heights.

### 3.4 Shapes

Corner radii: 8 (inputs, small chips), 16 (cards, FAB), 24 (bottom sheet top corners), 28 (dialogs), full pill (chips, badges). Checkbox corners 6. Rows are separated by 1dp ruled lines in outlineVariant, the main notebook motif; list screens may show a faint left margin line in primaryContainer.

### 3.5 Elevation

Material 3 tonal surfaces, not shadows. Cards are filled (surfaceContainer) with no shadow. FAB uses the default M3 elevation. A dragged row lifts to elevation 6 with a 1.02 scale. Sheets and dialogs use surfaceContainerHigh.

### 3.6 Icons

Built-in Material icons, rounded variants, 24dp, no extra icon package. Icons that carry meaning have a text label or a semantic label.

### 3.7 Components

- **NavigationBar** with three destinations; Inbox shows a badge. **FAB** (coral) for Quick add on tab screens.
- **Filled card** for stores and lists; custom row for items (checkbox, content, handle).
- **Checkbox** M3 with rounded corners; checked fill is primary with a white check.
- **Bottom sheets** with a drag handle, scroll-safe, padded by keyboard insets; used for all forms. **AlertDialog** only for store archive with active lists and replace-all restore.
- **ChoiceChip** for store selection and colour swatches; **SegmentedButton** for the theme and the Archive segments.
- **Floating SnackBar** with an action for Undo and Open, above the bottom bar.
- Buttons: FilledButton for the main action, TextButton for secondary, no outlined buttons unless needed.

### 3.8 Component states and motion

States follow M3 state layers (hover, focus, pressed, disabled at 38% opacity). Focus rings are visible for keyboard and switch access. Purchased rows: muted colour, strikethrough, checked box; never colour alone.

| Motion | Duration | Notes |
| --- | --- | --- |
| Check toggle and chip select | 150 ms | Emphasised easing |
| Row removal collapse | 200 ms | Fade and size |
| Purchased section expand and collapse | 250 ms | Chevron rotates |
| Sheets and dialogs | 250 ms | Platform defaults |

When the system asks to reduce motion (`MediaQuery.disableAnimations`), transitions become instant or simple fades.

### 3.9 Accessibility

- Text 4.5:1 and non-text UI 3:1 against its background in both themes; verify with a checker, including dark store tints.
- Dynamic type to at least 200% without clipped titles, overlapping rows or unreachable buttons; test it explicitly, in both English and Serbian.
- Screen readers: each item row announces title, description, and state ('Milk, 2L lactose-free, not purchased'); the checkbox has its own label. Custom accessibility actions: Move up, Move down, Remove. Removal and Undo are announced through the snackbar live region.
- Every gesture has a non-gesture path (D-22). Back navigation always works, including closing sheets.
- Colour never carries meaning alone (D-23). Haptics are light and optional (check, drag start).

### 3.10 Light and dark behaviour

The app follows the system by default and the user can force Light or Dark (SE-1). Two complete `ColorScheme`s drive all component themes. Status bar and navigation bar icon brightness follow the active theme, and the native launch screen uses the matching background colour.

### 3.11 Branding

The wordmark is the text 'ZeroCart' in DynaPuff Bold, primary colour, with a small coral dot. The idea behind the name is getting the cart to zero. App label: ZeroCart. Repository: zero-cart. Dart package: zero\_cart.

### 3.12 Home screen: store cards

Home has no list shortcuts. It is a staggered two-column board of large store cards, one per active store (the prototype shows it):

- **Fill:** the store colour mixed about 38% into the background, a solid store-colour circle clipped at the top-right corner, corner radius 28.
- **Content:** the number of unpurchased items across the store's active lists in storeCount style with the label 'left to buy'; store name in Bold 20sp; a thin progress bar (purchased share of all items); the list count. At zero the label reads 'cart is empty' (the idea of the name); a store without lists reads 'no lists yet'.
- **Layout:** the right column sits 26dp lower; every third card is taller (230dp against a 170dp minimum); cards tilt about 1 degree, alternating. Above 1.3x text scale the board becomes one column with no tilt.
- **Behaviour:** tapping a card opens store details, where the lists live. Order: most recently active store first. Accessibility label: store name, items left, list count.
- **Alternatives considered:** a horizontal swipe deck of big cards, and single-column full-width cards. Both are easy to swap in later since only the Home screen changes.
