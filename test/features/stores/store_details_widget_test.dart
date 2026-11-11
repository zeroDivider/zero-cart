import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/archive/ui/archive_screen.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/stores/ui/store_details_screen.dart';
import 'package:zero_cart/features/stores/ui/store_form_sheet.dart';
import 'package:zero_cart/features/stores/ui/stores_screen.dart';

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

StoresRepository _repo(TestAppHarness harness) {
  return StoresRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12),
    newId: () => 'store-seed',
  );
}

Future<void> insertActiveList(
  AppDatabase db, {
  required String id,
  required String storeId,
  required String name,
}) async {
  final now = DateTime.utc(2026, 1, 1, 10);
  await db
      .into(db.shoppingLists)
      .insert(
        ShoppingListsCompanion.insert(
          id: id,
          storeId: storeId,
          name: name,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  testWidgets('store details shows header and opens edit sheet', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () => _repo(harness).create(
        name: 'Lidl',
        colorKey: 'lime',
        address: 'Main St',
        note: 'Weekly',
      ),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);

    expect(find.byType(StoreDetailsScreen), findsOneWidget);
    expect(find.text('Lidl'), findsWidgets);
    expect(find.text('Main St'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Shopping lists'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);

    await _tapButton(tester, const Key('store_details_edit'), harness);
    expect(find.byType(StoreFormSheet), findsOneWidget);
    expect(find.text('Edit store'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('archive with no active lists archives immediately', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () => _repo(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);

    await _tapButton(tester, const Key('store_details_archive'), harness);

    expect(find.byKey(const Key('archive_store_dialog')), findsNothing);
    expect(find.byType(StoresScreen), findsOneWidget);
    expect(find.text('Lidl'), findsNothing);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(row!.archivedAt, isNotNull);
    await harness.dispose(tester);
  });

  testWidgets('archive with active lists shows dialog then archives', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () => _repo(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await tester.runAsync(
      () => insertActiveList(
        harness.db,
        id: 'list-1',
        storeId: store!.id,
        name: 'Weekend',
      ),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);

    await _tapButton(tester, const Key('store_details_archive'), harness);
    expect(find.byKey(const Key('archive_store_dialog')), findsOneWidget);
    expect(
      find.text('1 active list will be hidden until you restore the store.'),
      findsOneWidget,
    );

    await _tapButton(tester, const Key('archive_store_confirm'), harness);
    expect(find.byType(StoresScreen), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(row!.archivedAt, isNotNull);

    final list = await tester.runAsync(
      () => harness.db.select(harness.db.shoppingLists).getSingle(),
    );
    expect(list!.archivedAt, isNull);
    expect(list.name, 'Weekend');
    await harness.dispose(tester);
  });

  testWidgets('archive dialog uses plural copy for multiple lists', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () => _repo(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await tester.runAsync(() async {
      await insertActiveList(
        harness.db,
        id: 'list-1',
        storeId: store!.id,
        name: 'Weekend',
      );
      await insertActiveList(
        harness.db,
        id: 'list-2',
        storeId: store.id,
        name: 'Party',
      );
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_details_archive'), harness);

    expect(find.byKey(const Key('archive_store_dialog')), findsOneWidget);
    expect(
      find.text('2 active lists will be hidden until you restore the store.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await pumpApp(tester, harness);
    await harness.dispose(tester);
  });

  testWidgets('cancel archive dialog leaves store active', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () => _repo(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await tester.runAsync(
      () => insertActiveList(
        harness.db,
        id: 'list-1',
        storeId: store!.id,
        name: 'Weekend',
      ),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_details_archive'), harness);
    expect(find.byKey(const Key('archive_store_dialog')), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await pumpApp(tester, harness);

    expect(find.byType(StoreDetailsScreen), findsOneWidget);
    expect(find.byKey(const Key('store_details_archive')), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(row!.archivedAt, isNull);
    await harness.dispose(tester);
  });

  testWidgets('archived store details are read-only with Restore', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () =>
          _repo(harness)
              .create(name: 'Lidl', colorKey: 'lime', note: 'Keep me'),
    );
    await tester.runAsync(() => _repo(harness).archive(store!.id));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('stores_archive')));
    await pumpApp(tester, harness);
    expect(find.byType(ArchiveScreen), findsOneWidget);

    await tester.tap(find.byKey(Key('archived_store_row_${store!.id}')));
    await pumpApp(tester, harness);

    expect(find.byType(StoreDetailsScreen), findsOneWidget);
    expect(find.byKey(const Key('store_details_restore')), findsOneWidget);
    expect(find.byKey(const Key('store_details_edit')), findsNothing);
    expect(find.byKey(const Key('store_details_archive')), findsNothing);
    expect(find.text('Keep me'), findsOneWidget);

    await _tapButton(tester, const Key('store_details_restore'), harness);
    expect(find.byKey(const Key('store_details_edit')), findsOneWidget);
    expect(find.byKey(const Key('store_details_archive')), findsOneWidget);
    expect(find.byKey(const Key('store_details_restore')), findsNothing);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(row!.archivedAt, isNull);
    expect(row.note, 'Keep me');
    await harness.dispose(tester);
  });

  testWidgets('archive screen restores store from Stores segment', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final store = await tester.runAsync(
      () => _repo(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await tester.runAsync(() => _repo(harness).archive(store!.id));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('stores_archive')));
    await pumpApp(tester, harness);

    expect(find.text('Lidl'), findsOneWidget);
    await _tapButton(
      tester,
      Key('archived_store_restore_${store!.id}'),
      harness,
    );
    expect(find.text('No archived stores.'), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(row!.archivedAt, isNull);

    await tester.pageBack();
    await pumpApp(tester, harness);
    expect(find.text('Lidl'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('archive Lists segment shows placeholder', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.archive),
    );

    expect(find.byType(ArchiveScreen), findsOneWidget);
    expect(find.text('No archived stores.'), findsOneWidget);

    await tester.tap(find.text('Lists'));
    await pumpApp(tester, harness);
    expect(find.text('Archived lists will show here.'), findsOneWidget);
    await harness.dispose(tester);
  });
}
