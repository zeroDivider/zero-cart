import 'package:drift/drift.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/core/text_normalize.dart';
import 'package:zero_cart/data/database.dart';

/// Per-store wishlist CRUD (D-18, WL-1).
class WishlistRepository {
  WishlistRepository({
    required AppDatabase database,
    required Clock now,
    required IdGenerator newId,
  }) : _db = database,
       _clock = now,
       _idGenerator = newId;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _idGenerator;

  /// Oldest first by creation (D-18); ties broken by id ascending.
  Stream<List<WishlistItem>> watch(String storeId) {
    return (_db.select(_db.wishlistItems)
          ..where((t) => t.storeId.equals(storeId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.createdAt),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// Live count for the store-details card (WL-1).
  Stream<int> watchCount(String storeId) {
    return watch(storeId).map((rows) => rows.length);
  }

  /// Inserts a normalized wishlist row. Rejects empty title and archived stores.
  Future<WishlistItem> add({
    required String storeId,
    required String title,
    String? description,
  }) {
    final normalizedTitle = normalizeTitle(title);
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    final normalizedDescription = normalizeDescription(description);

    return _db.transaction(() async {
      await _assertStoreWritable(storeId);
      final now = _clock();
      final id = _idGenerator();
      await _db
          .into(_db.wishlistItems)
          .insert(
            WishlistItemsCompanion.insert(
              id: id,
              storeId: storeId,
              title: normalizedTitle,
              description: Value(normalizedDescription),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return WishlistItem(
        id: id,
        storeId: storeId,
        title: normalizedTitle,
        description: normalizedDescription,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  /// Updates title/description; keeps [WishlistItem.createdAt] so order is stable.
  Future<WishlistItem> update({
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
        _db.wishlistItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Wishlist item $id not found');
      }
      await _assertStoreWritable(existing.storeId);
      final now = _clock();
      final updated = existing.copyWith(
        title: normalizedTitle,
        description: Value(normalizedDescription),
        updatedAt: now,
      );
      await _db.update(_db.wishlistItems).replace(updated);
      return updated;
    });
  }

  /// Hard-deletes the row and returns a snapshot for Undo (D-07, D-19).
  Future<WishlistItem> remove(String id) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.wishlistItems,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Wishlist item $id not found');
      }
      await _assertStoreWritable(existing.storeId);
      await (_db.delete(_db.wishlistItems)..where((t) => t.id.equals(id))).go();
      return existing;
    });
  }

  /// Re-inserts [snapshot] unchanged (same id and timestamps).
  Future<void> restore(WishlistItem snapshot) {
    return _db.transaction(() async {
      await _assertStoreWritable(snapshot.storeId);
      await _db.into(_db.wishlistItems).insert(snapshot);
    });
  }

  Future<void> _assertStoreWritable(String storeId) async {
    final store = await (_db.select(
      _db.stores,
    )..where((t) => t.id.equals(storeId))).getSingleOrNull();
    if (store == null) {
      throw StateError('Store $storeId not found');
    }
    if (store.archivedAt != null) {
      throw StoreArchivedException(storeId);
    }
  }
}
