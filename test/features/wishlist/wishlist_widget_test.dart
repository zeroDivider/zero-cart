import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/core/widgets/swipe_to_remove_row.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/ui/list_screen.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/wishlist/ui/sheets/copy_to_list_sheet.dart';
import 'package:zero_cart/features/wishlist/ui/sheets/wishlist_add_sheet.dart';
import 'package:zero_cart/features/wishlist/ui/sheets/wishlist_edit_sheet.dart';
import 'package:zero_cart/features/wishlist/ui/wishlist_screen.dart';
import 'package:zero_cart/features/wishlist/wishlist_repository.dart';

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
    newId: () => 'store-1',
  );
}

WishlistRepository _wishlist(TestAppHarness harness, {String id = 'wish-1'}) {
  var n = 0;
  return WishlistRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12, n++),
    newId: () => '$id-$n',
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

Future<String> _seedStore(WidgetTester tester, TestAppHarness harness) async {
  final store = await tester.runAsync(
    () => _stores(harness).create(name: 'DM', colorKey: 'sky'),
  );
  await pumpApp(tester, harness);
  return store!.id;
}

void main() {
  testWidgets('store details card shows count and opens wishlist', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final storeId = await _seedStore(tester, harness);

    await tester.tap(find.byKey(Key('store_row_$storeId')));
    await pumpApp(tester, harness);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    await tester.pageBack();
    await pumpApp(tester, harness);

    await tester.runAsync(
      () => _wishlist(harness).add(storeId: storeId, title: 'Heads'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_$storeId')));
    await pumpApp(tester, harness);

    expect(find.byKey(const Key('store_wishlist_card')), findsOneWidget);
    expect(find.text('1 item for someday'), findsOneWidget);

    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);
    expect(find.byType(WishlistScreen), findsOneWidget);
    expect(find.text('Heads'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('add closes; add another clears and stays open', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final storeId = await _seedStore(tester, harness);
    await tester.tap(find.byKey(Key('store_row_$storeId')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('wishlist_fab_add')));
    await pumpApp(tester, harness);
    expect(find.byType(WishlistAddSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('wishlist_add_title')),
      'Cream',
    );
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('wishlist_add_another'), harness);
    expect(find.byType(WishlistAddSheet), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('wishlist_add_title')))
          .controller!
          .text,
      isEmpty,
    );

    await tester.enterText(
      find.byKey(const Key('wishlist_add_title')),
      'Heads',
    );
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('wishlist_add_submit'), harness);
    expect(find.byType(WishlistAddSheet), findsNothing);
    expect(find.text('Cream'), findsOneWidget);
    expect(find.text('Heads'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('edit save and remove with Undo', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final storeId = await _seedStore(tester, harness);
    final item = await tester.runAsync(
      () => _wishlist(harness).add(storeId: storeId, title: 'Heads'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_$storeId')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('wishlist_row_${item!.id}')));
    await pumpApp(tester, harness);
    expect(find.byType(WishlistEditSheet), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('wishlist_edit_title')),
      'Heads soft',
    );
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('wishlist_edit_save'), harness);
    expect(find.text('Heads soft'), findsOneWidget);

    await tester.tap(find.byKey(Key('wishlist_row_${item.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('wishlist_edit_remove'), harness);
    expect(find.text('Heads soft'), findsNothing);
    expect(find.text('Removed Heads soft'), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    snackBar.action!.onPressed();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumpApp(tester, harness);
    expect(find.text('Heads soft'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('swipe remove shows Undo snackbar', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final storeId = await _seedStore(tester, harness);
    final item = await tester.runAsync(
      () => _wishlist(harness).add(storeId: storeId, title: 'Cream'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_$storeId')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);

    final dismissible = find.descendant(
      of: find.byType(SwipeToRemoveRow),
      matching: find.byType(Dismissible),
    );
    await tester.drag(dismissible, const Offset(-500, 0));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumpApp(tester, harness);

    expect(find.byKey(Key('wishlist_row_${item!.id}')), findsNothing);
    expect(find.text('Removed Cream'), findsOneWidget);
    expect(rootScaffoldMessengerKey.currentState, isNotNull);
    await harness.dispose(tester);
  });

  testWidgets('copy to existing list shows snackbar Open', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final storeId = await _seedStore(tester, harness);
    final lists = _lists(harness);
    final list = await tester.runAsync(
      () => lists.create(storeId: storeId, name: 'Drugstore'),
    );
    final item = await tester.runAsync(
      () => _wishlist(harness).add(storeId: storeId, title: 'Heads'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_$storeId')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);

    await _tapButton(tester, Key('wishlist_add_to_list_${item!.id}'), harness);
    expect(find.byType(CopyToListSheet), findsOneWidget);
    await tester.tap(find.byKey(Key('copy_list_${list!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('copy_to_list_confirm'), harness);

    expect(find.text('Added to Drugstore'), findsOneWidget);
    expect(find.text('Heads'), findsOneWidget);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    snackBar.action!.onPressed();
    await pumpApp(tester, harness);
    expect(find.byType(ListScreen), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('copy via New list creates target and keeps wishlist row', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final storeId = await _seedStore(tester, harness);
    final item = await tester.runAsync(
      () => _wishlist(harness).add(storeId: storeId, title: 'Cream'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_$storeId')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);

    await _tapButton(tester, Key('wishlist_add_to_list_${item!.id}'), harness);
    await tester.tap(find.byKey(const Key('copy_new_list')));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('list_form_name')), 'Someday');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('list_form_save'), harness);
    expect(find.text('Someday'), findsOneWidget);
    await _tapButton(tester, const Key('copy_to_list_confirm'), harness);

    expect(find.text('Added to Someday'), findsOneWidget);
    expect(find.text('Cream'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('archived store wishlist is read-only', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final storeId = await _seedStore(tester, harness);
    await tester.runAsync(
      () => _wishlist(harness).add(storeId: storeId, title: 'Heads'),
    );
    await tester.runAsync(() => _stores(harness).archive(storeId));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('stores_archive')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('archived_store_row_$storeId')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);

    expect(find.byType(WishlistScreen), findsOneWidget);
    expect(find.byKey(const Key('wishlist_fab_add')), findsNothing);
    expect(find.byType(SwipeToRemoveRow), findsNothing);
    expect(find.text('Add to list'), findsNothing);
    await harness.dispose(tester);
  });

  testWidgets('multi-select copies selected items', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final storeId = await _seedStore(tester, harness);
    final lists = _lists(harness);
    final list = await tester.runAsync(
      () => lists.create(storeId: storeId, name: 'Run'),
    );
    final wish = _wishlist(harness);
    final a = await tester.runAsync(
      () => wish.add(storeId: storeId, title: 'A'),
    );
    final b = await tester.runAsync(
      () => wish.add(storeId: storeId, title: 'B'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_$storeId')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);

    await tester.longPress(find.byKey(Key('wishlist_row_${a!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(Key('wishlist_row_${b!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('wishlist_add_selected'), harness);
    await tester.tap(find.byKey(Key('copy_list_${list!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('copy_to_list_confirm'), harness);

    expect(find.text('Added to Run'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    await harness.dispose(tester);
  });
}
