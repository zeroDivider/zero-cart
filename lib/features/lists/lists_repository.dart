import 'package:drift/drift.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/core/ordering.dart';
import 'package:zero_cart/core/text_normalize.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/active_list_progress.dart';
import 'package:zero_cart/features/lists/archived_list_with_store.dart';
import 'package:zero_cart/features/lists/assign_inbox_target.dart';
import 'package:zero_cart/features/lists/copy_wishlist_target.dart';
import 'package:zero_cart/features/lists/finish_list_result.dart';
import 'package:zero_cart/features/lists/list_exceptions.dart';
import 'package:zero_cart/features/stores/store_draft.dart';

/// List lifecycle and item operations (LI-1, LI-2, LI-5; IT-1 to IT-7).
class ListsRepository {
  ListsRepository({
    required AppDatabase database,
    required Clock now,
    required IdGenerator newId,
  }) : _db = database,
       _clock = now,
       _idGenerator = newId;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _idGenerator;

  static const String archiveReasonManual = 'manual';
  static const String archiveReasonFinished = 'finished';

  /// Active lists for [storeId] with left/total item counts (live).
  ///
  /// Ordered by creation (`created_at`, `id`) to match the prototype.
  Stream<List<ActiveListProgress>> watchActiveForStore(String storeId) {
    return _db
        .customSelect(
          '''
SELECT
  sl.id,
  sl.store_id,
  sl.name,
  sl.archived_at,
  sl.archive_reason,
  sl.created_at,
  sl.updated_at,
  (
    SELECT COUNT(*) FROM list_items AS li
    WHERE li.list_id = sl.id AND li.is_purchased = 0
  ) AS items_left,
  (
    SELECT COUNT(*) FROM list_items AS li
    WHERE li.list_id = sl.id
  ) AS items_total
FROM shopping_lists AS sl
WHERE sl.store_id = ? AND sl.archived_at IS NULL
ORDER BY sl.created_at ASC, sl.id ASC
''',
          variables: [Variable.withString(storeId)],
          readsFrom: {_db.shoppingLists, _db.listItems},
        )
        .watch()
        .map((rows) {
          return [
            for (final row in rows)
              ActiveListProgress(
                list: ShoppingList(
                  id: row.read<String>('id'),
                  storeId: row.read<String>('store_id'),
                  name: row.read<String>('name'),
                  archivedAt: row.readNullable<DateTime>('archived_at'),
                  archiveReason: row.readNullable<String>('archive_reason'),
                  createdAt: row.read<DateTime>('created_at'),
                  updatedAt: row.read<DateTime>('updated_at'),
                ),
                itemsLeft: row.read<int>('items_left'),
                itemsTotal: row.read<int>('items_total'),
              ),
          ];
        });
  }

