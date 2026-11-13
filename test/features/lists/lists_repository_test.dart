import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/ordering.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/list_exceptions.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

void main() {
  late AppDatabase db;
  late List<DateTime> clockTicks;
  late int idCounter;
  late StoresRepository stores;
  late ListsRepository lists;

  setUp(() {
    db = AppDatabase.memory();
    clockTicks = <DateTime>[
      for (var i = 0; i < 60; i++) DateTime.utc(2026, 1, 1, 12, i),
    ];
    idCounter = 0;
    DateTime nextClock() {
      if (clockTicks.isEmpty) {
        fail('clock exhausted');
      }
      return clockTicks.removeAt(0);
    }

    String nextId() {
      idCounter += 1;
      return 'id-$idCounter';
    }

    stores = StoresRepository(database: db, now: nextClock, newId: nextId);
    lists = ListsRepository(database: db, now: nextClock, newId: nextId);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertItem({
    required String id,
    required String listId,
    required String title,
    required bool purchased,
    int position = 1,
  }) async {
    final now = DateTime.utc(2026, 1, 1, 9);
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: id,
            listId: listId,
            title: title,
            isPurchased: Value(purchased),
            position: position,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('create makes an empty active list and rejects empty name', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(
      storeId: store.id,
      name: '  Weekend\nrun  ',
    );

    expect(list.id, isNotEmpty);
    expect(list.storeId, store.id);
    expect(list.name, 'Weekend run');
    expect(list.archivedAt, isNull);
    expect(list.archiveReason, isNull);

    final items = await (db.select(
      db.listItems,
    )..where((t) => t.listId.equals(list.id))).get();
    expect(items, isEmpty);

    expect(
      () => lists.create(storeId: store.id, name: '   '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('create allows duplicate names and rejects archived store', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final a = await lists.create(storeId: store.id, name: 'Party');
    final b = await lists.create(storeId: store.id, name: 'Party');
    expect(a.name, 'Party');
    expect(b.name, 'Party');
    expect(a.id, isNot(b.id));

    await stores.archive(store.id);
    expect(
      () => lists.create(storeId: store.id, name: 'New'),
      throwsA(isA<StoreArchivedException>()),
    );
  });

  test('rename updates name; rejects empty and archived lists', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final renamed = await lists.rename(id: list.id, name: '  Party  ');
    expect(renamed.name, 'Party');

    expect(
      () => lists.rename(id: list.id, name: '  '),
      throwsA(isA<ArgumentError>()),
    );

    await lists.archive(list.id);
    expect(
      () => lists.rename(id: list.id, name: 'Again'),
      throwsA(isA<ListArchivedException>()),
    );
  });

  test(
    'archive sets manual reason; restore clears when store active',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');

      await lists.archive(list.id);
      final archived = await (db.select(
        db.shoppingLists,
      )..where((t) => t.id.equals(list.id))).getSingle();
      expect(archived.archivedAt, isNotNull);
      expect(archived.archiveReason, ListsRepository.archiveReasonManual);

      await lists.restore(list.id);
      final restored = await (db.select(
        db.shoppingLists,
      )..where((t) => t.id.equals(list.id))).getSingle();
      expect(restored.archivedAt, isNull);
      expect(restored.archiveReason, isNull);
    },
  );

  test(
    'restore throws StoreArchivedException when store is archived',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');
      await lists.archive(list.id);
      await stores.archive(store.id);

      expect(
        () => lists.restore(list.id),
        throwsA(isA<StoreArchivedException>()),
      );

      final still = await (db.select(
        db.shoppingLists,
      )..where((t) => t.id.equals(list.id))).getSingle();
      expect(still.archivedAt, isNotNull);
      expect(still.archiveReason, ListsRepository.archiveReasonManual);
    },
  );

  test('watchActiveForStore emits progress and updates live', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final events = <List<int>>[];
    final sub = lists.watchActiveForStore(store.id).listen((rows) {
      events.add([
        for (final row in rows) ...[row.itemsLeft, row.itemsTotal],
      ]);
    });

    final list = await lists.create(storeId: store.id, name: 'Weekend');
    await pumpEventQueue();
    expect(events.last, [0, 0]);

    await insertItem(
      id: 'item-1',
      listId: list.id,
      title: 'Milk',
      purchased: false,
    );
    await insertItem(
      id: 'item-2',
      listId: list.id,
      title: 'Bread',
      purchased: true,
      position: 2,
    );
    await pumpEventQueue();
    expect(events.last, [1, 2]);

    await lists.archive(list.id);
    await pumpEventQueue();
    expect(events.last, isEmpty);

    await sub.cancel();
  });

  test('watchById emits list and updates on rename', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final events = <ShoppingList?>[];
    final sub = lists.watchById(list.id).listen(events.add);

    await pumpEventQueue();
    expect(events.last?.name, 'Weekend');

    await lists.rename(id: list.id, name: 'Party');
    await pumpEventQueue();
    expect(events.last?.name, 'Party');

    await sub.cancel();
  });

  test('addItem uses max+1 position and touches list updated_at', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final before = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(list.id))).getSingle();

    final first = await lists.addItem(
      listId: list.id,
      title: '  Milk\n2L  ',
      description: '  lactose-free  ',
    );
    expect(first.position, 1);
    expect(first.title, 'Milk 2L');
    expect(first.description, 'lactose-free');
    expect(first.isPurchased, isFalse);

    await insertItem(
      id: 'seed-purchased',
      listId: list.id,
      title: 'Bread',
      purchased: true,
      position: 5,
    );
    final second = await lists.addItem(listId: list.id, title: 'Eggs');
    expect(second.position, 6);

    final after = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(list.id))).getSingle();
    expect(after.updatedAt.isAfter(before.updatedAt), isTrue);

    expect(
      () => lists.addItem(listId: list.id, title: '   '),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('addItem rejects archived lists without writing', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    await lists.archive(list.id);
    final before = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(list.id))).getSingle();

    expect(
      () => lists.addItem(listId: list.id, title: 'Milk'),
      throwsA(isA<ListArchivedException>()),
    );

    final items = await (db.select(
      db.listItems,
    )..where((t) => t.listId.equals(list.id))).get();
    expect(items, isEmpty);
    final after = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(list.id))).getSingle();
    expect(after.updatedAt, before.updatedAt);
  });

  test('setPurchased leaves position alone', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final a = await lists.addItem(listId: list.id, title: 'Milk');
    final b = await lists.addItem(listId: list.id, title: 'Bread');
    final c = await lists.addItem(listId: list.id, title: 'Eggs');

    await lists.setPurchased(b.id, true);
    final purchased = await (db.select(
      db.listItems,
    )..where((t) => t.id.equals(b.id))).getSingle();
    expect(purchased.isPurchased, isTrue);
    expect(purchased.position, b.position);

    final ordered = await lists.watchItems(list.id).first;
    expect(ordered.map((i) => i.id).toList(), [a.id, b.id, c.id]);

    await lists.setPurchased(b.id, false);
    final unchecked = await (db.select(
      db.listItems,
    )..where((t) => t.id.equals(b.id))).getSingle();
    expect(unchecked.isPurchased, isFalse);
    expect(unchecked.position, b.position);
  });

  test('updateItem normalizes fields and rejects archived lists', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final item = await lists.addItem(listId: list.id, title: 'Milk');

    final updated = await lists.updateItem(
      id: item.id,
      title: '  Pasta\n500g  ',
      description: '  ',
    );
    expect(updated.title, 'Pasta 500g');
    expect(updated.description, isNull);
    expect(updated.position, item.position);
    expect(updated.isPurchased, isFalse);

    await lists.archive(list.id);
    expect(
      () => lists.updateItem(id: item.id, title: 'Again'),
      throwsA(isA<ListArchivedException>()),
    );
    expect(
      () => lists.setPurchased(item.id, true),
      throwsA(isA<ListArchivedException>()),
    );
  });

  test('watchItems orders by position then created_at then id', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final now = DateTime.utc(2026, 1, 1, 10);
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'b',
            listId: list.id,
            title: 'B',
            position: 1,
            createdAt: now.add(const Duration(seconds: 1)),
            updatedAt: now,
          ),
        );
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'a',
            listId: list.id,
            title: 'A',
            position: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'c',
            listId: list.id,
            title: 'C',
            position: 2,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final ordered = await lists.watchItems(list.id).first;
    expect(ordered.map((i) => i.id).toList(), ['a', 'b', 'c']);
  });

  test('reorderActive densifies ties and keeps purchased slots', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final now = DateTime.utc(2026, 1, 1, 10);
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'b',
            listId: list.id,
            title: 'B',
            position: 1,
            createdAt: now.add(const Duration(seconds: 1)),
            updatedAt: now,
          ),
        );
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'a',
            listId: list.id,
            title: 'A',
            position: 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'c',
            listId: list.id,
            title: 'C',
            isPurchased: const Value(true),
            position: 2,
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Load order with ties: a, b, c(purchased). Move b before a.
    await lists.reorderActive(list.id, ['b', 'a']);
    final ordered = await lists.watchItems(list.id).first;
    expect(ordered.map((i) => i.id).toList(), ['b', 'a', 'c']);
    expect(ordered.map((i) => i.position).toList(), [1, 2, 3]);
    expect(ordered.last.isPurchased, isTrue);
  });

  test(
    'reorderActive with purchased in the middle preserves relative order',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');
      await insertItem(
        id: 'a',
        listId: list.id,
        title: 'A',
        purchased: false,
        position: 1,
      );
      await insertItem(
        id: 'p1',
        listId: list.id,
        title: 'P1',
        purchased: true,
        position: 2,
      );
      await insertItem(
        id: 'b',
        listId: list.id,
        title: 'B',
        purchased: false,
        position: 3,
      );
      await insertItem(
        id: 'p2',
        listId: list.id,
        title: 'P2',
        purchased: true,
        position: 4,
      );
      await insertItem(
        id: 'c',
        listId: list.id,
        title: 'C',
        purchased: false,
        position: 5,
      );

      await lists.reorderActive(list.id, ['c', 'a', 'b']);
      final ordered = await lists.watchItems(list.id).first;
      expect(ordered.map((i) => i.id).toList(), ['c', 'p1', 'a', 'p2', 'b']);
      expect(ordered.map((i) => (i.id, i.position, i.isPurchased)).toList(), [
        ('c', 1, false),
        ('p1', 2, true),
        ('a', 3, false),
        ('p2', 4, true),
        ('b', 5, false),
      ]);
    },
  );

  test('reorderActive aborts on stale input without writing', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final a = await lists.addItem(listId: list.id, title: 'A');
    final b = await lists.addItem(listId: list.id, title: 'B');

    await expectLater(
      lists.reorderActive(list.id, [b.id]),
      throwsA(isA<StaleOrderException>()),
    );
    await expectLater(
      lists.reorderActive(list.id, [a.id, b.id, 'missing']),
      throwsA(isA<StaleOrderException>()),
    );

    final ordered = await lists.watchItems(list.id).first;
    expect(ordered.map((i) => i.id).toList(), [a.id, b.id]);
    expect(ordered.map((i) => i.position).toList(), [1, 2]);
  });

  test(
    'check, reorder others, uncheck returns to stored position slot',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');
      final a = await lists.addItem(listId: list.id, title: 'A');
      final b = await lists.addItem(listId: list.id, title: 'B');
      final c = await lists.addItem(listId: list.id, title: 'C');

      await lists.setPurchased(b.id, true);
      await lists.reorderActive(list.id, [c.id, a.id]);

      final afterReorder = await lists.watchItems(list.id).first;
      expect(afterReorder.map((i) => i.id).toList(), [c.id, b.id, a.id]);
      final bRow = afterReorder.firstWhere((i) => i.id == b.id);
      expect(bRow.position, 2);
      expect(bRow.isPurchased, isTrue);

      await lists.setPurchased(b.id, false);
      final afterUncheck = await lists.watchItems(list.id).first;
      expect(afterUncheck.map((i) => i.id).toList(), [c.id, b.id, a.id]);
      expect(afterUncheck.map((i) => !i.isPurchased).toList(), [
        true,
        true,
        true,
      ]);
    },
  );

  test('reorderActive rejects archived lists', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final a = await lists.addItem(listId: list.id, title: 'A');
    final b = await lists.addItem(listId: list.id, title: 'B');
    await lists.archive(list.id);

    await expectLater(
      lists.reorderActive(list.id, [b.id, a.id]),
      throwsA(isA<ListArchivedException>()),
    );
  });
}
