# Backup format

Version 1 of the ZeroCart JSON backup. Decision record: ADR-0005. Data model: `docs/data-model.md`. Operations: data model 3.5, operations 11 and 12.

## 1. File

- UTF-8 JSON without BOM, one object. Suggested name `zero-cart-backup-YYYYMMDD-HHmm.json`. MIME type `application/json`. No device paths, no derived data.
- Maximum accepted size: 20 MB.
- Key order and row order are stable so exports are diffable: collections sorted by `createdAt` then `id`; items by list, then `position`, then `createdAt`, then `id`.

## 2. Structure

```json
{
  "format": "zero-cart-backup",
  "schemaVersion": 1,
  "appVersion": "0.1.0",
  "exportedAt": "2026-11-09T12:00:00.000Z",
  "data": {
    "settings": { "themeMode": "system" },
    "stores": [
      { "id": "s-1", "name": "Lidl", "colorKey": "lime", "address": "Main Street 12", "note": null,
        "archivedAt": null, "createdAt": "2026-11-01T08:00:00.000Z", "updatedAt": "2026-11-01T08:00:00.000Z" }
    ],
    "lists": [
      { "id": "l-1", "storeId": "s-1", "name": "Weekend groceries", "archivedAt": null, "archiveReason": null,
        "createdAt": "2026-11-01T08:05:00.000Z", "updatedAt": "2026-11-02T09:00:00.000Z" }
    ],
    "items": [
      { "id": "i-1", "listId": "l-1", "title": "Milk", "description": "2L, lactose-free", "isPurchased": false,
        "position": 1, "createdAt": "2026-11-01T08:06:00.000Z", "updatedAt": "2026-11-01T08:06:00.000Z" }
    ],
    "inboxItems": [
      { "id": "x-1", "title": "Dishwasher tablets", "description": null,
        "createdAt": "2026-11-03T18:00:00.000Z", "updatedAt": "2026-11-03T18:00:00.000Z" }
    ],
    "wishlistItems": [
      { "id": "w-1", "storeId": "s-2", "title": "Electric toothbrush heads", "description": null,
        "createdAt": "2026-11-04T10:00:00.000Z", "updatedAt": "2026-11-04T10:00:00.000Z" }
    ]
  }
}
```
All keys are always present; absent values are explicit `null`. Timestamps are ISO-8601 UTC with milliseconds and a trailing `Z`. Real exports use UUID v4 ids.

## 3. Field rules (validation)

| Rule | Detail |
|---|---|
| Top level | `format` equals `zero-cart-backup`; `schemaVersion` is an integer; `data` is an object containing the five collections as arrays |
| Ids | non-empty string, at most 64 characters, unique within their collection |
| Store | `name` trimmed length 1 to 40; `colorKey` one of tomato, tangerine, lemon, lime, teal, sky, grape, bubblegum; `address` and `note` string or null |
| List | `storeId` references an existing store; `name` 1 to 60; `archiveReason` is `manual`, `finished` or null; `archivedAt` and `archiveReason` are both null or both set |
| Item | `listId` references an existing list; `title` 1 to 50; `description` null or 1 to 70; `isPurchased` boolean; `position` integer at least 1 |
| Inbox item | `title` 1 to 50; `description` null or 1 to 70 |
| Wishlist item | `storeId` references an existing store; `title` 1 to 50; `description` null or 1 to 70 |
| Settings | `themeMode` is `system`, `light` or `dark`; a missing `settings` object means defaults |
| Timestamps | parse as ISO-8601; `updatedAt` is not required to follow `createdAt` |
| Extra fields | unknown extra fields inside rows are ignored for the same `schemaVersion` |
| Positions | duplicates tolerated (ties are legal, ADR-0004); restore keeps them as given |

## 4. Versioning

- `schemaVersion` is the backup version, independent of the database version.
- A file with a higher version than the app supports is rejected as incompatible. A lower version is upgraded in memory through an explicit stepwise chain (`vN -> vN+1`), then validated as the current version. The chain is empty for version 1 but the mechanism exists from APP-022.
- Any change that adds, removes or reinterprets a field bumps `schemaVersion`, adds an upgrader and a fixture for the previous version, and updates this document.

## 5. Errors

| Error | When | User-facing message idea |
|---|---|---|
| `tooLarge` | file over 20 MB | 'This file is too large to be a ZeroCart backup' |
| `notJson` / `corrupt` | not UTF-8, not JSON, or truncated | 'This file is damaged or is not a backup' |
| `wrongFormat` | `format` missing or different | 'This is not a ZeroCart backup' |
| `incompatibleVersion` | `schemaVersion` newer than supported | 'Made by a newer version of ZeroCart. Update the app first' |
| `invalid(path, reason)` | any rule in section 3 fails | 'The backup contains invalid data (<where>)' |

## 6. Restore behaviour (replace-all)

1. Read the file and run all checks above in memory. Any failure: stop; the database is not touched.
2. The user confirms in a dialog stating that all current data will be replaced; the dialog offers 'Export current data first'.
3. One transaction: delete all rows (children first), insert parents before children, verify inserted counts match the file, write settings. Any exception rolls the transaction back and leaves the previous data intact.
4. On success navigate to Home; reactive queries refresh the UI.
Restore is never a merge in v1.

## 7. Portability

The format uses no platform paths and no binary data; backups made on Android restore on iOS and the reverse. Test with a file made on the other platform when both are available (APP-023).

## 8. Tests required

Fixture-exact export of a sample database; one fixture per error class in section 5 and per rule in section 3; round-trip equality; rollback test with an injected failing insert; upgrader tests when versions are added.
