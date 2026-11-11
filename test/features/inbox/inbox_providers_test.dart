import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';

/// Proves live Drift `.watch()` → [inboxItemsProvider] without the widget
/// harness stream bridge in [pumpTestApp].
void main() {
  test('inboxItemsProvider emits after repository write', () async {
    final db = AppDatabase.memory();
    var idCounter = 0;
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 1, 1, 12)),
        idGeneratorProvider.overrideWithValue(() {
          idCounter += 1;
          return 'live-id-$idCounter';
        }),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final events = <AsyncValue<List<InboxItem>>>[];
    final sub = container.listen(inboxItemsProvider, (previous, next) {
      events.add(next);
    }, fireImmediately: true);
    addTearDown(sub.close);

    await pumpEventQueue();
    expect(container.read(inboxItemsProvider).value, isEmpty);

    await container.read(inboxRepositoryProvider).add(title: 'Milk');
    await pumpEventQueue();

    final latest = container.read(inboxItemsProvider);
    expect(latest.hasValue, isTrue);
    expect(latest.value!.single.title, 'Milk');
    expect(events.where((e) => e.hasValue && e.value!.isNotEmpty), isNotEmpty);
  });
}
