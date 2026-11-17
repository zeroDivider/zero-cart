import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/lists/finish_list_result.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/ui/item_row.dart';
import 'package:zero_cart/features/lists/ui/list_screen.dart';
import 'package:zero_cart/features/lists/ui/sheets/finish_list_sheet.dart';
import 'package:zero_cart/features/lists/ui/sheets/item_edit_sheet.dart';
import 'package:zero_cart/features/lists/ui/sheets/list_form_sheet.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

import '../../support/test_app.dart';

const _genericError = 'Something went wrong. Try again.';

class _ThrowingListsRepository extends ListsRepository {
  _ThrowingListsRepository({
    required super.database,
    required super.now,
    required super.newId,
    this.throwOnCreate = false,
    this.throwOnRename = false,
    this.throwOnArchive = false,
    this.throwOnFinishList = false,
    this.throwOnRestore = false,
    this.throwOnSetPurchased = false,
    this.throwOnAddItem = false,
    this.throwOnUpdateItem = false,
    this.throwOnRemoveItem = false,
    this.throwOnRestoreItem = false,
    this.throwOnReorder = false,
  });

  final bool throwOnCreate;
  final bool throwOnRename;
  final bool throwOnArchive;
  final bool throwOnFinishList;
  final bool throwOnRestore;
  final bool throwOnSetPurchased;
  final bool throwOnAddItem;
  final bool throwOnUpdateItem;
  final bool throwOnRemoveItem;
  final bool throwOnRestoreItem;
  final bool throwOnReorder;

  @override
  Future<ShoppingList> create({required String storeId, required String name}) {
    if (throwOnCreate) {
      throw Exception('create failed');
    }
    return super.create(storeId: storeId, name: name);
  }

  @override
  Future<ShoppingList> rename({required String id, required String name}) {
    if (throwOnRename) {
      throw Exception('rename failed');
    }
    return super.rename(id: id, name: name);
  }

  @override
  Future<void> archive(String id) async {
    if (throwOnArchive) {
      throw Exception('archive failed');
    }
    await super.archive(id);
  }

  @override
  Future<FinishListResult> finishList(
    String listId, {
    required bool carryForward,
    String? newName,
  }) {
    if (throwOnFinishList) {
      throw Exception('finish failed');
    }
    return super.finishList(
      listId,
      carryForward: carryForward,
      newName: newName,
    );
  }

  @override
  Future<void> restore(String id) async {
    if (throwOnRestore) {
      throw Exception('restore failed');
    }
    await super.restore(id);
  }

  @override
  Future<void> setPurchased(String id, bool isPurchased) {
    if (throwOnSetPurchased) {
      throw Exception('purchase failed');
    }
    return super.setPurchased(id, isPurchased);
  }

  @override
  Future<ListItem> addItem({
    required String listId,
    required String title,
    String? description,
  }) {
    if (throwOnAddItem) {
      throw Exception('add item failed');
    }
    return super.addItem(
      listId: listId,
      title: title,
      description: description,
    );
  }

  @override
  Future<ListItem> updateItem({
    required String id,
    required String title,
    String? description,
  }) {
    if (throwOnUpdateItem) {
      throw Exception('update item failed');
    }
    return super.updateItem(id: id, title: title, description: description);
  }

  @override
  Future<ListItem> removeItem(String id) {
    if (throwOnRemoveItem) {
      throw Exception('remove item failed');
    }
    return super.removeItem(id);
  }

  @override
  Future<void> restoreItem(ListItem snapshot) async {
    if (throwOnRestoreItem) {
      throw Exception('restore item failed');
    }
    await super.restoreItem(snapshot);
  }

  @override
  Future<void> reorderActive(String listId, List<String> orderedActiveIds) {
    if (throwOnReorder) {
      throw Exception('reorder failed');
    }
    return super.reorderActive(listId, orderedActiveIds);
  }
}

StoresRepository _stores(TestAppHarness harness) {
  return StoresRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12),
    newId: () => 'seed-store',
  );
}

ListsRepository _lists(TestAppHarness harness) {
  return ListsRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12),
    newId: () => 'seed-list',
  );
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