  /// Single list by id, or null if missing.
  Stream<ShoppingList?> watchById(String id) {
    return (_db.select(_db.shoppingLists)..where((t) => t.id.equals(id)))
        .watch()
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Active lists across all stores, most recently updated first (D-16).
  Stream<List<ShoppingList>> watchActiveByRecency() {
    return (_db.select(_db.shoppingLists)
          ..where((t) => t.archivedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// Finished lists for [storeId] (Past trips), newest [ShoppingList.updatedAt] first.
  Stream<List<ShoppingList>> watchFinishedListsForStore(String storeId) {
    return (_db.select(_db.shoppingLists)
          ..where(
            (t) =>
                t.storeId.equals(storeId) &
                t.archivedAt.isNotNull() &
                t.archiveReason.equals(archiveReasonFinished),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.updatedAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// Live count of finished lists for [storeId] (Past trips card).
  Stream<int> watchFinishedCountForStore(String storeId) {
    return watchFinishedListsForStore(storeId).map((rows) => rows.length);
  }

  /// Manually archived lists joined with store name, colour and archive flag.
  ///
  /// Ordered by store name (case-insensitive), then list [ShoppingList.updatedAt]
  /// descending within each store. Finished lists are excluded (Archive Lists).
  Stream<List<ArchivedListWithStore>> watchManualArchivedLists() {
    return _db
        .customSelect(
          '''
SELECT
  sl.id,
  sl.store_id,
  sl.name,
  sl.archived_at,
  sl.archive_reason,
  sl.created_at,
  sl.updated_at,
  s.name AS store_name,
  s.color_key AS store_color_key,
  s.archived_at AS store_archived_at
FROM shopping_lists AS sl
INNER JOIN stores AS s ON s.id = sl.store_id
WHERE sl.archived_at IS NOT NULL AND sl.archive_reason = ?
ORDER BY s.name COLLATE NOCASE ASC, s.id ASC, sl.updated_at DESC, sl.id DESC
''',
          variables: [Variable.withString(archiveReasonManual)],
          readsFrom: {_db.shoppingLists, _db.stores},
        )
        .watch()
        .map((rows) {
          return [
            for (final row in rows)
              ArchivedListWithStore(
                list: ShoppingList(
                  id: row.read<String>('id'),
                  storeId: row.read<String>('store_id'),
                  name: row.read<String>('name'),
                  archivedAt: row.readNullable<DateTime>('archived_at'),
                  archiveReason: row.readNullable<String>('archive_reason'),
                  createdAt: row.read<DateTime>('created_at'),
                  updatedAt: row.read<DateTime>('updated_at'),
                ),
                storeName: row.read<String>('store_name'),
                storeColorKey: row.read<String>('store_color_key'),
                storeArchivedAt: row.readNullable<DateTime>(
                  'store_archived_at',
                ),
              ),
          ];
        });
  }

  /// Creates an empty active list. Rejects archived or missing stores.
  Future<ShoppingList> create({required String storeId, required String name}) {
    return _db.transaction(() async {
      final store = await (_db.select(
        _db.stores,
      )..where((t) => t.id.equals(storeId))).getSingleOrNull();
      if (store == null) {
        throw StateError('Store $storeId not found');
      }
      if (store.archivedAt != null) {
        throw StoreArchivedException(storeId);
      }

      final normalizedName = normalizeListName(name);
      if (normalizedName.isEmpty) {
        throw ArgumentError.value(name, 'name', 'must not be empty');
      }

      final now = _clock();
      final id = _idGenerator();
      await _db
          .into(_db.shoppingLists)
          .insert(
            ShoppingListsCompanion.insert(
              id: id,
              storeId: storeId,
              name: normalizedName,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return ShoppingList(
        id: id,
        storeId: storeId,
        name: normalizedName,
        archivedAt: null,
        archiveReason: null,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  /// Renames an active list (LI-2). Rejects archived lists (D-13).
  Future<ShoppingList> rename({
    required String id,
    required String name,
  }) async {
    final normalizedName = normalizeListName(name);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final existing = await (_db.select(
      _db.shoppingLists,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('List $id not found');
    }
    if (existing.archivedAt != null) {
      throw ListArchivedException(id);
    }
    final now = _clock();
    final updated = existing.copyWith(name: normalizedName, updatedAt: now);
    await _db.update(_db.shoppingLists).replace(updated);
    return updated;
  }

  /// Archives an active list with reason `manual` (LI-3 foundation).
  Future<void> archive(String id) async {
    final existing = await (_db.select(
      _db.shoppingLists,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('List $id not found');
    }
    if (existing.archivedAt != null) {
      return;
    }
    final now = _clock();
    await (_db.update(_db.shoppingLists)..where((t) => t.id.equals(id))).write(
      ShoppingListsCompanion(
        archivedAt: Value(now),
        archiveReason: const Value(archiveReasonManual),
        updatedAt: Value(now),
      ),
    );
  }

  /// Finishes an active list (ops 8–9, D-10 to D-13).
  ///
  /// Archives with reason `finished`. When [carryForward] is true and there are
  /// unpurchased leftovers, creates a new list in the same store (I3: store must
  /// not be archived) and copies leftovers with new ids and positions 1..n.
  /// [newName] is normalised via [_insertNewList]; the UI builds any default
  /// "Leftovers: …" label. One transaction: failure leaves the list active.
  Future<FinishListResult> finishList(
    String listId, {
    required bool carryForward,
    String? newName,
  }) {
    return _db.transaction(() async {
      final list = await (_db.select(
        _db.shoppingLists,
      )..where((t) => t.id.equals(listId))).getSingleOrNull();
      if (list == null) {
        throw StateError('List $listId not found');
      }
      if (list.archivedAt != null) {
        throw ListArchivedException(listId);
      }

      final left =
          await (_db.select(_db.listItems)
                ..where(
                  (t) => t.listId.equals(listId) & t.isPurchased.equals(false),
                )
                ..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();

      final willCarry = carryForward && left.isNotEmpty;
      if (willCarry) {
        final store = await (_db.select(
          _db.stores,
        )..where((t) => t.id.equals(list.storeId))).getSingleOrNull();
        if (store == null) {
          throw StateError('Store ${list.storeId} not found');
        }
        if (store.archivedAt != null) {
          throw StoreArchivedException(list.storeId);
        }
      }

      final now = _clock();
      await (_db.update(
        _db.shoppingLists,
      )..where((t) => t.id.equals(listId))).write(
        ShoppingListsCompanion(
          archivedAt: Value(now),
          archiveReason: const Value(archiveReasonFinished),
          updatedAt: Value(now),
        ),
      );

      String? newListId;
      var carried = 0;
      if (willCarry) {
        final created = await _insertNewList(list.storeId, newName ?? '');
        newListId = created.id;
        var pos = 1;
        for (final item in left) {
          await _db
              .into(_db.listItems)
              .insert(
                ListItemsCompanion.insert(
                  id: _idGenerator(),
                  listId: created.id,
                  title: item.title,
                  description: Value(item.description),
                  isPurchased: const Value(false),
                  position: pos,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          pos += 1;
          carried += 1;
        }
      }

      return FinishListResult(
        archivedListId: listId,
        newListId: newListId,
        carriedCount: carried,
      );
    });
  }

  /// Restores an archived list. Fails with [StoreArchivedException] if the
  /// parent store is archived (LI-5).
  Future<void> restore(String id) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.shoppingLists,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('List $id not found');
      }
      if (existing.archivedAt == null) {
        return;
      }
      final store = await (_db.select(
        _db.stores,
      )..where((t) => t.id.equals(existing.storeId))).getSingleOrNull();
      if (store == null) {
        throw StateError('Store ${existing.storeId} not found');
      }
      if (store.archivedAt != null) {
        throw StoreArchivedException(store.id);
      }
      final now = _clock();
      await (_db.update(
        _db.shoppingLists,
      )..where((t) => t.id.equals(id))).write(
        ShoppingListsCompanion(
          archivedAt: const Value(null),
          archiveReason: const Value(null),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Items for [listId] ordered by `(position, created_at, id)` (ADR-0004).
  Stream<List<ListItem>> watchItems(String listId) {
    return (_db.select(_db.listItems)
          ..where((t) => t.listId.equals(listId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// Appends an active item at max(position)+1 and touches the list (D-04).
  ///
  /// Rejects archived lists inside the transaction (D-13).
  Future<ListItem> addItem({
    required String listId,
    required String title,
    String? description,
  }) {
    final normalizedTitle = normalizeTitle(title);
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    final normalizedDescription = normalizeDescription(description);

    return _db.transaction(() async {
      final list = await (_db.select(
        _db.shoppingLists,
      )..where((t) => t.id.equals(listId))).getSingleOrNull();
      if (list == null) {
        throw StateError('List $listId not found');
      }
      if (list.archivedAt != null) {
        throw ListArchivedException(listId);
      }

      final maxRow = await _db
          .customSelect(
            'SELECT MAX(position) AS max_pos FROM list_items WHERE list_id = ?',
            variables: [Variable.withString(listId)],
            readsFrom: {_db.listItems},
          )
          .getSingle();
      final maxPos = maxRow.readNullable<int>('max_pos') ?? 0;
      final position = maxPos + 1;

      final now = _clock();
      final id = _idGenerator();
      await _db
          .into(_db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: id,
              listId: listId,
              title: normalizedTitle,
              description: Value(normalizedDescription),
              isPurchased: const Value(false),
              position: position,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await (_db.update(_db.shoppingLists)..where((t) => t.id.equals(listId)))
          .write(ShoppingListsCompanion(updatedAt: Value(now)));

      return ListItem(
        id: id,
        listId: listId,
        title: normalizedTitle,
        description: normalizedDescription,
        isPurchased: false,
        position: position,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  /// Hard-deletes the item and returns a snapshot for Undo (D-07, op 1).
  ///
  /// Rejects archived lists (owner: archived lists are immutable except restore).
  Future<ListItem> removeItem(String id) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.listItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('List item $id not found');
      }
      await _assertListActive(existing.listId);
      await (_db.delete(_db.listItems)..where((t) => t.id.equals(id))).go();
      return existing;
    });
  }

  /// Re-inserts [snapshot] unchanged (same id, position, purchased, timestamps).
  ///
  /// Fails with [ListUnavailableException] if the list is missing or archived.
  Future<void> restoreItem(ListItem snapshot) {
    return _db.transaction(() async {
      final list = await (_db.select(
        _db.shoppingLists,
      )..where((t) => t.id.equals(snapshot.listId))).getSingleOrNull();
      if (list == null || list.archivedAt != null) {
        throw ListUnavailableException(snapshot.listId);
      }
      await _db.into(_db.listItems).insert(snapshot);
    });
  }

  /// Updates title/description; position and purchased state unchanged (IT-4).
  ///
  /// Rejects archived lists (D-13).
  Future<ListItem> updateItem({
    required String id,
    required String title,
    String? description,
  }) {
    final normalizedTitle = normalizeTitle(title);
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    final normalizedDescription = normalizeDescription(description);

    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.listItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('List item $id not found');
      }
      await _assertListActive(existing.listId);

      final now = _clock();
      final updated = existing.copyWith(
        title: normalizedTitle,
        description: Value(normalizedDescription),
        updatedAt: now,
      );
      await _db.update(_db.listItems).replace(updated);
      return updated;
    });
  }

  /// Toggles purchased; [ListItem.position] is never changed (D-03).
  ///
  /// Rejects archived lists (D-13).
  Future<void> setPurchased(String id, bool isPurchased) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.listItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('List item $id not found');
      }
      await _assertListActive(existing.listId);
      if (existing.isPurchased == isPurchased) {
        return;
      }
      final now = _clock();
      await (_db.update(_db.listItems)..where((t) => t.id.equals(id))).write(
        ListItemsCompanion(
          isPurchased: Value(isPurchased),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Moves Inbox rows onto a list in one transaction (ops 5–6, D-17).
  ///
  /// Loads inbox rows oldest-first and aborts if any id is missing. Resolves
  /// or creates the store (rejects archived), then the list (existing must be
  /// active and in that store). Appends items at max+1 in creation order,
  /// touches the list, and deletes the inbox rows. Any failure rolls back.
  Future<AssignInboxResult> assignInbox(
    List<String> inboxIds,
    AssignInboxTarget target,
  ) {
    if (inboxIds.isEmpty) {
      throw ArgumentError.value(inboxIds, 'inboxIds', 'must not be empty');
    }
    return _db.transaction(() async {
      final inboxRows =
          await (_db.select(_db.inboxItems)
                ..where((t) => t.id.isIn(inboxIds))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      if (inboxRows.length != inboxIds.toSet().length) {
        throw StateError('One or more inbox items were not found');
      }

      final storeId = await _resolveAssignStore(target.store);
      final list = await _resolveAssignList(storeId, target.list);

      final maxRow = await _db
          .customSelect(
            'SELECT MAX(position) AS max_pos FROM list_items WHERE list_id = ?',
            variables: [Variable.withString(list.id)],
            readsFrom: {_db.listItems},
          )
          .getSingle();
      var nextPosition = (maxRow.readNullable<int>('max_pos') ?? 0) + 1;
      final now = _clock();

      for (final inbox in inboxRows) {
        await _db
            .into(_db.listItems)
            .insert(
              ListItemsCompanion.insert(
                id: _idGenerator(),
                listId: list.id,
                title: inbox.title,
                description: Value(inbox.description),
                isPurchased: const Value(false),
                position: nextPosition,
                createdAt: now,
                updatedAt: now,
              ),
            );
        nextPosition += 1;
      }

      await (_db.update(_db.shoppingLists)..where((t) => t.id.equals(list.id)))
          .write(ShoppingListsCompanion(updatedAt: Value(now)));

      await (_db.delete(
        _db.inboxItems,
      )..where((t) => t.id.isIn(inboxIds))).go();

      return AssignInboxResult(listId: list.id, listName: list.name);
    });
  }

  /// Copies wishlist rows into an active list of the same store (op 7, D-18).
  ///
  /// One transaction: resolve/create the list, insert copies at max+1 with new
  /// ids (oldest wishlist first), touch `updated_at`. Wishlist rows are never
  /// modified (I7). Rejects empty [wishlistIds], missing ids, mixed stores,
  /// archived targets, and archived stores (I3).
  Future<CopyWishlistResult> copyWishlistItems(
    List<String> wishlistIds,
    CopyWishlistTarget target,
  ) {
    if (wishlistIds.isEmpty) {
      throw ArgumentError.value(
        wishlistIds,
        'wishlistIds',
        'must not be empty',
      );
    }
    return _db.transaction(() async {
      final wishlistRows =
          await (_db.select(_db.wishlistItems)
                ..where((t) => t.id.isIn(wishlistIds))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      if (wishlistRows.isEmpty ||
          wishlistRows.length != wishlistIds.toSet().length) {
        throw const InvalidWishlistCopyException();
      }

      final storeId = wishlistRows.first.storeId;
      for (final row in wishlistRows) {
        if (row.storeId != storeId) {
          throw const InvalidWishlistCopyException();
        }
      }

      final store = await (_db.select(
        _db.stores,
      )..where((t) => t.id.equals(storeId))).getSingleOrNull();
      if (store == null) {
        throw const InvalidWishlistCopyException();
      }
      if (store.archivedAt != null) {
        throw StoreArchivedException(storeId);
      }

      final list = await _resolveCopyWishlistList(storeId, target);

      final maxRow = await _db
          .customSelect(
            'SELECT MAX(position) AS max_pos FROM list_items WHERE list_id = ?',
            variables: [Variable.withString(list.id)],
            readsFrom: {_db.listItems},
          )
          .getSingle();
      var nextPosition = (maxRow.readNullable<int>('max_pos') ?? 0) + 1;
      final now = _clock();

      for (final wish in wishlistRows) {
        await _db
            .into(_db.listItems)
            .insert(
              ListItemsCompanion.insert(
                id: _idGenerator(),
                listId: list.id,
                title: wish.title,
                description: Value(wish.description),
                isPurchased: const Value(false),
                position: nextPosition,
                createdAt: now,
                updatedAt: now,
              ),
            );
        nextPosition += 1;
      }

      await (_db.update(_db.shoppingLists)..where((t) => t.id.equals(list.id)))
          .write(ShoppingListsCompanion(updatedAt: Value(now)));

      return CopyWishlistResult(listId: list.id, listName: list.name);
    });
  }

  /// Dense-renumbers active items into existing active slots (D-06, op 4).
  ///
  /// Aborts with [StaleOrderException] when [orderedActiveIds] does not match
  /// the current active set. Rejects archived lists (D-13). Purchased rows keep
  /// their slot indices; only changed positions are written.
  Future<void> reorderActive(String listId, List<String> orderedActiveIds) {
    return _db.transaction(() async {
      await _assertListActive(listId);
      final all =
          await (_db.select(_db.listItems)
                ..where((t) => t.listId.equals(listId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      final changes = computeDenseReorder([
        for (final item in all)
          OrderableItem(
            id: item.id,
            position: item.position,
            isPurchased: item.isPurchased,
          ),
      ], orderedActiveIds);
      for (final entry in changes.entries) {
        await (_db.update(_db.listItems)..where((t) => t.id.equals(entry.key)))
            .write(ListItemsCompanion(position: Value(entry.value)));
      }
    });
  }

  Future<void> _assertListActive(String listId) async {
    final list = await (_db.select(
      _db.shoppingLists,
    )..where((t) => t.id.equals(listId))).getSingleOrNull();
    if (list == null) {
      throw StateError('List $listId not found');
    }
    if (list.archivedAt != null) {
      throw ListArchivedException(listId);
    }
  }

  Future<String> _resolveAssignStore(AssignStoreTarget target) async {
    switch (target) {
      case ExistingStore(:final id):
        final store = await (_db.select(
          _db.stores,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (store == null) {
          throw StateError('Store $id not found');
        }
        if (store.archivedAt != null) {
          throw StoreArchivedException(id);
        }
        return store.id;
      case NewStore(:final draft):
        return _insertStoreFromDraft(draft);
    }
  }

  Future<ShoppingList> _resolveAssignList(
    String storeId,
    AssignListTarget target,
  ) async {
    switch (target) {
      case ExistingList(:final listId):
        final list = await (_db.select(
          _db.shoppingLists,
        )..where((t) => t.id.equals(listId))).getSingleOrNull();
        if (list == null) {
          throw StateError('List $listId not found');
        }
        if (list.archivedAt != null) {
          throw ListArchivedException(listId);
        }
        if (list.storeId != storeId) {
          throw StateError('List $listId does not belong to store $storeId');
        }
        return list;
      case NewList(:final name):
        return _insertNewList(storeId, name);
    }
  }

  /// Resolves the copy target; invalid existing lists map to
  /// [InvalidWishlistCopyException] (generic UI message for F13).
  Future<ShoppingList> _resolveCopyWishlistList(
    String storeId,
    CopyWishlistTarget target,
  ) async {
    switch (target) {
      case ExistingList(:final listId):
        final list = await (_db.select(
          _db.shoppingLists,
        )..where((t) => t.id.equals(listId))).getSingleOrNull();
        // Must be an active list in the wishlist's store (op 7).
        if (list == null ||
            list.archivedAt != null ||
            list.storeId != storeId) {
          throw const InvalidWishlistCopyException();
        }
        return list;
      case NewList(:final name):
        return _insertNewList(storeId, name);
    }
  }

  Future<ShoppingList> _insertNewList(String storeId, String name) async {
    final normalizedName = normalizeListName(name);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    final now = _clock();
    final id = _idGenerator();
    await _db
        .into(_db.shoppingLists)
        .insert(
          ShoppingListsCompanion.insert(
            id: id,
            storeId: storeId,
            name: normalizedName,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return ShoppingList(
      id: id,
      storeId: storeId,
      name: normalizedName,
      archivedAt: null,
      archiveReason: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Inserts a store inside the assign transaction (same rules as StoresRepository).
  Future<String> _insertStoreFromDraft(StoreDraft draft) async {
    final normalizedName = normalizeStoreName(draft.name);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(draft.name, 'name', 'must not be empty');
    }
    if (!AppTokens.storePaletteKeys.contains(draft.colorKey)) {
      throw ArgumentError.value(
        draft.colorKey,
        'colorKey',
        'unknown palette key',
      );
    }
    final now = _clock();
    final id = _idGenerator();
    final address = _normalizeOptionalStoreLine(draft.address);
    final note = _normalizeOptionalStoreLine(draft.note);
    await _db
        .into(_db.stores)
        .insert(
          StoresCompanion.insert(
            id: id,
            name: normalizedName,
            colorKey: draft.colorKey,
            address: Value(address),
            note: Value(note),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  static String? _normalizeOptionalStoreLine(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}
