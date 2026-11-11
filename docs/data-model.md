# Data model

## 3.1 Conventions

Ids are UUID v4 text generated in the app. Timestamps are UTC (`created_at`, `updated_at` on every entity; backups serialise ISO-8601 UTC). **Drift storage (APP-006):** `DateTime` columns are stored as ISO-8601 text (`store_date_time_values_as_text: true` in `build.yaml`), not as Unix-second integers, so UTC-ness is preserved and the on-disk values stay close to the backup format. Enumerations are text with CHECK constraints. Empty descriptions are stored as NULL. Foreign keys are enforced.

## 3.2 Tables

**stores**: `id` TEXT PK; `name` TEXT NOT NULL, CHECK trimmed length 1..40; `color_key` TEXT NOT NULL (one of eight palette keys: tomato, tangerine, lemon, lime, teal, sky, grape, bubblegum; validated in app and on restore); `address` TEXT NULL; `note` TEXT NULL; `archived_at` NULL; `created_at`; `updated_at`. Index on `archived_at`. Default colour for a new store: first palette key not used by an active store; if every key is used, cycle with `palette[activeCount % 8]` (not a fixed sky fallback).

**shopping\_lists**: `id` PK; `store_id` FK to stores, ON DELETE CASCADE, NOT NULL; `name` CHECK 1..60; `archived_at` NULL; `archive_reason` TEXT NULL CHECK IN ('manual','finished'); CHECK `(archived_at IS NULL) = (archive_reason IS NULL)`; `created_at`; `updated_at` (touched on add, assign, copy and carry-forward, not on check toggles; used to preselect the most recent list). Index `(store_id, archived_at)`.

**list\_items**: `id` PK; `list_id` FK to shopping\_lists, ON DELETE CASCADE; `title` CHECK 1..50; `description` NULL (max 70); `is_purchased` BOOL default false; `position` INTEGER NOT NULL; `created_at`; `updated_at`. Index `(list_id, position)`. **No unique constraint on position**: an undo can legally recreate a tie, resolved by ordering on `(position, created_at, id)`; dense renumbering on reorder removes ties.

**inbox\_items**: `id` PK; `title`; `description`; `created_at`; `updated_at`. Index `created_at`.

**wishlist\_items**: `id` PK; `store_id` FK to stores, ON DELETE CASCADE; `title`; `description`; `created_at`; `updated_at`. Index `(store_id, created_at)`. A store has exactly one wishlist, so there is no wishlists table.

**app\_settings**: `key` TEXT PK; `value` TEXT NOT NULL. v1 key: `theme_mode` in (system, light, dark), absent means system.

Cascades exist for integrity and for restore; no UI path deletes a store or list in v1 (D-10).

## 3.3 Separate tables vs one shared items table

Separate tables. The three item kinds have different parents (none, store, list) and different columns (purchased state and position exist only on list items). A single table with a container discriminator would need a polymorphic parent, which gives up real foreign keys, and every query would filter on the discriminator. The duplicated columns (title, description, timestamps) are cheap, and a Drift column mixin can share the declarations. Independence of copies falls out for free.

## 3.4 Invariants

- **I1** Every list item has an existing list; every list has an existing store (foreign keys).
- **I2** `archived_at` and `archive_reason` are both set or both null.
- **I3** Add, assign, copy and carry-forward targets must be an active list in a non-archived store, checked inside the same transaction as the write.
- **I4** Titles and names are non-empty after trimming.
- **I5** Reorder never changes the relative order of purchased items.
- **I6** An inbox item is deleted if and only if its copy was inserted (same transaction).
- **I7** Wishlist rows are never modified by copying.

## 3.5 Operations (pseudocode, transaction boundaries marked TX)

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

## 3.6 Migrations

Drift `schemaVersion` starts at 1 and uses stepwise migrations. Every PR that changes a table must bump the version, add the migration, commit the updated snapshot in `drift_schemas/`, and add a migration test generated with Drift's schema tooling. Destructive migrations are not allowed without a documented data-preservation step. The backup `schemaVersion` is independent of the database version; its upgraders are specified in `docs/backup-format.md`.

## 3.7 Example data

| table | rows |
| --- | --- |
| stores | Lidl (lime), DM (sky) |
| shopping\_lists | 'Weekend groceries' (Lidl, active), 'Party' (Lidl, active), 'Next week' (Lidl, active), 'Drugstore run' (DM, active), 'Easter' (Lidl, archived, finished) |
| list\_items (Weekend groceries) | Milk / 2L, lactose-free (pos 1, active); Pasta / Whole wheat, 500g (pos 2, purchased); Bread (pos 3, active) |
| inbox\_items | Dishwasher tablets; Lightbulb / E27 warm white |
| wishlist\_items (DM) | Electric toothbrush heads |

Share text of 'Weekend groceries' is three lines: `Weekend groceries`, `Milk - 2L, lactose-free`, `Bread`. Pasta is excluded because it is purchased.
