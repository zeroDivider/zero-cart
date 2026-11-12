import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/list_form_sheet.dart';
import 'package:zero_cart/features/lists/ui/item_edit_sheet.dart';
import 'package:zero_cart/features/lists/ui/item_row.dart';
import 'package:zero_cart/features/lists/ui/list_screen.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/stores/ui/store_active_lists_section.dart';
import 'package:zero_cart/features/stores/ui/store_details_screen.dart';

import '../../support/test_app.dart';

Future<List<String>> _activeTitlesInOrder(
  WidgetTester tester,
  TestAppHarness harness,
  String listId,
) async {
  final rows = await tester.runAsync(
    () =>
        (harness.db.select(harness.db.listItems)
              ..where((t) => t.listId.equals(listId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.position),
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get(),
  );
  return [
    for (final row in rows!)
      if (!row.isPurchased) row.title,
  ];
}

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
  String? description,
}) async {
  final now = DateTime.utc(2026, 1, 1, 9);
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

Future<(Store, ShoppingList)> _seedList(
  WidgetTester tester,
  TestAppHarness harness, {
  String listName = 'Weekend',
}) async {
  final store = await tester.runAsync(
    () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
  );
  final list = await tester.runAsync(
    () => _lists(harness).create(storeId: store!.id, name: listName),
  );
  return (store!, list!);
}

Future<void> _openList(
  WidgetTester tester,
  TestAppHarness harness,
  Store store,
  ShoppingList list,
) async {
  await tester.tap(find.byKey(Key('store_row_${store.id}')));
  await pumpApp(tester, harness);
  await tester.tap(find.byKey(Key('store_list_card_${list.id}')));
  await pumpApp(tester, harness);
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
    expect(find.byType(ListScreen), findsOneWidget);
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

    expect(find.byType(ListScreen), findsOneWidget);

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

  testWidgets('list screen adds an item on Enter and keeps the add field', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final (store, list) = await _seedList(tester, harness);
    await pumpApp(tester, harness);
    await _openList(tester, harness, store, list);

    expect(find.byType(ListScreen), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.byKey(const Key('list_add_title')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('list_add_title')), 'Milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await pumpApp(tester, harness);

    expect(find.text('Milk'), findsWidgets);
    expect(find.byKey(const Key('list_add_title')), findsOneWidget);
    final addField = tester.widget<TextField>(
      find.byKey(const Key('list_add_title')),
    );
    expect(addField.controller?.text, isEmpty);

    final items = await tester.runAsync(
      () => (harness.db.select(
        harness.db.listItems,
      )..where((t) => t.listId.equals(list.id))).get(),
    );
    expect(items, hasLength(1));
    expect(items!.first.title, 'Milk');
    expect(items.first.position, 1);
    await harness.dispose(tester);
  });

  testWidgets('checking moves item to Purchased; unchecking restores place', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final (store, list) = await _seedList(tester, harness);
    await tester.runAsync(() async {
      await _insertItem(
        harness.db,
        id: 'a',
        listId: list.id,
        title: 'Milk',
        purchased: false,
        position: 1,
      );
      await _insertItem(
        harness.db,
        id: 'b',
        listId: list.id,
        title: 'Bread',
        purchased: false,
        position: 2,
      );
      await _insertItem(
        harness.db,
        id: 'c',
        listId: list.id,
        title: 'Eggs',
        purchased: false,
        position: 3,
      );
    });
    await pumpApp(tester, harness);
    await _openList(tester, harness, store, list);

    await tester.tap(find.byKey(const Key('item_checkbox_b')));
    await pumpApp(tester, harness);

    expect(find.text('Purchased (1)'), findsOneWidget);
    expect(find.byKey(const Key('item_handle_b')), findsNothing);

    final purchased = await tester.runAsync(
      () => (harness.db.select(
        harness.db.listItems,
      )..where((t) => t.id.equals('b'))).getSingle(),
    );
    expect(purchased!.isPurchased, isTrue);
    expect(purchased.position, 2);

    await tester.tap(find.byKey(const Key('item_checkbox_b')));
    await pumpApp(tester, harness);

    final unchecked = await tester.runAsync(
      () => (harness.db.select(
        harness.db.listItems,
      )..where((t) => t.id.equals('b'))).getSingle(),
    );
    expect(unchecked!.isPurchased, isFalse);
    expect(unchecked.position, 2);
    expect(find.byKey(const Key('item_handle_b')), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('edit sheet Save updates title and description', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final (store, list) = await _seedList(tester, harness);
    await tester.runAsync(() async {
      await _insertItem(
        harness.db,
        id: 'milk',
        listId: list.id,
        title: 'Milk',
        description: '1L',
        purchased: false,
        position: 1,
      );
    });
    await pumpApp(tester, harness);
    await _openList(tester, harness, store, list);

    await tester.tap(find.byKey(const Key('item_content_milk')));
    await pumpApp(tester, harness);
    expect(find.byType(ItemEditSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('item_edit_title')),
      'Oat milk',
    );
    await tester.enterText(
      find.byKey(const Key('item_edit_description')),
      '2L lactose-free',
    );
    await _tapButton(tester, const Key('item_edit_save'), harness);

    expect(find.byType(ItemEditSheet), findsNothing);
    expect(find.text('Oat milk'), findsOneWidget);
    expect(find.text('2L lactose-free'), findsOneWidget);

    final row = await tester.runAsync(
      () => (harness.db.select(
        harness.db.listItems,
      )..where((t) => t.id.equals('milk'))).getSingle(),
    );
    expect(row!.title, 'Oat milk');
    expect(row.description, '2L lactose-free');
    await harness.dispose(tester);
  });

  testWidgets('Purchased section collapses and expands', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final (store, list) = await _seedList(tester, harness);
    await tester.runAsync(() async {
      await _insertItem(
        harness.db,
        id: 'active',
        listId: list.id,
        title: 'Milk',
        purchased: false,
        position: 1,
      );
      await _insertItem(
        harness.db,
        id: 'done',
        listId: list.id,
        title: 'Bread',
        purchased: true,
        position: 2,
      );
    });
    await pumpApp(tester, harness);
    await _openList(tester, harness, store, list);

    expect(find.text('Purchased (1)'), findsOneWidget);
    expect(find.byKey(const Key('item_content_done')), findsOneWidget);

    await tester.tap(find.byKey(const Key('purchased_section_header')));
    await pumpApp(tester, harness);
    expect(find.byKey(const Key('item_content_done')), findsNothing);
    expect(find.text('Purchased (1)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('purchased_section_header')));
    await pumpApp(tester, harness);
    expect(find.byKey(const Key('item_content_done')), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('archive error shows snackbar', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final (store, list) = await _seedList(tester, harness);
    await pumpApp(tester, harness);
    await _openList(tester, harness, store, list);

    // Bridged streams keep the screen; closing the DB makes archive fail.
    await tester.runAsync(harness.db.close);

    final menu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('list_menu')),
    );
    menu.onSelected!('archive');
    await pumpApp(tester);

    expect(find.text("Couldn't archive. Try again."), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('archived list hides the add row', (tester) async {
    const listId = 'archived-list';
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(
        initialLocation: AppRoutes.listDetailsLocation(listId),
      ),
    );
    await tester.runAsync(() async {
      final store = await _stores(harness)
          .create(name: 'Lidl', colorKey: 'lime');
      await harness.db
          .into(harness.db.shoppingLists)
          .insert(
            ShoppingListsCompanion.insert(
              id: listId,
              storeId: store.id,
              name: 'Weekend',
              archivedAt: Value(DateTime.utc(2026, 1, 1, 14)),
              archiveReason: const Value('manual'),
              createdAt: DateTime.utc(2026, 1, 1, 13),
              updatedAt: DateTime.utc(2026, 1, 1, 14),
            ),
          );
      await _insertItem(
        harness.db,
        id: 'milk',
        listId: listId,
        title: 'Milk',
        purchased: false,
        position: 1,
      );
    });
    await pumpApp(tester, harness);

    expect(find.byType(ListScreen), findsOneWidget);
    expect(find.text('Weekend'), findsOneWidget);
    expect(find.byKey(const Key('list_add_title')), findsNothing);
    expect(find.byKey(const Key('item_checkbox_milk')), findsNothing);
    expect(find.byKey(const Key('list_menu')), findsNothing);
    await harness.dispose(tester);
  });

  testWidgets('drag handle moves an active item and leaves purchased fixed', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final (store, list) = await _seedList(tester, harness);
    await tester.runAsync(() async {
      await _insertItem(
        harness.db,
        id: 'a',
        listId: list.id,
        title: 'Alpha',
        purchased: false,
        position: 1,
      );
      await _insertItem(
        harness.db,
        id: 'b',
        listId: list.id,
        title: 'Bravo',
        purchased: false,
        position: 2,
      );
      await _insertItem(
        harness.db,
        id: 'c',
        listId: list.id,
        title: 'Charlie',
        purchased: false,
        position: 3,
      );
      await _insertItem(
        harness.db,
        id: 'p',
        listId: list.id,
        title: 'Purchased',
        purchased: true,
        position: 4,
      );
    });
    await pumpApp(tester, harness);
    await _openList(tester, harness, store, list);

    await tester.drag(
      find.byKey(const Key('item_handle_c')),
      const Offset(0, -320),
    );
    await tester.pumpAndSettle();
    await pumpApp(tester, harness);

    final afterDrag = await _activeTitlesInOrder(tester, harness, list.id);
    expect(afterDrag, ['Charlie', 'Alpha', 'Bravo']);
    expect(find.byKey(const Key('item_handle_p')), findsNothing);

    final purchasedPos = await tester.runAsync(
      () => (harness.db.select(
        harness.db.listItems,
      )..where((t) => t.id.equals('p'))).getSingle(),
    );
    expect(purchasedPos!.position, 4);

    await pumpApp(tester, harness);
    expect(await _activeTitlesInOrder(tester, harness, list.id), afterDrag);
    await harness.dispose(tester);
  });

  testWidgets('Move up and Move down cover top middle and bottom slots', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final harness = await pumpTestApp(
        tester,
        router: AppRouter.create(initialLocation: AppRoutes.stores),
      );
      final (store, list) = await _seedList(tester, harness);
      await tester.runAsync(() async {
        await _insertItem(
          harness.db,
          id: 'a',
          listId: list.id,
          title: 'Alpha',
          purchased: false,
          position: 1,
        );
        await _insertItem(
          harness.db,
          id: 'b',
          listId: list.id,
          title: 'Bravo',
          purchased: false,
          position: 2,
        );
        await _insertItem(
          harness.db,
          id: 'c',
          listId: list.id,
          title: 'Charlie',
          purchased: false,
          position: 3,
        );
      });
      await pumpApp(tester, harness);
      await _openList(tester, harness, store, list);

      List<String?> actionLabels(SemanticsNode node) => [
        for (final id
            in node.getSemanticsData().customSemanticsActionIds ??
                const <int>[])
          CustomSemanticsAction.getAction(id)?.label,
      ];

      Future<void> performMove(Finder rowFinder, String label) async {
        final node = tester.getSemantics(rowFinder);
        final actionId = CustomSemanticsAction.getIdentifier(
          CustomSemanticsAction(label: label),
        );
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          actionId,
        );
        await pumpApp(tester, harness);
      }

      final firstRow = tester.getSemantics(find.byType(ItemRow).at(0));
      expect(actionLabels(firstRow), isNot(contains('Move up')));
      expect(actionLabels(firstRow), contains('Move down'));

      final lastRow = tester.getSemantics(find.byType(ItemRow).at(2));
      expect(actionLabels(lastRow), contains('Move up'));
      expect(actionLabels(lastRow), isNot(contains('Move down')));

      await performMove(find.byType(ItemRow).at(2), 'Move up');
      await performMove(find.byType(ItemRow).at(1), 'Move up');
      expect(await _activeTitlesInOrder(tester, harness, list.id), [
        'Charlie',
        'Alpha',
        'Bravo',
      ]);

      await performMove(find.byType(ItemRow).at(0), 'Move down');
      expect(await _activeTitlesInOrder(tester, harness, list.id), [
        'Alpha',
        'Charlie',
        'Bravo',
      ]);

      await performMove(find.byType(ItemRow).at(1), 'Move down');
      expect(await _activeTitlesInOrder(tester, harness, list.id), [
        'Alpha',
        'Bravo',
        'Charlie',
      ]);
      await harness.dispose(tester);
    } finally {
      handle.dispose();
    }
  });
}
