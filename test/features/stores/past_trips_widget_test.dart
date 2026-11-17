import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/ui/list_screen.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/stores/ui/past_trips_screen.dart';
import 'package:zero_cart/features/stores/ui/store_details_screen.dart';

import '../../support/test_app.dart';

({StoresRepository stores, ListsRepository lists}) _repos(
  TestAppHarness harness,
) {
  var storeN = 0;
  var listN = 0;
  return (
    stores: StoresRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 12, 0, storeN++),
      newId: () => 'store-${storeN++}',
    ),
    lists: ListsRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 13, 0, listN++),
      newId: () => 'list-${listN++}',
    ),
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

void main() {
  testWidgets('Past trips card opens screen; Restore returns list to active', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    late Store store;
    late ShoppingList list;
    await tester.runAsync(() async {
      final repos = _repos(harness);
      store = await repos.stores.create(name: 'Lidl', colorKey: 'lime');
      list = await repos.lists.create(storeId: store.id, name: 'Weekend run');
      await repos.lists.finishList(list.id, carryForward: false);
    });
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store.id}')));
    await pumpApp(tester, harness);
    expect(find.byType(StoreDetailsScreen), findsOneWidget);
    expect(find.byKey(const Key('store_past_trips_card')), findsOneWidget);
    expect(find.text('1 past trip'), findsOneWidget);

    await tester.tap(find.byKey(const Key('store_past_trips_card')));
    await pumpApp(tester, harness);
    expect(find.byType(PastTripsScreen), findsOneWidget);
    expect(find.text('Weekend run'), findsOneWidget);

    await tester.tap(find.byKey(Key('past_trip_row_${list.id}')));
    await pumpApp(tester, harness);
    expect(find.byType(ListScreen), findsOneWidget);

    tester.binding.handlePopRoute();
    await pumpApp(tester, harness);
    expect(find.byType(PastTripsScreen), findsOneWidget);

    await _tapButton(tester, Key('past_trip_restore_${list.id}'), harness);
    expect(find.text('Weekend run'), findsNothing);
    expect(find.text('No finished trips yet.'), findsOneWidget);

    final row = await tester.runAsync(
      () => (harness.db.select(
        harness.db.shoppingLists,
      )..where((t) => t.id.equals(list.id))).getSingle(),
    );
    expect(row!.archivedAt, isNull);
    await harness.dispose(tester);
  });

  testWidgets('Past trips disables Restore when store is archived', (
    tester,
  ) async {
    const storeId = 'archived-store';
    const listId = 'finished-list';
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(
        initialLocation: AppRoutes.pastTripsLocation(storeId),
      ),
    );
    await tester.runAsync(() async {
      await harness.db
          .into(harness.db.stores)
          .insert(
            StoresCompanion.insert(
              id: storeId,
              name: 'Lidl',
              colorKey: 'lime',
              archivedAt: Value(DateTime.utc(2026, 1, 1, 12)),
              createdAt: DateTime.utc(2026, 1, 1, 10),
              updatedAt: DateTime.utc(2026, 1, 1, 12),
            ),
          );
      await harness.db
          .into(harness.db.shoppingLists)
          .insert(
            ShoppingListsCompanion.insert(
              id: listId,
              storeId: storeId,
              name: 'Done',
              archivedAt: Value(DateTime.utc(2026, 1, 1, 11)),
              archiveReason: const Value(ListsRepository.archiveReasonFinished),
              createdAt: DateTime.utc(2026, 1, 1, 10),
              updatedAt: DateTime.utc(2026, 1, 1, 11),
            ),
          );
      await harness.db
          .into(harness.db.shoppingLists)
          .insert(
            ShoppingListsCompanion.insert(
              id: 'manual-hidden',
              storeId: storeId,
              name: 'Manual only',
              archivedAt: Value(DateTime.utc(2026, 1, 1, 11)),
              archiveReason: const Value(ListsRepository.archiveReasonManual),
              createdAt: DateTime.utc(2026, 1, 1, 10),
              updatedAt: DateTime.utc(2026, 1, 1, 11),
            ),
          );
    });
    await pumpApp(tester, harness);

    expect(find.byType(PastTripsScreen), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Manual only'), findsNothing);
    expect(find.text('Restore the store first'), findsOneWidget);
    final restore = tester.widget<TextButton>(
      find.byKey(const Key('past_trip_restore_$listId')),
    );
    expect(restore.onPressed, isNull);
    await harness.dispose(tester);
  });
}
