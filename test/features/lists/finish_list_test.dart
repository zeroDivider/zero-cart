import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/finish_list_result.dart';
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
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertItem({
    required String id,
    required String listId,
    required String title,
    required bool purchased,
    String? description,
    int position = 1,
    DateTime? createdAt,
  }) async {
    final now = createdAt ?? DateTime.utc(2026, 1, 1, 9);
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: id,
            listId: listId,
            title: title,
            description: Value(description),
            isPurchased: Value(purchased),
            position: position,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test(
    'carry-forward copies leftovers in order with new ids; original untouched',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');
      // Positions with a tie: Milk and Bread share position 1; order by created_at, id.
      await insertItem(
        id: 'item-milk',
        listId: list.id,
        title: 'Milk',
        description: '2L',
        purchased: false,
        position: 1,
        createdAt: DateTime.utc(2026, 1, 1, 8),
      );
      await insertItem(
        id: 'item-pasta',
        listId: list.id,
        title: 'Pasta',
        purchased: true,
        position: 2,
        createdAt: DateTime.utc(2026, 1, 1, 8, 1),
      );
      await insertItem(
        id: 'item-bread',
        listId: list.id,
        title: 'Bread',
        purchased: false,
        position: 1,
        createdAt: DateTime.utc(2026, 1, 1, 8, 2),
      );
      await insertItem(
        id: 'item-eggs',
        listId: list.id,
        title: 'Eggs',
        purchased: false,
        position: 3,
        createdAt: DateTime.utc(2026, 1, 1, 8, 3),
      );

      final result = await lists.finishList(
        list.id,
        carryForward: true,
        newName: 'Leftovers: Weekend',
      );

      expect(result.archivedListId, list.id);
      expect(result.newListId, isNotNull);
      expect(result.carriedCount, 3);

      final archived = await (db.select(
        db.shoppingLists,
      )..where((t) => t.id.equals(list.id))).getSingle();
      expect(archived.archivedAt, isNotNull);
      expect(archived.archiveReason, ListsRepository.archiveReasonFinished);

      final originalItems =
          await (db.select(db.listItems)
                ..where((t) => t.listId.equals(list.id))
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get();
      expect(originalItems, hasLength(4));
      expect(
        originalItems.map((i) => (i.title, i.isPurchased, i.position)),
        containsAll([
          ('Milk', false, 1),
          ('Pasta', true, 2),
          ('Bread', false, 1),
          ('Eggs', false, 3),
        ]),
      );

      final newList = await (db.select(
        db.shoppingLists,
      )..where((t) => t.id.equals(result.newListId!))).getSingle();
      expect(newList.storeId, store.id);
      expect(newList.name, 'Leftovers: Weekend');
      expect(newList.archivedAt, isNull);

      final copies =
          await (db.select(db.listItems)
                ..where((t) => t.listId.equals(result.newListId!))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      expect(copies.map((i) => i.title), ['Milk', 'Bread', 'Eggs']);
      expect(copies.map((i) => i.position), [1, 2, 3]);
      expect(copies.every((i) => !i.isPurchased), isTrue);
      expect(
        copies.map((i) => i.id).toSet().intersection({
          'item-milk',
          'item-bread',
          'item-eggs',
        }),
        isEmpty,
      );
      expect(copies.first.description, '2L');
    },
  );

  test(
    'archive without carrying creates no new list; leftovers stay on original',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Party');
      await insertItem(
        id: 'left-1',
        listId: list.id,
        title: 'Chips',
        purchased: false,
      );
      await insertItem(
        id: 'bought-1',
        listId: list.id,
        title: 'Soda',
        purchased: true,
        position: 2,
      );

      final result = await lists.finishList(list.id, carryForward: false);

      expect(
        result,
        isA<FinishListResult>()
            .having((r) => r.archivedListId, 'archivedListId', list.id)
            .having((r) => r.newListId, 'newListId', isNull)
            .having((r) => r.carriedCount, 'carriedCount', 0),
      );

      final allLists = await db.select(db.shoppingLists).get();
      expect(allLists, hasLength(1));
      expect(
        allLists.single.archiveReason,
        ListsRepository.archiveReasonFinished,
      );

      final items = await lists.watchItems(list.id).first;
      expect(items.map((i) => i.title), ['Chips', 'Soda']);
      expect(items.first.isPurchased, isFalse);
    },
  );

  test('empty list finishes with carriedCount 0 and no new list', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Empty');

    final result = await lists.finishList(
      list.id,
      carryForward: true,
      newName: 'Leftovers: Empty',
    );

    expect(result.newListId, isNull);
    expect(result.carriedCount, 0);
    expect(await db.select(db.shoppingLists).get(), hasLength(1));
    final archived = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(list.id))).getSingle();
    expect(archived.archiveReason, ListsRepository.archiveReasonFinished);
  });

  test(
    'carryForward true with only purchased items creates no new list',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Done');
      await insertItem(
        id: 'bought',
        listId: list.id,
        title: 'Milk',
        purchased: true,
      );

      final result = await lists.finishList(
        list.id,
        carryForward: true,
        newName: 'Leftovers: Done',
      );

      expect(result.newListId, isNull);
      expect(result.carriedCount, 0);
      expect(await db.select(db.shoppingLists).get(), hasLength(1));
    },
  );

  test(
    'finishing an already-archived list throws ListArchivedException',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Old');
      await lists.archive(list.id);

      await expectLater(
        lists.finishList(list.id, carryForward: false),
        throwsA(isA<ListArchivedException>()),
      );
    },
  );

  test('finishing a missing list throws StateError', () async {
    await expectLater(
      lists.finishList('missing', carryForward: false),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'blank newName on carry-forward rolls back; list stays active',
    () async {
      final store = await stores.create(name: 'Lidl', colorKey: 'lime');
      final list = await lists.create(storeId: store.id, name: 'Weekend');
      await insertItem(
        id: 'left',
        listId: list.id,
        title: 'Milk',
        purchased: false,
      );

      await expectLater(
        lists.finishList(list.id, carryForward: true, newName: '   '),
        throwsA(isA<ArgumentError>()),
      );

      final still = await (db.select(
        db.shoppingLists,
      )..where((t) => t.id.equals(list.id))).getSingle();
      expect(still.archivedAt, isNull);
      expect(still.archiveReason, isNull);
      expect(await db.select(db.shoppingLists).get(), hasLength(1));
      expect(await db.select(db.listItems).get(), hasLength(1));
    },
  );

  test('mid-transaction id failure rolls back archive and new list', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    final listUpdatedAt = list.updatedAt;
    await insertItem(
      id: 'left-a',
      listId: list.id,
      title: 'Milk',
      purchased: false,
      position: 1,
    );
    await insertItem(
      id: 'left-b',
      listId: list.id,
      title: 'Bread',
      purchased: false,
      position: 2,
    );

    var idsIssued = 0;
    final flakyLists = ListsRepository(
      database: db,
      now: () {
        if (clockTicks.isEmpty) {
          fail('clock exhausted');
        }
        return clockTicks.removeAt(0);
      },
      newId: () {
        idsIssued += 1;
        // New list id 1, first copy id 2, second copy would be id 3.
        if (idsIssued == 3) {
          throw StateError('forced id failure');
        }
        return 'flaky-$idsIssued';
      },
    );

    await expectLater(
      flakyLists.finishList(
        list.id,
        carryForward: true,
        newName: 'Leftovers: Weekend',
      ),
      throwsA(isA<StateError>()),
    );

    final still = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(list.id))).getSingle();
    expect(still.archivedAt, isNull);
    expect(still.archiveReason, isNull);
    expect(still.updatedAt, listUpdatedAt);
    expect(await db.select(db.shoppingLists).get(), hasLength(1));
    final items = await lists.watchItems(list.id).first;
    expect(items.map((i) => i.id), ['left-a', 'left-b']);
  });

  test('carry-forward rejects archived parent store (I3)', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    await insertItem(
      id: 'left',
      listId: list.id,
      title: 'Milk',
      purchased: false,
    );
    await stores.archive(store.id);

    await expectLater(
      lists.finishList(
        list.id,
        carryForward: true,
        newName: 'Leftovers: Weekend',
      ),
      throwsA(isA<StoreArchivedException>()),
    );

    final still = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(list.id))).getSingle();
    expect(still.archivedAt, isNull);
    expect(await db.select(db.shoppingLists).get(), hasLength(1));
  });

  test('restore after finish returns the list to active', () async {
    final store = await stores.create(name: 'Lidl', colorKey: 'lime');
    final list = await lists.create(storeId: store.id, name: 'Weekend');
    await insertItem(
      id: 'left',
      listId: list.id,
      title: 'Milk',
      purchased: false,
    );

    final result = await lists.finishList(list.id, carryForward: false);
    await lists.restore(result.archivedListId);

    final restored = await (db.select(
      db.shoppingLists,
    )..where((t) => t.id.equals(list.id))).getSingle();
    expect(restored.archivedAt, isNull);
    expect(restored.archiveReason, isNull);
    final items = await lists.watchItems(list.id).first;
    expect(items.single.title, 'Milk');
    expect(items.single.isPurchased, isFalse);
  });
}
