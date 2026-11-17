import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/wishlist/wishlist_repository.dart';

void main() {
  late AppDatabase db;
  late List<DateTime> clockTicks;
  late int idCounter;
  late StoresRepository stores;
  late WishlistRepository wishlist;

  setUp(() {
    db = AppDatabase.memory();
    clockTicks = <DateTime>[
      for (var i = 0; i < 40; i++) DateTime.utc(2026, 1, 1, 12, i),
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
    wishlist = WishlistRepository(database: db, now: nextClock, newId: nextId);
  });

  tearDown(() async {
    await db.close();
  });

  test('watch emits oldest first and reacts to writes', () async {
    final store = await stores.create(name: 'DM', colorKey: 'sky');
    final events = <List<WishlistItem>>[];
    final sub = wishlist.watch(store.id).listen(events.add);

    final older = await wishlist.add(storeId: store.id, title: 'Older');
    await pumpEventQueue();
    final newer = await wishlist.add(storeId: store.id, title: 'Newer');
    await pumpEventQueue();

    expect(events.last.map((e) => e.id), [older.id, newer.id]);

    await wishlist.update(
      id: older.id,
      title: 'Older edited',
      description: 'note',
    );
    await pumpEventQueue();
    expect(
      events.last.firstWhere((e) => e.id == older.id).title,
      'Older edited',
    );
    expect(events.last.map((e) => e.id), [older.id, newer.id]);

    final snapshot = await wishlist.remove(newer.id);
    await pumpEventQueue();
    expect(snapshot.id, newer.id);
    expect(events.last.map((e) => e.id), [older.id]);

    await wishlist.restore(snapshot);
    await pumpEventQueue();
    expect(events.last.map((e) => e.id), [older.id, newer.id]);

    await sub.cancel();
  });

  test('add normalizes and rejects empty title and archived store', () async {
    final store = await stores.create(name: 'DM', colorKey: 'sky');
    final item = await wishlist.add(
      storeId: store.id,
      title: '  Heads\nsoft  ',
      description: '  size\nM  ',
    );
    expect(item.title, 'Heads soft');
    expect(item.description, 'size M');
    expect(item.storeId, store.id);

    final blankDesc = await wishlist.add(
      storeId: store.id,
      title: 'Brush',
      description: '   ',
    );
    expect(blankDesc.description, isNull);

    await expectLater(
      () => wishlist.add(storeId: store.id, title: '   '),
      throwsA(isA<ArgumentError>()),
    );

    await stores.archive(store.id);
    await expectLater(
      () => wishlist.add(storeId: store.id, title: 'Nope'),
      throwsA(isA<StoreArchivedException>()),
    );
  });

  test(
    'update bumps updatedAt only and restore keeps original timestamps',
    () async {
      final store = await stores.create(name: 'DM', colorKey: 'sky');
      final created = await wishlist.add(
        storeId: store.id,
        title: 'Heads',
        description: 'soft',
      );
      final updated = await wishlist.update(
        id: created.id,
        title: 'Heads',
        description: 'firm',
      );
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
      expect(updated.description, 'firm');

      final snapshot = await wishlist.remove(created.id);
      expect(snapshot.createdAt, created.createdAt);
      expect(snapshot.updatedAt, updated.updatedAt);

      await wishlist.restore(snapshot);
      final restored = await db.select(db.wishlistItems).getSingle();
      expect(restored.id, snapshot.id);
      expect(restored.createdAt, snapshot.createdAt);
      expect(restored.updatedAt, snapshot.updatedAt);
      expect(restored.title, snapshot.title);
      expect(restored.description, snapshot.description);
    },
  );

  test('watchCount reflects inserts and deletes', () async {
    final store = await stores.create(name: 'DM', colorKey: 'sky');
    final counts = <int>[];
    final sub = wishlist.watchCount(store.id).listen(counts.add);

    await wishlist.add(storeId: store.id, title: 'A');
    await pumpEventQueue();
    await wishlist.add(storeId: store.id, title: 'B');
    await pumpEventQueue();
    expect(counts.last, 2);

    final first = (await wishlist.watch(store.id).first).first;
    await wishlist.remove(first.id);
    await pumpEventQueue();
    expect(counts.last, 1);

    await sub.cancel();
  });

  test(
    'update, remove and restore reject when the store is archived',
    () async {
      final store = await stores.create(name: 'DM', colorKey: 'sky');
      final item = await wishlist.add(storeId: store.id, title: 'Heads');

      await stores.archive(store.id);
      await expectLater(
        wishlist.update(id: item.id, title: 'Edited'),
        throwsA(isA<StoreArchivedException>()),
      );
      await expectLater(
        wishlist.remove(item.id),
        throwsA(isA<StoreArchivedException>()),
      );
      expect(await wishlist.watch(store.id).first, hasLength(1));

      await stores.restore(store.id);
      final snapshot = await wishlist.remove(item.id);
      await stores.archive(store.id);
      await expectLater(
        wishlist.restore(snapshot),
        throwsA(isA<StoreArchivedException>()),
      );
      expect(await db.select(db.wishlistItems).get(), isEmpty);
    },
  );
}
