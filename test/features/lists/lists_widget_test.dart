import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/list_form_sheet.dart';
import 'package:zero_cart/features/lists/ui/list_placeholder_screen.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/stores/ui/store_active_lists_section.dart';
import 'package:zero_cart/features/stores/ui/store_details_screen.dart';

import '../../support/test_app.dart';

Future<void> _tapButton(
  WidgetTester tester,
  Key key,
  TestAppHarness harness,
) async {
  final widget = tester.widget<ButtonStyleButton>(find.byKey(key));
  widget.onPressed!.call();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await pumpApp(tester, harness);
  await tester.pump(const Duration(milliseconds: 300));
  await pumpApp(tester, harness);
}

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

void main() {
  testWidgets('store details shows list cards with items left', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
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
        id: 'item-1',
        listId: list!.id,
        title: 'Milk',
        purchased: false,
        position: 1,
      );
      await _insertItem(
        harness.db,
        id: 'item-2',
        listId: list.id,
        title: 'Bread',
        purchased: true,
        position: 2,
      );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);

    expect(find.byType(StoreDetailsScreen), findsOneWidget);
    expect(find.byType(StoreActiveListsSection), findsOneWidget);
    expect(find.text('Weekend'), findsOneWidget);
    expect(find.text('1 left'), findsOneWidget);
    expect(find.byKey(const Key('store_details_new_list')), findsOneWidget);

    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);
    expect(find.byType(ListPlaceholderScreen), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('creating a list from store details opens the list screen', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);

    await _tapButton(tester, const Key('store_details_new_list'), harness);
    expect(find.byType(ListFormSheet), findsOneWidget);
    expect(find.text('New list'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('list_form_name')), 'Party');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('list_form_save'), harness);

    expect(find.byType(ListPlaceholderScreen), findsOneWidget);

    final lists = await tester.runAsync(
      () => harness.db.select(harness.db.shoppingLists).get(),
    );
    expect(lists, hasLength(1));
    expect(lists!.first.name, 'Party');
    expect(lists.first.archivedAt, isNull);
    expect(lists.first.storeId, store.id);

    await tester.pageBack();
    await pumpApp(tester, harness);
    expect(find.text('Party'), findsOneWidget);
    expect(find.text('0 left'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('archived store details hide New list', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await tester.runAsync(() => _stores(harness).archive(store!.id));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('stores_archive')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('archived_store_row_${store!.id}')));
    await pumpApp(tester, harness);

    expect(find.byType(StoreDetailsScreen), findsOneWidget);
    expect(find.byKey(const Key('store_details_new_list')), findsNothing);
    expect(find.text('No active lists yet.'), findsOneWidget);
    await harness.dispose(tester);
  });
}