List<Override> _throwingListsOverrides({
  bool throwOnCreate = false,
  bool throwOnRename = false,
  bool throwOnArchive = false,
  bool throwOnFinishList = false,
  bool throwOnRestore = false,
  bool throwOnSetPurchased = false,
  bool throwOnAddItem = false,
  bool throwOnUpdateItem = false,
  bool throwOnRemoveItem = false,
  bool throwOnRestoreItem = false,
  bool throwOnReorder = false,
}) {
  return [
    listsRepositoryProvider.overrideWith((ref) {
      return _ThrowingListsRepository(
        database: ref.watch(appDatabaseProvider),
        now: ref.watch(nowProvider),
        newId: ref.watch(idGeneratorProvider),
        throwOnCreate: throwOnCreate,
        throwOnRename: throwOnRename,
        throwOnArchive: throwOnArchive,
        throwOnFinishList: throwOnFinishList,
        throwOnRestore: throwOnRestore,
        throwOnSetPurchased: throwOnSetPurchased,
        throwOnAddItem: throwOnAddItem,
        throwOnUpdateItem: throwOnUpdateItem,
        throwOnRemoveItem: throwOnRemoveItem,
        throwOnRestoreItem: throwOnRestoreItem,
        throwOnReorder: throwOnReorder,
      );
    }),
  ];
}

