import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
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
    this.throwOnSetPurchased = false,
  });

  final bool throwOnCreate;
  final bool throwOnRename;
  final bool throwOnArchive;
  final bool throwOnSetPurchased;

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
  Future<void> setPurchased(String id, bool isPurchased) {
    if (throwOnSetPurchased) {
      throw Exception('purchase failed');
    }
    return super.setPurchased(id, isPurchased);
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
  bool throwOnSetPurchased = false,
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
        throwOnSetPurchased: throwOnSetPurchased,
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
}
