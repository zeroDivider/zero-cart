import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

void main() {
  late AppDatabase db;
  late List<DateTime> clockTicks;
  late int idCounter;
  late StoresRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    clockTicks = <DateTime>[
      for (var i = 0; i < 40; i++) DateTime.utc(2026, 1, 1, 12, i),
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
    DateTime? archivedAt,
    String? archiveReason,
  }) async {
    final now = DateTime.utc(2026, 1, 1, 10);
    await db
        .into(db.shoppingLists)
        .insert(
          ShoppingListsCompanion.insert(
            id: id,
            storeId: storeId,
            name: name,
            archivedAt: Value(archivedAt),
            archiveReason: Value(archiveReason),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  test('watchActive orders case-insensitively and excludes archived', () async {
    final events = <List<Store>>[];
    final sub = repo.watchActive().listen(events.add);

    await repo.create(name: 'dm', colorKey: 'sky');
    await repo.create(name: 'Lidl', colorKey: 'lime');
    await repo.create(name: 'aldi', colorKey: 'tomato');
    await pumpEventQueue();

    expect(events.last.map((s) => s.name), ['aldi', 'dm', 'Lidl']);

    final lidl = events.last.firstWhere((s) => s.name == 'Lidl');
    await repo.archive(lidl.id);
    await pumpEventQueue();
    expect(events.last.map((s) => s.name), ['aldi', 'dm']);

    await sub.cancel();
  });

  test('watchArchived orders case-insensitively and excludes active', () async {
    final events = <List<Store>>[];
    final sub = repo.watchArchived().listen(events.add);

    final dm = await repo.create(name: 'dm', colorKey: 'sky');
    final lidl = await repo.create(name: 'Lidl', colorKey: 'lime');
    await repo.create(name: 'aldi', colorKey: 'tomato');
    await pumpEventQueue();
    expect(events.last, isEmpty);

    await repo.archive(lidl.id);
    await repo.archive(dm.id);
    await pumpEventQueue();
    expect(events.last.map((s) => s.name), ['dm', 'Lidl']);

    await repo.restore(dm.id);
    await pumpEventQueue();
    expect(events.last.map((s) => s.name), ['Lidl']);

    await sub.cancel();
  });

  test('nextFreeColorKey returns first unused then cycles', () async {
    expect(await repo.nextFreeColorKey(), 'tomato');

    await repo.create(name: 'A', colorKey: 'tomato');
    await repo.create(name: 'B', colorKey: 'tangerine');
    expect(await repo.nextFreeColorKey(), 'lemon');

    final keys = AppTokens.storePaletteKeys;
    for (var i = 2; i < keys.length; i++) {
      await repo.create(name: 'S$i', colorKey: keys[i]);
    }
    // All eight in use → cycle by active count (8 % 8 == 0 → tomato).
    expect(await repo.nextFreeColorKey(), 'tomato');

    await repo.create(name: 'Extra', colorKey: 'tomato');
    expect(await repo.nextFreeColorKey(), 'tangerine');

    // Archived store frees its colour for the first-unused scan.
    final tomatoStores = await (db.select(
      db.stores,
    )..where((t) => t.colorKey.equals('tangerine'))).get();
    await repo.archive(tomatoStores.first.id);
    expect(await repo.nextFreeColorKey(), 'tangerine');
  });

  test(
    'create normalizes fields and rejects empty name or bad colour',
    () async {
      final store = await repo.create(
        name: '  Lidl\nMarket  ',
        colorKey: 'lime',
        address: '  Main\nSt  ',
        note: '   ',
      );
      expect(store.id, 'id-1');
      expect(store.name, 'Lidl Market');
      expect(store.colorKey, 'lime');
      expect(store.address, 'Main St');
      expect(store.note, isNull);
      expect(store.archivedAt, isNull);

      await expectLater(
        () => repo.create(name: '   ', colorKey: 'tomato'),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        () => repo.create(name: 'X', colorKey: 'magenta'),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test('update bumps updatedAt and watchById emits the change', () async {
    final created = await repo.create(
      name: 'DM',
      colorKey: 'sky',
      address: 'Old',
    );
    final events = <Store?>[];
    final sub = repo.watchById(created.id).listen(events.add);
    await pumpEventQueue();

    final updated = await repo.update(
      id: created.id,
      name: 'DM City',
      colorKey: 'grape',
      address: 'New Rd',
      note: 'Offers',
    );
    await pumpEventQueue();

    expect(updated.name, 'DM City');
    expect(updated.colorKey, 'grape');
    expect(updated.address, 'New Rd');
    expect(updated.note, 'Offers');
    expect(updated.createdAt, created.createdAt);
    expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
    expect(events.last!.name, 'DM City');

    await sub.cancel();
  });

  test('archive is cascade-free; restore clears archivedAt only', () async {
    final store = await repo.create(
      name: 'Lidl',
      colorKey: 'lime',
      address: 'Main St',
      note: 'Weekly',
    );
    await insertList(id: 'list-1', storeId: store.id, name: 'Weekend');
    await insertList(
      id: 'list-2',
      storeId: store.id,
      name: 'Easter',
      archivedAt: DateTime.utc(2026, 1, 1, 9),
      archiveReason: 'finished',
    );
    await db
        .into(db.wishlistItems)
        .insert(
          WishlistItemsCompanion.insert(
            id: 'wish-1',
            storeId: store.id,
            title: 'Brush heads',
            createdAt: DateTime.utc(2026, 1, 1, 8),
            updatedAt: DateTime.utc(2026, 1, 1, 8),
          ),
        );
    await db
        .into(db.listItems)
        .insert(
          ListItemsCompanion.insert(
            id: 'item-1',
            listId: 'list-1',
            title: 'Milk',
            position: 1,
            createdAt: DateTime.utc(2026, 1, 1, 8),
            updatedAt: DateTime.utc(2026, 1, 1, 8),
          ),
        );

    expect(await repo.countActiveLists(store.id), 1);

    final beforeLists = await db.select(db.shoppingLists).get();
    final beforeItems = await db.select(db.listItems).get();
    final beforeWish = await db.select(db.wishlistItems).get();

    await repo.archive(store.id);
    await repo.archive(store.id); // idempotent

    final archived = await (db.select(
      db.stores,
    )..where((t) => t.id.equals(store.id))).getSingle();
    expect(archived.archivedAt, isNotNull);
    expect(archived.name, 'Lidl');
    expect(archived.colorKey, 'lime');
    expect(archived.address, 'Main St');
    expect(archived.note, 'Weekly');

    final afterLists = await db.select(db.shoppingLists).get();
    final afterItems = await db.select(db.listItems).get();
    final afterWish = await db.select(db.wishlistItems).get();
    expect(
      afterLists.map((l) => l.toJson()),
      beforeLists.map((l) => l.toJson()),
    );
    expect(
      afterItems.map((i) => i.toJson()),
      beforeItems.map((i) => i.toJson()),
    );
    expect(afterWish.map((w) => w.toJson()), beforeWish.map((w) => w.toJson()));
    expect(await repo.countActiveLists(store.id), 1);

    final archivedAtBeforeRestore = archived.archivedAt;
    final updatedAtBeforeRestore = archived.updatedAt;
    await repo.restore(store.id);
    await repo.restore(store.id); // idempotent

    final restored = await (db.select(
      db.stores,
    )..where((t) => t.id.equals(store.id))).getSingle();
    expect(restored.archivedAt, isNull);
    expect(restored.updatedAt, updatedAtBeforeRestore);
    expect(restored.name, 'Lidl');
    expect(restored.address, 'Main St');
    expect(restored.note, 'Weekly');
    expect(archivedAtBeforeRestore, isNotNull);
  });

  test('duplicate store names are allowed', () async {
    await repo.create(name: 'Lidl', colorKey: 'lime');
    await repo.create(name: 'Lidl', colorKey: 'sky');
    final active = await repo.watchActive().first;
    expect(active.where((s) => s.name == 'Lidl').length, 2);
  });
}
