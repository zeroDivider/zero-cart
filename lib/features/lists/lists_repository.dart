import 'package:drift/drift.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/core/text_normalize.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/active_list_progress.dart';
import 'package:zero_cart/features/lists/list_exceptions.dart';

/// List lifecycle operations (LI-1, LI-2, LI-5; item ops come in APP-012).
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
}
