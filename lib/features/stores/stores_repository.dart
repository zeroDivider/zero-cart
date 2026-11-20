import 'package:drift/drift.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/core/text_normalize.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/home/store_summary.dart';
import 'package:zero_cart/features/stores/active_store_summary.dart';
import 'package:zero_cart/features/stores/store_draft.dart';

/// Business rules and Drift access for stores (data model §3.2 / op 10).
class StoresRepository {
  StoresRepository({
    required AppDatabase database,
    required Clock now,
    required IdGenerator newId,
  }) : _db = database,
       _clock = now,
       _idGenerator = newId;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _idGenerator;

  /// Active stores, alphabetical case-insensitive (ST-2).
  Stream<List<Store>> watchActive() {
    return (_db.select(_db.stores)
          ..where((t) => t.archivedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.name.collate(Collate.noCase)),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// Active stores with a live active-list count (Stores tab).
  ///
  /// One query so a list insert, archive or restore re-emits the row the
  /// screen paints, including the count. Ordering matches [watchActive].
  Stream<List<ActiveStoreSummary>> watchActiveWithListCounts() {
    return _db
        .customSelect(
          '''
SELECT
  s.id,
  s.name,
  s.color_key,
  s.address,
  s.note,
  s.archived_at,
  s.created_at,
  s.updated_at,
  (
    SELECT COUNT(*) FROM shopping_lists AS sl
    WHERE sl.store_id = s.id AND sl.archived_at IS NULL
  ) AS active_list_count
FROM stores AS s
WHERE s.archived_at IS NULL
ORDER BY s.name COLLATE NOCASE ASC, s.id ASC
''',
          readsFrom: {_db.stores, _db.shoppingLists},
        )
        .watch()
        .map((rows) {
          return [
            for (final row in rows)
              ActiveStoreSummary(
                store: Store(
                  id: row.read<String>('id'),
                  name: row.read<String>('name'),
                  colorKey: row.read<String>('color_key'),
                  address: row.readNullable<String>('address'),
                  note: row.readNullable<String>('note'),
                  archivedAt: row.readNullable<DateTime>('archived_at'),
                  createdAt: row.read<DateTime>('created_at'),
                  updatedAt: row.read<DateTime>('updated_at'),
                ),
                activeListCount: row.read<int>('active_list_count'),
              ),
          ];
        });
  }

  /// Active stores for the Home board: list and item counts plus last activity.
  ///
  /// Counts cover **active** lists only. [StoreSummary.lastActivity] is the
  /// newest active-list `updated_at`, falling back to the store's own.
  /// Ordered newest activity first (ST-2 / design system 3.12). Item writes
  /// re-emit because [listItems] is in [readsFrom].
  Stream<List<StoreSummary>> watchHomeStoreSummaries() {
    return _db
        .customSelect(
          '''
SELECT
  s.id,
  s.name,
  s.color_key,
  s.address,
  s.note,
  s.archived_at,
  s.created_at,
  s.updated_at,
  (
    SELECT COUNT(*) FROM shopping_lists AS sl
    WHERE sl.store_id = s.id AND sl.archived_at IS NULL
  ) AS active_list_count,
  (
    SELECT COUNT(*) FROM list_items AS li
    INNER JOIN shopping_lists AS sl ON sl.id = li.list_id
    WHERE sl.store_id = s.id
      AND sl.archived_at IS NULL
      AND li.is_purchased = 0
  ) AS unpurchased_count,
  (
    SELECT COUNT(*) FROM list_items AS li
    INNER JOIN shopping_lists AS sl ON sl.id = li.list_id
    WHERE sl.store_id = s.id AND sl.archived_at IS NULL
  ) AS total_item_count,
  COALESCE(
    (
      SELECT MAX(sl.updated_at) FROM shopping_lists AS sl
      WHERE sl.store_id = s.id AND sl.archived_at IS NULL
    ),
    s.updated_at
  ) AS last_activity
FROM stores AS s
WHERE s.archived_at IS NULL
ORDER BY last_activity DESC, s.id DESC
''',
          readsFrom: {_db.stores, _db.shoppingLists, _db.listItems},
        )
        .watch()
        .map((rows) {
          return [
            for (final row in rows)
              StoreSummary(
                store: Store(
                  id: row.read<String>('id'),
                  name: row.read<String>('name'),
                  colorKey: row.read<String>('color_key'),
                  address: row.readNullable<String>('address'),
                  note: row.readNullable<String>('note'),
                  archivedAt: row.readNullable<DateTime>('archived_at'),
                  createdAt: row.read<DateTime>('created_at'),
                  updatedAt: row.read<DateTime>('updated_at'),
                ),
                activeListCount: row.read<int>('active_list_count'),
                unpurchasedCount: row.read<int>('unpurchased_count'),
                totalItemCount: row.read<int>('total_item_count'),
                lastActivity: row.read<DateTime>('last_activity'),
              ),
          ];
        });
  }

  /// Archived stores, alphabetical case-insensitive (Archive Stores segment).
  Stream<List<Store>> watchArchived() {
    return (_db.select(_db.stores)
          ..where((t) => t.archivedAt.isNotNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.name.collate(Collate.noCase)),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// Single store by id, or null if missing.
  Stream<Store?> watchById(String id) {
    return (_db.select(_db.stores)..where((t) => t.id.equals(id))).watch().map(
      (rows) => rows.isEmpty ? null : rows.first,
    );
  }

  /// Inserts a store from a draft (or field args). Rejects empty name / bad colour.
  Future<Store> create({
    required String name,
    required String colorKey,
    String? address,
    String? note,
  }) {
    return _insert(
      name: name,
      colorKey: colorKey,
      address: address,
      note: note,
    );
  }

  /// Convenience for [StoreDraft] callers (Stores tab, APP-015).
  Future<Store> createFromDraft(StoreDraft draft) {
    return create(
      name: draft.name,
      colorKey: draft.colorKey,
      address: draft.address,
      note: draft.note,
    );
  }

  /// Updates name, colour, address and note; bumps [Store.updatedAt] (ST-3).
  Future<Store> update({
    required String id,
    required String name,
    required String colorKey,
    String? address,
    String? note,
  }) async {
    final normalizedName = normalizeStoreName(name);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    _requireValidColorKey(colorKey);
    final existing = await (_db.select(
      _db.stores,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Store $id not found');
    }
    final now = _clock();
    final updated = existing.copyWith(
      name: normalizedName,
      colorKey: colorKey,
      address: Value(_normalizeOptionalLine(address)),
      note: Value(_normalizeOptionalLine(note)),
      updatedAt: now,
    );
    await _db.update(_db.stores).replace(updated);
    return updated;
  }

  Future<Store> updateFromDraft(String id, StoreDraft draft) {
    return update(
      id: id,
      name: draft.name,
      colorKey: draft.colorKey,
      address: draft.address,
      note: draft.note,
    );
  }

  /// Sets [Store.archivedAt]; lists, items and wishlist are untouched (ST-4).
  Future<void> archive(String id) async {
    final existing = await (_db.select(
      _db.stores,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Store $id not found');
    }
    if (existing.archivedAt != null) {
      return;
    }
    final now = _clock();
    await (_db.update(_db.stores)..where((t) => t.id.equals(id))).write(
      StoresCompanion(archivedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Clears [Store.archivedAt] only (data model restoreStore; idempotent).
  Future<void> restore(String id) async {
    final existing = await (_db.select(
      _db.stores,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Store $id not found');
    }
    if (existing.archivedAt == null) {
      return;
    }
    await (_db.update(_db.stores)..where((t) => t.id.equals(id))).write(
      const StoresCompanion(archivedAt: Value(null)),
    );
  }

  /// Active lists for [storeId] (archive dialog / ST-2 count).
  Future<int> countActiveLists(String storeId) async {
    final query = _db.selectOnly(_db.shoppingLists)
      ..addColumns([_db.shoppingLists.id.count()])
      ..where(
        _db.shoppingLists.storeId.equals(storeId) &
            _db.shoppingLists.archivedAt.isNull(),
      );
    final row = await query.getSingle();
    return row.read(_db.shoppingLists.id.count()) ?? 0;
  }

  /// First palette key unused by an active store; else cycle by active count.
  Future<String> nextFreeColorKey() async {
    final active = await (_db.select(
      _db.stores,
    )..where((t) => t.archivedAt.isNull())).get();
    final used = {for (final store in active) store.colorKey};
    for (final key in AppTokens.storePaletteKeys) {
      if (!used.contains(key)) {
        return key;
      }
    }
    final keys = AppTokens.storePaletteKeys;
    return keys[active.length % keys.length];
  }

  Future<Store> _insert({
    required String name,
    required String colorKey,
    String? address,
    String? note,
  }) async {
    final normalizedName = normalizeStoreName(name);
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    _requireValidColorKey(colorKey);
    final now = _clock();
    final id = _idGenerator();
    final normalizedAddress = _normalizeOptionalLine(address);
    final normalizedNote = _normalizeOptionalLine(note);
    await _db
        .into(_db.stores)
        .insert(
          StoresCompanion.insert(
            id: id,
            name: normalizedName,
            colorKey: colorKey,
            address: Value(normalizedAddress),
            note: Value(normalizedNote),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return Store(
      id: id,
      name: normalizedName,
      colorKey: colorKey,
      address: normalizedAddress,
      note: normalizedNote,
      archivedAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  void _requireValidColorKey(String colorKey) {
    if (!AppTokens.storePaletteKeys.contains(colorKey)) {
      throw ArgumentError.value(colorKey, 'colorKey', 'unknown palette key');
    }
  }

  /// Trim, collapse newlines; empty becomes null. No documented max (D-08).
  static String? _normalizeOptionalLine(String? value) {
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
