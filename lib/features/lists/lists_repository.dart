import 'package:drift/drift.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/core/ordering.dart';
import 'package:zero_cart/core/text_normalize.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/active_list_progress.dart';
import 'package:zero_cart/features/lists/list_exceptions.dart';

/// List lifecycle and item operations (LI-1, LI-2, LI-5; IT-1 to IT-4, IT-7).
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
}
