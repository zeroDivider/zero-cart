import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/inbox/ui/sheets/assign_sheet.dart';
import 'package:zero_cart/features/lists/assign_inbox_target.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';

import '../../support/test_app.dart';

const _genericError = 'Something went wrong. Try again.';

class _ThrowingListsRepository extends ListsRepository {
  _ThrowingListsRepository({
    required super.database,
    required super.now,
    required super.newId,
  });

  @override
  Future<AssignInboxResult> assignInbox(
    List<String> inboxIds,
    AssignInboxTarget target,
  ) {
    throw Exception('assign failed');
  }
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

Future<void> _tapActionChip(
  WidgetTester tester,
  Key key,
  TestAppHarness harness,
) async {
  final chip = tester.widget<ActionChip>(find.byKey(key));
  chip.onPressed!.call();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await pumpApp(tester, harness);
  await tester.pump(const Duration(milliseconds: 300));
  await pumpApp(tester, harness);
}

Future<({Store store, ShoppingList list, InboxItem item})> _seed(
  TestAppHarness harness, {
  String inboxTitle = 'Milk',
  String inboxId = 'inbox-1',
}) async {
  final stores = StoresRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12),
    newId: () => 'store-1',
  );
  final lists = ListsRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12, 1),
    newId: () => 'list-1',
  );
  final store = await stores.create(name: 'Lidl', colorKey: 'lime');
  final list = await lists.create(storeId: store.id, name: 'Weekend');
  final now = DateTime.utc(2026, 1, 1, 12, 2);
  await harness.db
      .into(harness.db.inboxItems)
      .insert(
        InboxItemsCompanion.insert(
          id: inboxId,
          title: inboxTitle,
          createdAt: now,
          updatedAt: now,
        ),
      );
  final item = await (harness.db.select(
    harness.db.inboxItems,
  )..where((t) => t.id.equals(inboxId))).getSingle();
  return (store: store, list: list, item: item);
}

void main() {
  testWidgets('assign to existing store and list shows Open snackbar', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.inbox),
    );
    final seed = await tester.runAsync(() => _seed(harness));
    await harness.refreshInbox();
    await harness.refreshStores();
    await harness.refreshLists();
    await pumpApp(tester, harness);

    await _tapButton(tester, Key('inbox_assign_${seed!.item.id}'), harness);
    expect(find.byType(AssignSheet), findsOneWidget);
    expect(find.text('Assign “Milk”'), findsOneWidget);

    await _tapButton(tester, const Key('assign_confirm'), harness);
    expect(find.byType(AssignSheet), findsNothing);
    expect(find.text('Milk'), findsNothing);
    expect(find.text('Added to Weekend'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);

    final action = tester.widget<SnackBarAction>(
      find.byWidgetPredicate(
        (widget) => widget is SnackBarAction && widget.label == 'Open',
      ),
    );
    action.onPressed();
    await pumpApp(tester, harness);
    expect(find.text('Weekend'), findsWidgets);

    await harness.dispose(tester);
  });

  testWidgets('new store and new list drafts persist only on confirm', (
    tester,
  ) async {
    var id = 0;
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.inbox),
      idGenerator: () {
        id += 1;
        return 'id-$id';
      },
    );
    await tester.runAsync(() async {
      await harness.db
          .into(harness.db.inboxItems)
          .insert(
            InboxItemsCompanion.insert(
              id: 'inbox-1',
              title: 'Tablets',
              createdAt: DateTime.utc(2026, 1, 1, 12),
              updatedAt: DateTime.utc(2026, 1, 1, 12),
            ),
          );
    });
    await harness.refreshInbox();
    await pumpApp(tester, harness);

    await _tapButton(tester, const Key('inbox_assign_inbox-1'), harness);
    expect(find.byType(AssignSheet), findsOneWidget);

    await _tapActionChip(tester, const Key('assign_new_store'), harness);
    expect(find.byType(StoreFormSheet), findsOneWidget);
    await tester.enterText(find.byKey(const Key('store_form_name')), 'DM');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_form_save'), harness);
    expect(find.byType(StoreFormSheet), findsNothing);
    expect(find.byKey(const Key('assign_new_store_name')), findsOneWidget);

    final storesBeforeConfirm = await tester.runAsync(
      () => harness.db.select(harness.db.stores).get(),
    );
    expect(storesBeforeConfirm, isEmpty);

    await _tapActionChip(tester, const Key('assign_new_list'), harness);
    expect(find.byKey(const Key('list_form_name')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('list_form_name')), 'Run');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('list_form_save'), harness);
    expect(find.byKey(const Key('assign_new_list_name')), findsOneWidget);

    await _tapButton(tester, const Key('assign_confirm'), harness);
    expect(find.byType(AssignSheet), findsNothing);
    expect(find.text('Added to Run'), findsOneWidget);

    final stores = await tester.runAsync(
      () => harness.db.select(harness.db.stores).get(),
    );
    expect(stores!.single.name, 'DM');
    final inboxLeft = await tester.runAsync(
      () => harness.db.select(harness.db.inboxItems).get(),
    );
    expect(inboxLeft, isEmpty);

    await harness.dispose(tester);
  });

  testWidgets('long-press multi-select assigns selected items', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.inbox),
    );
    final seed = await tester.runAsync(() async {
      final first = await _seed(harness, inboxTitle: 'Milk');
      final now = DateTime.utc(2026, 1, 1, 12, 3);
      await harness.db
          .into(harness.db.inboxItems)
          .insert(
            InboxItemsCompanion.insert(
              id: 'inbox-2',
              title: 'Bread',
              createdAt: now,
              updatedAt: now,
            ),
          );
      return first;
    });
    await harness.refreshInbox();
    await harness.refreshStores();
    await harness.refreshLists();
    await pumpApp(tester, harness);

    await tester.longPress(find.byKey(Key('inbox_row_${seed!.item.id}')));
    await pumpApp(tester, harness);
    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inbox_row_inbox-2')));
    await pumpApp(tester, harness);
    expect(find.text('2 selected'), findsOneWidget);

    await _tapButton(tester, const Key('inbox_assign_selected'), harness);
    expect(find.byType(AssignSheet), findsOneWidget);
    await _tapButton(tester, const Key('assign_confirm'), harness);

    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsNothing);
    expect(find.text('Added to Weekend'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('assign failure keeps sheet open and inbox unchanged', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.inbox),
      overrides: <Override>[
        listsRepositoryProvider.overrideWith((ref) {
          return _ThrowingListsRepository(
            database: ref.watch(appDatabaseProvider),
            now: ref.watch(nowProvider),
            newId: ref.watch(idGeneratorProvider),
          );
        }),
      ],
    );
    final seed = await tester.runAsync(() => _seed(harness));
    await harness.refreshInbox();
    await harness.refreshStores();
    await harness.refreshLists();
    await pumpApp(tester, harness);

    await _tapButton(tester, Key('inbox_assign_${seed!.item.id}'), harness);
    await _tapButton(tester, const Key('assign_confirm'), harness);

    expect(find.byType(AssignSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);

    await harness.dispose(tester);
  });
}
