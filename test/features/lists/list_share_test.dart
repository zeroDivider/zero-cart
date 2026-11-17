import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/core/share_service.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

import '../../support/fake_share_service.dart';
import '../../support/test_app.dart';

const _genericError = 'Something went wrong. Try again.';
const _expectedShareText = 'Weekend groceries\nMilk - 2L, lactose-free\nBread';

StoresRepository _stores(TestAppHarness harness) {
  return StoresRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12),
    newId: () => 'store-seed',
  );
}

ListsRepository _lists(TestAppHarness harness) {
  var n = 0;
  return ListsRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 13, n++),
    newId: () => 'list-$n',
  );
}

Future<void> _insertItem(
  AppDatabase db, {
  required String id,
  required String listId,
  required String title,
  required bool purchased,
  required int position,
  String? description,
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

Future<void> _tapShare(WidgetTester tester, TestAppHarness harness) async {
  final button = tester.widget<IconButton>(find.byKey(const Key('list_share')));
  button.onPressed!.call();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await pumpApp(tester, harness);
  await tester.pump(const Duration(milliseconds: 300));
  await pumpApp(tester, harness);
}

void main() {
  testWidgets('share sends exact D-20 text and button origin', (tester) async {
    final fakeShare = FakeShareService();
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: [shareServiceProvider.overrideWithValue(fakeShare)],
    );

    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () =>
          _lists(harness).create(storeId: store!.id, name: 'Weekend groceries'),
    );
    await tester.runAsync(() async {
      await _insertItem(
        harness.db,
        id: 'item-milk',
        listId: list!.id,
        title: 'Milk',
        description: '2L, lactose-free',
        purchased: false,
        position: 1,
        createdAt: DateTime.utc(2026, 1, 1, 8),
      );
      await _insertItem(
        harness.db,
        id: 'item-pasta',
        listId: list.id,
        title: 'Pasta',
        description: 'Whole wheat, 500g',
        purchased: true,
        position: 2,
        createdAt: DateTime.utc(2026, 1, 1, 8, 1),
      );
      await _insertItem(
        harness.db,
        id: 'item-bread',
        listId: list.id,
        title: 'Bread',
        purchased: false,
        position: 3,
        createdAt: DateTime.utc(2026, 1, 1, 8, 2),
      );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    expect(find.byKey(const Key('list_share')), findsOneWidget);
    await _tapShare(tester, harness);

    expect(fakeShare.calls, hasLength(1));
    expect(fakeShare.calls.single.text, _expectedShareText);
    expect(fakeShare.calls.single.sharePositionOrigin, isNot(Rect.zero));
    expect(find.text('Nothing left to share'), findsNothing);

    await harness.dispose(tester);
  });

  testWidgets('share with nothing left shows info and skips sheet', (
    tester,
  ) async {
    final fakeShare = FakeShareService();
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: [shareServiceProvider.overrideWithValue(fakeShare)],
    );

    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () =>
          _lists(harness).create(storeId: store!.id, name: 'Weekend groceries'),
    );
    await tester.runAsync(() async {
      await _insertItem(
        harness.db,
        id: 'item-pasta',
        listId: list!.id,
        title: 'Pasta',
        purchased: true,
        position: 1,
      );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await _tapShare(tester, harness);

    expect(fakeShare.calls, isEmpty);
    expect(find.text('Nothing left to share'), findsOneWidget);

    await harness.dispose(tester);
  });

  testWidgets('share failure shows generic error snackbar', (tester) async {
    final fakeShare = FakeShareService()
      ..errorToThrow = Exception('share failed');
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: [shareServiceProvider.overrideWithValue(fakeShare)],
    );

    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await tester.runAsync(() async {
      await _insertItem(
        harness.db,
        id: 'item-milk',
        listId: list!.id,
        title: 'Milk',
        purchased: false,
        position: 1,
      );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await _tapShare(tester, harness);

    expect(fakeShare.calls, isEmpty);
    expect(find.text(_genericError), findsOneWidget);

    await harness.dispose(tester);
  });
}
