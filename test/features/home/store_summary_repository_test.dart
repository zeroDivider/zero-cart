import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/home/store_summary.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

void main() {
  late AppDatabase db;
  late List<DateTime> clockTicks;
  late int idCounter;
  late StoresRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    clockTicks = <DateTime>[
      for (var i = 0; i < 80; i++) DateTime.utc(2026, 1, 1, 12, i),
    ];
    idCounter = 0;
    repo = StoresRepository(
      database: db,
      now: () {
        if (clockTicks.isEmpty) {
          fail('clock exhausted');
        }
        return clockTicks.removeAt(0);
      },
      newId: () {
        idCounter += 1;
        return 'id-$idCounter';
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertList({
    required String id,
    required String storeId,
    required String name,
    required DateTime updatedAt,
    DateTime? archivedAt,
    String? archiveReason,
  }) async {
    await db
        .into(db.shoppingLists)
        .insert(
          ShoppingListsCompanion.insert(
            id: id,
            storeId: storeId,
            name: name,
            archivedAt: Value(archivedAt),
            archiveReason: Value(archiveReason),
            createdAt: updatedAt,
            updatedAt: updatedAt,
          ),
        );
  }

  Future<void> insertItem({
    required String id,
    required String listId,
    required String title,
    required bool isPurchased,
    required int position,
  }) async {
    final now = DateTime.utc(2026, 1, 1, 9);
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: id,
            listId: listId,
            title: title,
            isPurchased: Value(isPurchased),
            position: position,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test(
    'excludes archived stores and archived-list items from counts',
    () async {
      final events = <List<StoreSummary>>[];
      final sub = repo.watchHomeStoreSummaries().listen(events.add);

      final active = await repo.create(name: 'Active', colorKey: 'lime');
      final archived = await repo.create(name: 'Gone', colorKey: 'sky');
      await insertList(
        id: 'list-a',
        storeId: active.id,
        name: 'Cart',
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await insertList(
        id: 'list-archived',
        storeId: active.id,
        name: 'Old',
        updatedAt: DateTime.utc(2026, 1, 3),
        archivedAt: DateTime.utc(2026, 1, 4),
        archiveReason: 'manual',
      );
      await insertItem(
        id: 'item-1',
        listId: 'list-a',
        title: 'Milk',
        isPurchased: false,
        position: 1,
      );
      await insertItem(
        id: 'item-2',
        listId: 'list-archived',
        title: 'Hidden',
        isPurchased: false,
        position: 1,
      );
      await repo.archive(archived.id);
      await pumpEventQueue();

      expect(events.last.map((s) => s.store.name), ['Active']);
      final summary = events.last.single;
      expect(summary.activeListCount, 1);
      expect(summary.unpurchasedCount, 1);
      expect(summary.totalItemCount, 1);

      await sub.cancel();
    },
  );

  test(
    'aggregates unpurchased and total across multiple active lists',
    () async {
      final events = <List<StoreSummary>>[];
      final sub = repo.watchHomeStoreSummaries().listen(events.add);

      final store = await repo.create(name: 'Lidl', colorKey: 'lime');
      await insertList(
        id: 'list-1',
        storeId: store.id,
        name: 'A',
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await insertList(
        id: 'list-2',
        storeId: store.id,
        name: 'B',
        updatedAt: DateTime.utc(2026, 1, 3),
      );
      await insertItem(
        id: 'i1',
        listId: 'list-1',
        title: 'Milk',
        isPurchased: false,
        position: 1,
      );
      await insertItem(
        id: 'i2',
        listId: 'list-1',
        title: 'Bread',
        isPurchased: true,
        position: 2,
      );
      await insertItem(
        id: 'i3',
        listId: 'list-2',
        title: 'Eggs',
        isPurchased: false,
        position: 1,
      );
      await pumpEventQueue();

      final summary = events.last.single;
      expect(summary.activeListCount, 2);
      expect(summary.unpurchasedCount, 2);
      expect(summary.totalItemCount, 3);
      expect(summary.purchasedProgress, closeTo(1 / 3, 0.001));

      await sub.cancel();
    },
  );

  test(
    'lastActivity uses newest active list then falls back to store',
    () async {
      final events = <List<StoreSummary>>[];
      final sub = repo.watchHomeStoreSummaries().listen(events.add);

      final empty = await repo.create(name: 'Empty', colorKey: 'sky');
      final busy = await repo.create(name: 'Busy', colorKey: 'lime');
      await pumpEventQueue();

      final emptyRow = events.last.singleWhere((s) => s.store.id == empty.id);
      expect(emptyRow.lastActivity, empty.updatedAt);
      expect(emptyRow.activeListCount, 0);

      await insertList(
        id: 'older',
        storeId: busy.id,
        name: 'Older',
        updatedAt: DateTime.utc(2026, 1, 2, 10),
      );
      await insertList(
        id: 'newer',
        storeId: busy.id,
        name: 'Newer',
        updatedAt: DateTime.utc(2026, 1, 5, 10),
      );
      await insertList(
        id: 'archived-newer',
        storeId: busy.id,
        name: 'Archived',
        updatedAt: DateTime.utc(2026, 1, 9, 10),
        archivedAt: DateTime.utc(2026, 1, 9, 11),
        archiveReason: 'finished',
      );
      await pumpEventQueue();

      final busyRow = events.last.singleWhere((s) => s.store.id == busy.id);
      expect(busyRow.lastActivity, DateTime.utc(2026, 1, 5, 10));

      await sub.cancel();
    },
  );

  test('orders by lastActivity newest first with id tie-break', () async {
    final events = <List<StoreSummary>>[];
    final sub = repo.watchHomeStoreSummaries().listen(events.add);

    final older = await repo.create(name: 'Older', colorKey: 'sky');
    final newer = await repo.create(name: 'Newer', colorKey: 'lime');
    await insertList(
      id: 'list-older',
      storeId: older.id,
      name: 'A',
      updatedAt: DateTime.utc(2026, 1, 2),
    );
    await insertList(
      id: 'list-newer',
      storeId: newer.id,
      name: 'B',
      updatedAt: DateTime.utc(2026, 1, 4),
    );
    await pumpEventQueue();

    expect(events.last.map((s) => s.store.name), ['Newer', 'Older']);

    await sub.cancel();
  });

  test(
    'item purchase updates counts without needing list updated_at change',
    () async {
      final events = <List<StoreSummary>>[];
      final sub = repo.watchHomeStoreSummaries().listen(events.add);

      final store = await repo.create(name: 'Lidl', colorKey: 'lime');
      await insertList(
        id: 'list-1',
        storeId: store.id,
        name: 'Cart',
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      await insertItem(
        id: 'item-1',
        listId: 'list-1',
        title: 'Milk',
        isPurchased: false,
        position: 1,
      );
      await pumpEventQueue();
      expect(events.last.single.unpurchasedCount, 1);
      expect(events.last.single.totalItemCount, 1);
      final activityBefore = events.last.single.lastActivity;

      await (db.update(db.listItems)..where((t) => t.id.equals('item-1')))
          .write(const ListItemsCompanion(isPurchased: Value(true)));
      await pumpEventQueue();

      expect(events.last.single.unpurchasedCount, 0);
      expect(events.last.single.totalItemCount, 1);
      expect(events.last.single.lastActivity, activityBefore);

      await sub.cancel();
    },
  );

  test('archiving a store drops it from the Home stream', () async {
    final events = <List<StoreSummary>>[];
    final sub = repo.watchHomeStoreSummaries().listen(events.add);

    final keep = await repo.create(name: 'Keep', colorKey: 'lime');
    final drop = await repo.create(name: 'Drop', colorKey: 'sky');
    await pumpEventQueue();
    expect(events.last.map((s) => s.store.id).toSet(), {keep.id, drop.id});

    await repo.archive(drop.id);
    await pumpEventQueue();
    expect(events.last.map((s) => s.store.id), [keep.id]);

    await sub.cancel();
  });
}
