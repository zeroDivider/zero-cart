import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/ordering.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';
import 'package:zero_cart/features/lists/assign_inbox_target.dart';
import 'package:zero_cart/features/lists/list_exceptions.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/store_draft.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

void main() {
  late AppDatabase db;
  late List<DateTime> clockTicks;
  late int idCounter;
  late StoresRepository stores;
  late ListsRepository lists;
  late InboxRepository inbox;

  setUp(() {
    db = AppDatabase.memory();
    clockTicks = <DateTime>[
      for (var i = 0; i < 120; i++) DateTime.utc(2026, 1, 1, 12, 0, i),
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
    inbox = InboxRepository(database: db, now: nextClock, newId: nextId);
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

  test('removeItem returns snapshot and deletes the row', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final milk = await lists.addItem(
      listId: list.id,
      title: 'Milk',
      description: '2L',
    );
    await lists.setPurchased(milk.id, true);

    final snapshot = await lists.removeItem(milk.id);
    expect(snapshot.id, milk.id);
    expect(snapshot.title, 'Milk');
    expect(snapshot.description, '2L');
    expect(snapshot.isPurchased, isTrue);
    expect(snapshot.position, milk.position);
    expect(snapshot.createdAt, milk.createdAt);
    expect(snapshot.updatedAt, isNot(milk.updatedAt));

    final remaining = await lists.watchItems(list.id).first;
    expect(remaining, isEmpty);
  });

  test('removeItem rejects archived lists without deleting', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final milk = await lists.addItem(listId: list.id, title: 'Milk');
    await lists.archive(list.id);

    await expectLater(
      lists.removeItem(milk.id),
      throwsA(isA<ListArchivedException>()),
    );
    final remaining = await lists.watchItems(list.id).first;
    expect(remaining.single.id, milk.id);
  });

  test('restoreItem re-inserts unchanged including after reorder', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final a = await lists.addItem(listId: list.id, title: 'A');
    final b = await lists.addItem(
      listId: list.id,
      title: 'B',
      description: 'keep me',
    );
    final c = await lists.addItem(listId: list.id, title: 'C');
    await lists.setPurchased(b.id, true);
    final beforeRemove = (await lists.watchItems(list.id).first).firstWhere(
      (i) => i.id == b.id,
    );

    final snapshot = await lists.removeItem(b.id);
    expect(snapshot.isPurchased, isTrue);
    expect(snapshot.position, beforeRemove.position);
    await lists.reorderActive(list.id, [c.id, a.id]);

    await lists.restoreItem(snapshot);
    final after = await lists.watchItems(list.id).first;
    final restored = after.firstWhere((i) => i.id == b.id);
    expect(restored.title, 'B');
    expect(restored.description, 'keep me');
    expect(restored.isPurchased, isTrue);
    expect(restored.position, snapshot.position);
    expect(restored.createdAt, snapshot.createdAt);
    expect(restored.updatedAt, snapshot.updatedAt);
    expect(after.map((i) => i.id), containsAll([a.id, b.id, c.id]));
  });

  test('restoreItem tolerates a position tie with created_at order', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    await insertItem(
      id: 'tie-a',
      listId: list.id,
      title: 'A',
      purchased: false,
      position: 1,
    );
    final snapshot = ListItem(
      id: 'tie-b',
      listId: list.id,
      title: 'B',
      description: null,
      isPurchased: false,
      position: 1,
      createdAt: DateTime.utc(2026, 1, 1, 10),
      updatedAt: DateTime.utc(2026, 1, 1, 10),
    );

    await lists.restoreItem(snapshot);
    final after = await lists.watchItems(list.id).first;
    expect(after.map((i) => i.id).toList(), ['tie-a', 'tie-b']);
    expect(after.every((i) => i.position == 1), isTrue);
  });

  test('restoreItem rejects archived and missing lists', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final milk = await lists.addItem(listId: list.id, title: 'Milk');
    final snapshot = await lists.removeItem(milk.id);
    await lists.archive(list.id);

    await expectLater(
      lists.restoreItem(snapshot),
      throwsA(isA<ListUnavailableException>()),
    );
    expect(await lists.watchItems(list.id).first, isEmpty);

    final orphan = ListItem(
      id: 'orphan',
      listId: 'missing-list',
      title: 'Ghost',
      description: null,
      isPurchased: false,
      position: 1,
      createdAt: DateTime.utc(2026, 1, 1, 9),
      updatedAt: DateTime.utc(2026, 1, 1, 9),
    );
    await expectLater(
      lists.restoreItem(orphan),
      throwsA(isA<ListUnavailableException>()),
    );
  });

  group('assignInbox', () {
    test('assigns to existing store and list at max+1', () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');
      await lists.addItem(listId: list.id, title: 'Bread');
      final milk = await inbox.add(title: 'Milk', description: '2L');

      final result = await lists.assignInbox(
        [milk.id],
        AssignInboxTarget(
          store: ExistingStore(store.id),
          list: ExistingList(list.id),
        ),
      );

      expect(result.listId, list.id);
      expect(result.listName, 'Weekend');
      final items = await lists.watchItems(list.id).first;
      expect(items.map((i) => i.title).toList(), ['Bread', 'Milk']);
      expect(items.last.position, 2);
      expect(items.last.description, '2L');
      expect(await inbox.watchAll().first, isEmpty);
    });

    test('batch appends oldest-first and creates a new list', () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final newer = await inbox.add(title: 'Newer');
      final older = await inbox.add(title: 'Older');
      // Swap created_at so Older is first despite later insert.
      await (db.update(
        db.inboxItems,
      )..where((t) => t.id.equals(older.id))).write(
        InboxItemsCompanion(createdAt: Value(DateTime.utc(2026, 1, 1, 10))),
      );
      await (db.update(
        db.inboxItems,
      )..where((t) => t.id.equals(newer.id))).write(
        InboxItemsCompanion(createdAt: Value(DateTime.utc(2026, 1, 1, 11))),
      );

      final result = await lists.assignInbox(
        [newer.id, older.id],
        AssignInboxTarget(
          store: ExistingStore(store.id),
          list: const NewList('Party'),
        ),
      );

      final items = await lists.watchItems(result.listId).first;
      expect(items.map((i) => i.title).toList(), ['Older', 'Newer']);
      expect(items.map((i) => i.position).toList(), [1, 2]);
      expect(await inbox.watchAll().first, isEmpty);
    });

    test('creates new store and list in one transaction', () async {
      final item = await inbox.add(title: 'Tablets');

      final result = await lists.assignInbox(
        [item.id],
        const AssignInboxTarget(
          store: NewStore(
            StoreDraft(name: 'DM', colorKey: 'sky', address: 'Main'),
          ),
          list: NewList('Drugstore'),
        ),
      );

      expect(result.listName, 'Drugstore');
      final createdStores = await stores.watchActive().first;
      expect(createdStores.single.name, 'DM');
      expect(createdStores.single.address, 'Main');
      final items = await lists.watchItems(result.listId).first;
      expect(items.single.title, 'Tablets');
      expect(await inbox.watchAll().first, isEmpty);
    });

    test('rejects archived store and list without writing', () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');
      final item = await inbox.add(title: 'Milk');
      await lists.archive(list.id);

      await expectLater(
        lists.assignInbox(
          [item.id],
          AssignInboxTarget(
            store: ExistingStore(store.id),
            list: ExistingList(list.id),
          ),
        ),
        throwsA(isA<ListArchivedException>()),
      );
      expect((await inbox.watchAll().first).single.id, item.id);

      await lists.restore(list.id);
      await stores.archive(store.id);
      await expectLater(
        lists.assignInbox(
          [item.id],
          AssignInboxTarget(
            store: ExistingStore(store.id),
            list: ExistingList(list.id),
          ),
        ),
        throwsA(isA<StoreArchivedException>()),
      );
      expect((await inbox.watchAll().first).single.id, item.id);
      expect(await db.select(db.listItems).get(), isEmpty);
    });

    test('aborts when an inbox id is missing', () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');
      final item = await inbox.add(title: 'Milk');

      await expectLater(
        lists.assignInbox(
          [item.id, 'missing'],
          AssignInboxTarget(
            store: ExistingStore(store.id),
            list: ExistingList(list.id),
          ),
        ),
        throwsStateError,
      );
      expect((await inbox.watchAll().first).single.id, item.id);
      expect(await db.select(db.listItems).get(), isEmpty);
    });

    test('mid-transaction failure rolls back new store and inbox', () async {
      final item = await inbox.add(title: 'Milk');
      final storesBefore = await db.select(db.stores).get();

      await expectLater(
        lists.assignInbox(
          [item.id],
          const AssignInboxTarget(
            store: NewStore(StoreDraft(name: 'DM', colorKey: 'sky')),
            list: NewList('   '),
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(await db.select(db.stores).get(), storesBefore);
      expect(await db.select(db.shoppingLists).get(), isEmpty);
      expect(await db.select(db.listItems).get(), isEmpty);
      expect((await inbox.watchAll().first).single.id, item.id);
    });

    test('rejects list that belongs to another store', () async {
      final lidl = await stores.create(name: 'Lidl', colorKey: 'lime');
      final dm = await stores.create(name: 'DM', colorKey: 'sky');
      final dmList = await lists.create(storeId: dm.id, name: 'Run');
      final item = await inbox.add(title: 'Milk');

      await expectLater(
        lists.assignInbox(
          [item.id],
          AssignInboxTarget(
            store: ExistingStore(lidl.id),
            list: ExistingList(dmList.id),
          ),
        ),
        throwsStateError,
      );
      expect((await inbox.watchAll().first).single.id, item.id);
      expect(await db.select(db.listItems).get(), isEmpty);
    });
  });
}