void main() {
  testWidgets('list create failure keeps sheet open with inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnCreate: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_details_new_list'), harness);
    await tester.enterText(find.byKey(const Key('list_form_name')), 'Weekend');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('list_form_save'), harness);

    expect(find.byType(ListFormSheet<ShoppingList>), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);

    final lists = await tester.runAsync(
      () => harness.db.select(harness.db.shoppingLists).get(),
    );
    expect(lists, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets('list rename failure keeps sheet open with inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnRename: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    final renameMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('list_menu')),
    );
    renameMenu.onSelected!('rename');
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('list_form_name')), 'Party');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('list_form_save'), harness);

    expect(find.text(_genericError), findsOneWidget);
    expect(find.text('Rename list'), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.shoppingLists).getSingle(),
    );
    expect(row!.name, 'Weekend');
    await harness.dispose(tester);
  });

  testWidgets('list archive failure shows error snackbar', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnArchive: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    final archiveMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('list_menu')),
    );
    archiveMenu.onSelected!('archive');
    await pumpApp(tester, harness);
    expect(find.byKey(const Key('archive_list_dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('archive_list_confirm')));
    await pumpApp(tester, harness);

    expect(find.text(_genericError), findsOneWidget);
    expect(find.text('Weekend'), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.shoppingLists).getSingle(),
    );
    expect(row!.archivedAt, isNull);
    await harness.dispose(tester);
  });

  testWidgets('purchase toggle failure shows error snackbar', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnSetPurchased: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await tester.runAsync(() async {
      final now = DateTime.utc(2026, 1, 1, 10);
      await harness.db
          .into(harness.db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              listId: list!.id,
              title: 'Milk',
              isPurchased: const Value(false),
              position: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('item_checkbox_item-1')));
    await pumpApp(tester, harness);

    expect(find.text(_genericError), findsOneWidget);

    final item = await tester.runAsync(
      () => harness.db.select(harness.db.listItems).getSingle(),
    );
    expect(item!.isPurchased, isFalse);
    await harness.dispose(tester);
  });

  testWidgets('add item failure keeps text and shows inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnAddItem: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await tester.enterText(find.byKey(const Key('list_add_title')), 'Milk');
    await pumpApp(tester, harness);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumpApp(tester, harness);

    expect(find.text(_genericError), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('list_add_title')))
          .controller!
          .text,
      'Milk',
    );
    final items = await tester.runAsync(
      () => harness.db.select(harness.db.listItems).get(),
    );
    expect(items, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets('item edit save failure keeps sheet open with inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnUpdateItem: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await tester.runAsync(() async {
      final now = DateTime.utc(2026, 1, 1, 10);
      await harness.db
          .into(harness.db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              listId: list!.id,
              title: 'Milk',
              isPurchased: const Value(false),
              position: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('item_content_item-1')));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('item_edit_title')), 'Eggs');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('item_edit_save'), harness);

    expect(find.byType(ItemEditSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);

    final item = await tester.runAsync(
      () => harness.db.select(harness.db.listItems).getSingle(),
    );
    expect(item!.title, 'Milk');
    await harness.dispose(tester);
  });

  testWidgets('item remove failure shows error snackbar', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnRemoveItem: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await tester.runAsync(() async {
      final now = DateTime.utc(2026, 1, 1, 10);
      await harness.db
          .into(harness.db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              listId: list!.id,
              title: 'Milk',
              isPurchased: const Value(false),
              position: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('item_content_item-1')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('item_edit_remove'), harness);

    expect(find.text(_genericError), findsOneWidget);
    expect(find.textContaining('Removed'), findsNothing);

    final items = await tester.runAsync(
      () => harness.db.select(harness.db.listItems).get(),
    );
    expect(items, hasLength(1));
    await harness.dispose(tester);
  });

  testWidgets('item failed Undo shows messageFor immediately', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnRestoreItem: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await tester.runAsync(() async {
      final now = DateTime.utc(2026, 1, 1, 10);
      await harness.db
          .into(harness.db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'item-1',
              listId: list!.id,
              title: 'Milk',
              isPurchased: const Value(false),
              position: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('item_content_item-1')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('item_edit_remove'), harness);
    expect(find.text('Removed Milk'), findsOneWidget);

    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    action.onPressed();
    await tester.pumpAndSettle();

    expect(find.text('Removed Milk'), findsNothing);
    expect(find.text(_genericError), findsOneWidget);
    final items = await tester.runAsync(
      () => harness.db.select(harness.db.listItems).get(),
    );
    expect(items, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets(
    'reorder failure shows error snackbar and drops optimistic order',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final harness = await pumpTestApp(
          tester,
          router: AppRouter.create(initialLocation: AppRoutes.stores),
          overrides: _throwingListsOverrides(throwOnReorder: true),
        );
        final store = await tester.runAsync(
          () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
        );
        final list = await tester.runAsync(
          () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
        );
        await tester.runAsync(() async {
          final now = DateTime.utc(2026, 1, 1, 10);
          await harness.db
              .into(harness.db.listItems)
              .insert(
                ListItemsCompanion.insert(
                  id: 'a',
                  listId: list!.id,
                  title: 'Alpha',
                  isPurchased: const Value(false),
                  position: 1,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await harness.db
              .into(harness.db.listItems)
              .insert(
                ListItemsCompanion.insert(
                  id: 'b',
                  listId: list.id,
                  title: 'Bravo',
                  isPurchased: const Value(false),
                  position: 2,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        });
        await pumpApp(tester, harness);

        await tester.tap(find.byKey(Key('store_row_${store!.id}')));
        await pumpApp(tester, harness);
        await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
        await pumpApp(tester, harness);

        final node = tester.getSemantics(find.byType(ItemRow).at(1));
        final actionId = CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move up'),
        );
        node.owner!.performAction(
          node.id,
          SemanticsAction.customAction,
          actionId,
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await pumpApp(tester, harness);

        expect(find.text(_genericError), findsOneWidget);
        // UI order follows DB again after optimistic drop.
        expect(find.text('Alpha'), findsOneWidget);
        expect(find.text('Bravo'), findsOneWidget);
        final titles = find.byType(ItemRow).evaluate().map((e) {
          final row = e.widget as ItemRow;
          return row.item.title;
        }).toList();
        expect(titles, ['Alpha', 'Bravo']);

        final positions = await tester.runAsync(
          () => harness.db.select(harness.db.listItems).get(),
        );
        expect(
          {for (final row in positions!) row.id: row.position},
          {'a': 1, 'b': 2},
        );
        await harness.dispose(tester);
      } finally {
        handle.dispose();
      }
    },
  );

  testWidgets('finish carry-forward failure keeps sheet open; list active', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnFinishList: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await tester.runAsync(() async {
      final now = DateTime.utc(2026, 1, 1, 10);
      await harness.db
          .into(harness.db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'milk',
              listId: list!.id,
              title: 'Milk',
              isPurchased: const Value(false),
              position: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await _tapButton(tester, const Key('list_finish'), harness);
    expect(find.byType(FinishListSheet), findsOneWidget);
    await _tapButton(tester, const Key('finish_carry_forward'), harness);

    expect(find.byType(FinishListSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);
    expect(find.byType(ListScreen), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.shoppingLists).getSingle(),
    );
    expect(row!.archivedAt, isNull);
    await harness.dispose(tester);
  });

  testWidgets('finish archive-without failure keeps sheet open; list active', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnFinishList: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await tester.runAsync(() async {
      final now = DateTime.utc(2026, 1, 1, 10);
      await harness.db
          .into(harness.db.listItems)
          .insert(
            ListItemsCompanion.insert(
              id: 'milk',
              listId: list!.id,
              title: 'Milk',
              isPurchased: const Value(false),
              position: 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await _tapButton(tester, const Key('list_finish'), harness);
    expect(find.byType(FinishListSheet), findsOneWidget);
    await _tapButton(tester, const Key('finish_archive_without'), harness);

    expect(find.byType(FinishListSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.shoppingLists).getSingle(),
    );
    expect(row!.archivedAt, isNull);
    await harness.dispose(tester);
  });

  testWidgets('zero-leftover Finish failure shows snackbar; list active', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingListsOverrides(throwOnFinishList: true),
    );
    final store = await tester.runAsync(
      () => _stores(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    final list = await tester.runAsync(
      () => _lists(harness).create(storeId: store!.id, name: 'Weekend'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('store_list_card_${list!.id}')));
    await pumpApp(tester, harness);

    await _tapButton(tester, const Key('list_finish'), harness);
    expect(find.byType(FinishListSheet), findsNothing);
    expect(find.byType(ListScreen), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.shoppingLists).getSingle(),
    );
    expect(row!.archivedAt, isNull);
    await harness.dispose(tester);
  });
}
