import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/features/home/ui/home_screen.dart';
import 'package:zero_cart/features/home/ui/store_card.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';
import 'package:zero_cart/features/inbox/ui/inbox_screen.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';
import 'package:zero_cart/features/stores/ui/store_details_screen.dart';

import '../../support/test_app.dart';

StoresRepository _stores(TestAppHarness harness) {
  return StoresRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12),
    newId: () => 'store-${harness.db.hashCode}',
  );
}

ListsRepository _lists(TestAppHarness harness, {int start = 1}) {
  var n = start;
  return ListsRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 2, n),
    newId: () {
      final id = 'list-$n';
      n += 1;
      return id;
    },
  );
}

InboxRepository _inbox(TestAppHarness harness) {
  var n = 0;
  return InboxRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 13, n),
    newId: () {
      n += 1;
      return 'inbox-$n';
    },
  );
}

Future<void> _seedStoreWithItems(
  WidgetTester tester,
  TestAppHarness harness, {
  required String name,
  required String colorKey,
  required String storeId,
  required DateTime listUpdatedAt,
  int unpurchased = 0,
  int purchased = 0,
}) async {
  await tester.runAsync(() async {
    final stores = StoresRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 10),
      newId: () => storeId,
    );
    final store = await stores.create(name: name, colorKey: colorKey);
    var idTick = 0;
    final lists = ListsRepository(
      database: harness.db,
      now: () => listUpdatedAt,
      newId: () {
        idTick += 1;
        return '$storeId-list-$idTick';
      },
    );
    final list = await lists.create(storeId: store.id, name: 'Cart');
    for (var i = 0; i < unpurchased; i++) {
      await lists.addItem(listId: list.id, title: 'Left $i');
    }
    for (var i = 0; i < purchased; i++) {
      final item = await lists.addItem(listId: list.id, title: 'Done $i');
      await lists.setPurchased(item.id, true);
    }
  });
}

void main() {
  testWidgets('empty Home shows Create a store and opens store form', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);

    expect(find.text('No stores yet'), findsOneWidget);
    expect(find.byKey(const Key('home_empty_create')), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_empty_create')));
    await pumpApp(tester, harness);

    expect(find.byType(StoreFormSheet), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('Inbox pill appears only when Inbox has items and opens Inbox', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);

    expect(find.byKey(const Key('home_inbox_pill')), findsNothing);

    await tester.runAsync(() => _inbox(harness).add(title: 'Milk'));
    await pumpApp(tester, harness);

    expect(find.byKey(const Key('home_inbox_pill')), findsOneWidget);
    expect(find.textContaining('in Inbox'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_inbox_pill')));
    await pumpApp(tester, harness);

    expect(find.byType(InboxScreen), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('Inbox pill caps at phone width on a wide screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = await pumpTestApp(tester);
    await tester.runAsync(() => _inbox(harness).add(title: 'Milk'));
    await pumpApp(tester, harness);

    final pillWidth = tester
        .getSize(find.byKey(const Key('home_inbox_pill')))
        .width;
    expect(pillWidth, 400);
    await harness.dispose(tester);
  });

  testWidgets('store card tap opens store details', (tester) async {
    final harness = await pumpTestApp(tester);
    await _seedStoreWithItems(
      tester,
      harness,
      name: 'Lidl',
      colorKey: 'lime',
      storeId: 'store-lidl',
      listUpdatedAt: DateTime.utc(2026, 1, 3),
      unpurchased: 2,
    );
    await pumpApp(tester, harness);

    expect(find.byType(StoreCard), findsOneWidget);
    expect(find.text('Lidl'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('left to buy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home_store_card_store-lidl')));
    await pumpApp(tester, harness);

    expect(find.byType(StoreDetailsScreen), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('card labels cover empty cart and no lists yet', (tester) async {
    final harness = await pumpTestApp(tester);

    await tester.runAsync(() async {
      final empty = await _stores(harness)
          .create(name: 'Empty', colorKey: 'sky');
      final full = await StoresRepository(
        database: harness.db,
        now: () => DateTime.utc(2026, 1, 1, 11),
        newId: () => 'store-full',
      ).create(name: 'Full', colorKey: 'tomato');
      final lists = _lists(harness);
      final list = await lists.create(storeId: full.id, name: 'Done');
      final item = await lists.addItem(listId: list.id, title: 'Bought');
      await lists.setPurchased(item.id, true);
      expect(empty.name, 'Empty');
    });
    await pumpApp(tester, harness);

    expect(find.text('no lists yet'), findsOneWidget);
    expect(find.text('cart is empty'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('Home has no list shortcut affordances', (tester) async {
    final harness = await pumpTestApp(tester);
    await _seedStoreWithItems(
      tester,
      harness,
      name: 'Lidl',
      colorKey: 'lime',
      storeId: 'store-lidl',
      listUpdatedAt: DateTime.utc(2026, 1, 3),
      unpurchased: 1,
    );
    await pumpApp(tester, harness);

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Open list'), findsNothing);
    expect(find.textContaining('active list'), findsNothing);
    await harness.dispose(tester);
  });

  testWidgets('text scale above 1.3 stacks cards in one column', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    await _seedStoreWithItems(
      tester,
      harness,
      name: 'A',
      colorKey: 'lime',
      storeId: 'store-a',
      listUpdatedAt: DateTime.utc(2026, 1, 4),
      unpurchased: 1,
    );
    await _seedStoreWithItems(
      tester,
      harness,
      name: 'B',
      colorKey: 'sky',
      storeId: 'store-b',
      listUpdatedAt: DateTime.utc(2026, 1, 3),
      unpurchased: 0,
      purchased: 1,
    );
    await pumpApp(tester, harness);

    final twoColA = tester.getRect(
      find.byKey(const Key('home_store_card_store-a')),
    );
    final twoColB = tester.getRect(
      find.byKey(const Key('home_store_card_store-b')),
    );
    expect(twoColA.left, isNot(twoColB.left));

    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();

    final oneColA = tester.getRect(
      find.byKey(const Key('home_store_card_store-a')),
    );
    final oneColB = tester.getRect(
      find.byKey(const Key('home_store_card_store-b')),
    );
    expect(oneColA.left, oneColB.left);
    await harness.dispose(tester);
  });

  testWidgets('large text scale keeps cards readable without overflow', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    await _seedStoreWithItems(
      tester,
      harness,
      name: 'Very Long Store Name For Wrap',
      colorKey: 'lime',
      storeId: 'store-long',
      listUpdatedAt: DateTime.utc(2026, 1, 3),
      unpurchased: 12,
    );
    await pumpApp(tester, harness);

    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(StoreCard), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('store card semantics include name, left count and lists', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    await _seedStoreWithItems(
      tester,
      harness,
      name: 'Lidl',
      colorKey: 'lime',
      storeId: 'store-lidl',
      listUpdatedAt: DateTime.utc(2026, 1, 3),
      unpurchased: 3,
    );
    await pumpApp(tester, harness);

    expect(find.bySemanticsLabel('Lidl, 3 left, 1 list'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('settings icon still opens settings from Home', (tester) async {
    final harness = await pumpTestApp(tester);

    await tester.tap(find.byKey(const Key('home_settings_button')));
    await pumpApp(tester, harness);

    expect(find.text('Settings'), findsWidgets);
    await harness.dispose(tester);
  });
}
