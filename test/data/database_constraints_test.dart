import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/data/database.dart';

/// SQLite constraint / FK failures from the native opener.
Matcher get throwsSqliteFailure => throwsA(
  isA<Object>().having(
    (Object e) => e.runtimeType.toString(),
    'type',
    contains('SqliteException'),
  ),
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  final now = DateTime.utc(2026, 11, 10, 12);

  Future<void> insertStore({String id = 'store-1'}) {
    return db
        .into(db.stores)
        .insert(
          StoresCompanion.insert(
            id: id,
            name: 'Lidl',
            colorKey: 'lime',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> insertList({
    String id = 'list-1',
    String storeId = 'store-1',
    DateTime? archivedAt,
    String? archiveReason,
  }) {
    return db
        .into(db.shoppingLists)
        .insert(
          ShoppingListsCompanion.insert(
            id: id,
            storeId: storeId,
            name: 'Weekend groceries',
            archivedAt: Value(archivedAt),
            archiveReason: Value(archiveReason),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('inserting an item for a missing list fails', () async {
    await expectLater(
      () => db
          .into(db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              listId: 'missing-list',
              title: 'Milk',
              position: 1,
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsSqliteFailure,
    );
  });

  test('an empty title fails', () async {
    await insertStore();
    await insertList();

    await expectLater(
      () => db
          .into(db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              listId: 'list-1',
              title: '',
              position: 1,
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsSqliteFailure,
    );
  });

  test('an archived list without a reason fails', () async {
    await insertStore();

    await expectLater(() => insertList(archivedAt: now), throwsSqliteFailure);
  });

  test('deleting a store cascades to its lists, items and wishlist', () async {
    await insertStore();
    await insertList();
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            listId: 'list-1',
            title: 'Milk',
            position: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.wishlistItems)
        .insert(
          WishlistItemsCompanion.insert(
            id: 'wish-1',
            storeId: 'store-1',
            title: 'Toothbrush heads',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await (db.delete(db.stores)..where((t) => t.id.equals('store-1'))).go();

    expect(await db.select(db.stores).get(), isEmpty);
    expect(await db.select(db.shoppingLists).get(), isEmpty);
    expect(await db.select(db.listItems).get(), isEmpty);
    expect(await db.select(db.wishlistItems).get(), isEmpty);
  });

  test(
    'items for a list read back ordered by (position, created_at, id)',
    () async {
      await insertStore();
      await insertList();

      final earlier = DateTime.utc(2026, 11, 10, 10);
      final later = DateTime.utc(2026, 11, 10, 11);

      // Insert out of desired order: tied position 2 with later then earlier,
      // then position 1, then position 2 with a higher id for the same time.
      await db
          .into(db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-b',
              listId: 'list-1',
              title: 'B',
              position: 2,
              createdAt: later,
              updatedAt: later,
            ),
          );
      await db
          .into(db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-a',
              listId: 'list-1',
              title: 'A',
              position: 2,
              createdAt: earlier,
              updatedAt: earlier,
            ),
          );
      await db
          .into(db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-z',
              listId: 'list-1',
              title: 'Z',
              position: 1,
              createdAt: later,
              updatedAt: later,
            ),
          );
      await db
          .into(db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-c',
              listId: 'list-1',
              title: 'C',
              position: 2,
              createdAt: earlier,
              updatedAt: earlier,
            ),
          );

      final rows =
          await (db.select(db.listItems)
                ..where((t) => t.listId.equals('list-1'))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();

      expect(rows.map((r) => r.id).toList(), [
        'item-z', // position 1
        'item-a', // position 2, earlier, id a
        'item-c', // position 2, earlier, id c
        'item-b', // position 2, later
      ]);
    },
  );
}
