import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/archive/ui/archive_screen.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/ui/list_screen.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

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

Future<void> _selectListsSegment(
  WidgetTester tester,
  TestAppHarness harness,
) async {
  await tester.tap(find.text('Lists'));
  await pumpApp(tester, harness);
}

void main() {
  testWidgets(
    'Archive Lists shows manual only; Restore clears; finished excluded',
    (tester) async {
      final harness = await pumpTestApp(
        tester,
        router: AppRouter.create(initialLocation: AppRoutes.archive),
      );
      late Store store;
      late ShoppingList manual;
      late ShoppingList finished;
      await tester.runAsync(() async {
        final repos = _repos(harness);
        store = await repos.stores.create(name: 'Lidl', colorKey: 'lime');
        manual = await repos.lists.create(
          storeId: store.id,
          name: 'Manual trip',
        );
        finished = await repos.lists.create(
          storeId: store.id,
          name: 'Finished trip',
        );
        await repos.lists.archive(manual.id);
        await repos.lists.finishList(finished.id, carryForward: false);
      });
      await pumpApp(tester, harness);

      expect(find.byType(ArchiveScreen), findsOneWidget);
      await _selectListsSegment(tester, harness);

      expect(find.text('Manual trip'), findsOneWidget);
      expect(find.text('Finished trip'), findsNothing);
      expect(find.text('Lidl'), findsOneWidget);
      expect(find.textContaining('manual'), findsNothing);

      await tester.tap(find.byKey(Key('archived_list_row_${manual.id}')));
      await pumpApp(tester, harness);
      expect(find.byType(ListScreen), findsOneWidget);

      tester.binding.handlePopRoute();
      await pumpApp(tester, harness);
      expect(find.byType(ArchiveScreen), findsOneWidget);

      await _tapButton(
        tester,
        Key('archived_list_restore_${manual.id}'),
        harness,
      );
      expect(find.text('Manual trip'), findsNothing);
      expect(find.text('No archived lists.'), findsOneWidget);

      final row = await tester.runAsync(
        () => (harness.db.select(
          harness.db.shoppingLists,
        )..where((t) => t.id.equals(manual.id))).getSingle(),
      );
      expect(row!.archivedAt, isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets('Archive Lists disables Restore when store is archived (LI-5)', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.archive),
    );
    late Store store;
    late ShoppingList manual;
    await tester.runAsync(() async {
      final repos = _repos(harness);
      store = await repos.stores.create(name: 'Lidl', colorKey: 'lime');
      manual = await repos.lists.create(storeId: store.id, name: 'Parked');
      await repos.lists.archive(manual.id);
      await repos.stores.archive(store.id);
    });
    await pumpApp(tester, harness);
    await _selectListsSegment(tester, harness);

    expect(find.text('Parked'), findsOneWidget);
    expect(
      find.text('Lidl · Restore the store first'),
      findsOneWidget,
    );
    expect(find.textContaining('manual'), findsNothing);
    final restore = tester.widget<TextButton>(
      find.byKey(Key('archived_list_restore_${manual.id}')),
    );
    expect(restore.onPressed, isNull);

    await tester.runAsync(() async {
      await harness.db
          .into(harness.db.shoppingLists)
          .insert(
            ShoppingListsCompanion.insert(
              id: 'finished-under-archived',
              storeId: store.id,
              name: 'Should hide',
              archivedAt: Value(DateTime.utc(2026, 1, 1, 14)),
              archiveReason: const Value(ListsRepository.archiveReasonFinished),
              createdAt: DateTime.utc(2026, 1, 1, 10),
              updatedAt: DateTime.utc(2026, 1, 1, 14),
            ),
          );
    });
    await pumpApp(tester, harness);
    expect(find.text('Should hide'), findsNothing);
    await harness.dispose(tester);
  });
}
