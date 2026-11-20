import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

import '../../support/test_app.dart';

Future<void> _seedHomeBoard(WidgetTester tester, TestAppHarness harness) async {
  await tester.runAsync(() async {
    Future<void> addStore({
      required String id,
      required String name,
      required String colorKey,
      required DateTime listAt,
      required int left,
      required int bought,
    }) async {
      final stores = StoresRepository(
        database: harness.db,
        now: () => DateTime.utc(2026, 1, 1, 10),
        newId: () => id,
      );
      final store = await stores.create(name: name, colorKey: colorKey);
      var tick = 0;
      final lists = ListsRepository(
        database: harness.db,
        now: () => listAt,
        newId: () {
          tick += 1;
          return '$id-x-$tick';
        },
      );
      final list = await lists.create(storeId: store.id, name: 'Cart');
      for (var i = 0; i < left; i++) {
        await lists.addItem(listId: list.id, title: 'Item $i');
      }
      for (var i = 0; i < bought; i++) {
        final item = await lists.addItem(listId: list.id, title: 'Done $i');
        await lists.setPurchased(item.id, true);
      }
    }

    await addStore(
      id: 'store-1',
      name: 'Lidl',
      colorKey: 'lime',
      listAt: DateTime.utc(2026, 1, 5),
      left: 4,
      bought: 2,
    );
    await addStore(
      id: 'store-2',
      name: 'DM',
      colorKey: 'sky',
      listAt: DateTime.utc(2026, 1, 4),
      left: 0,
      bought: 3,
    );
    await addStore(
      id: 'store-3',
      name: 'Maxi',
      colorKey: 'tomato',
      listAt: DateTime.utc(2026, 1, 3),
      left: 1,
      bought: 0,
    );
    await StoresRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 9),
      newId: () => 'store-4',
    ).create(name: 'Idea', colorKey: 'lemon');
  });
}

void main() {
  testWidgets('Home board golden light', (tester) async {
    final harness = await pumpTestApp(tester, router: AppRouter.create());
    await _seedHomeBoard(tester, harness);
    await pumpApp(tester, harness);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_board_light.png'),
    );
    await harness.dispose(tester);
  }, tags: ['golden']);

  testWidgets('Home board golden dark', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final harness = await pumpTestApp(tester, router: AppRouter.create());
    await _seedHomeBoard(tester, harness);
    await pumpApp(tester, harness);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_board_dark.png'),
    );
    await harness.dispose(tester);
  }, tags: ['golden']);
}
