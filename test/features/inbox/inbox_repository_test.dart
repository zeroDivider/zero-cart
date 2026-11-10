import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';

void main() {
  late AppDatabase db;
  late List<DateTime> clockTicks;
  late int idCounter;
  late InboxRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    clockTicks = <DateTime>[
      DateTime.utc(2026, 1, 1, 12),
      DateTime.utc(2026, 1, 1, 13),
      DateTime.utc(2026, 1, 1, 14),
      DateTime.utc(2026, 1, 1, 15),
      DateTime.utc(2026, 1, 1, 16),
    ];
    idCounter = 0;
    repo = InboxRepository(
      db: db,
      clock: () {
        if (clockTicks.isEmpty) {
          fail('clock exhausted');
        }
        return clockTicks.removeAt(0);
      },
      idGenerator: () {
        idCounter += 1;
        return 'id-$idCounter';
      },
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('watchAll emits newest first and reacts to writes', () async {
    final events = <List<InboxItem>>[];
    final sub = repo.watchAll().listen(events.add);

    final older = await repo.add(title: 'Older');
    await pumpEventQueue();
    final newer = await repo.add(title: 'Newer');
    await pumpEventQueue();

    expect(events.last.map((e) => e.id), [newer.id, older.id]);

    await repo.update(id: older.id, title: 'Older edited', description: 'note');
    await pumpEventQueue();
    expect(
      events.last.firstWhere((e) => e.id == older.id).title,
      'Older edited',
    );
    expect(events.last.map((e) => e.id), [newer.id, older.id]);

    final snapshot = await repo.remove(newer.id);
    await pumpEventQueue();
    expect(snapshot.id, newer.id);
    expect(events.last.map((e) => e.id), [older.id]);

    await repo.restore(snapshot);
    await pumpEventQueue();
    expect(events.last.map((e) => e.id), [newer.id, older.id]);

    await sub.cancel();
  });

  test(
    'add normalizes title and description and rejects empty title',
    () async {
      final item = await repo.add(
        title: '  Milk\n2L  ',
        description: '  lactose\nfree  ',
      );
      expect(item.id, 'id-1');
      expect(item.title, 'Milk 2L');
      expect(item.description, 'lactose free');
      expect(item.createdAt, DateTime.utc(2026, 1, 1, 12));
      expect(item.updatedAt, DateTime.utc(2026, 1, 1, 12));

      final blankDesc = await repo.add(title: 'Bread', description: '   ');
      expect(blankDesc.description, isNull);

      await expectLater(
        () => repo.add(title: '   '),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test(
    'update bumps updatedAt only and restore keeps original timestamps',
    () async {
      final created = await repo.add(title: 'Eggs', description: 'large');
      final updated = await repo.update(
        id: created.id,
        title: 'Eggs',
        description: 'medium',
      );
      expect(updated.createdAt, created.createdAt);
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
      expect(updated.description, 'medium');

      final snapshot = await repo.remove(created.id);
      expect(snapshot.createdAt, created.createdAt);
      expect(snapshot.updatedAt, updated.updatedAt);
      expect(snapshot.description, 'medium');

      await repo.restore(snapshot);
      final restored = await db.select(db.inboxItems).getSingle();
      expect(restored.id, snapshot.id);
      expect(restored.createdAt, snapshot.createdAt);
      expect(restored.updatedAt, snapshot.updatedAt);
      expect(restored.title, snapshot.title);
      expect(restored.description, snapshot.description);
    },
  );

  test('add clamps to title and description limits', () async {
    final longTitle = 'T' * 60;
    final longDesc = 'D' * 80;
    final item = await repo.add(title: longTitle, description: longDesc);
    expect(item.title.length, 50);
    expect(item.description!.length, 70);
  });
}
