import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/features/archive/ui/archive_screen.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';
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

void main() {
  testWidgets('empty name keeps sheet open with inline error', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );

    await tester.tap(find.byKey(const Key('stores_empty_create')));
    await pumpApp(tester, harness);
    expect(find.byType(StoreFormSheet), findsOneWidget);

    await _tapButton(tester, const Key('store_form_save'), harness);
    expect(find.byType(StoreFormSheet), findsOneWidget);
    expect(find.text('Enter a store name'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('create store inserts row with first unused colour', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );

    await tester.tap(find.byKey(const Key('stores_empty_create')));
    await pumpApp(tester, harness);

    await tester.enterText(find.byKey(const Key('store_form_name')), 'Lidl');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_form_save'), harness);

    expect(find.byType(StoreFormSheet), findsNothing);
    expect(find.text('Lidl'), findsOneWidget);
    expect(find.text('0 active lists'), findsOneWidget);

    final store = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(store!.colorKey, AppTokens.storePaletteKeys.first);
    await harness.dispose(tester);
  });

  testWidgets('list count on the Stores tab updates after creating a list', (
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
    expect(find.text('0 active lists'), findsOneWidget);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_details_new_list'), harness);
    await tester.enterText(find.byKey(const Key('list_form_name')), 'Weekend');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('list_form_save'), harness);

    await tester.pageBack();
    await pumpApp(tester, harness);
    await tester.pageBack();
    await pumpApp(tester, harness);

    expect(find.byType(StoresScreen), findsOneWidget);
    expect(find.text('1 active list'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('new store button creates another store on the list', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    await tester.runAsync(
      () => _repo(harness).create(name: 'Aldi', colorKey: 'tomato'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('stores_new_store')));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('store_form_name')), 'DM');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_form_save'), harness);

    expect(find.text('Aldi'), findsOneWidget);
    expect(find.text('DM'), findsOneWidget);

    final rows = await tester.runAsync(
      () => harness.db.select(harness.db.stores).get(),
    );
    expect(rows, hasLength(2));
    final byName = [...rows!]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    expect(byName.map((s) => s.name), ['Aldi', 'DM']);
    expect(
      {for (final s in byName) s.name: s.colorKey},
      {'Aldi': 'tomato', 'DM': 'tangerine'},
    );
    await harness.dispose(tester);
  });

  testWidgets('edit store persists and refreshes the Stores list', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );
    final created = await tester.runAsync(
      () =>
          _repo(harness)
              .create(name: 'Lidl', colorKey: 'lime', address: 'Main'),
    );
    await pumpApp(tester, harness);
    expect(find.text('Lidl'), findsOneWidget);

    final context = tester.element(find.byType(StoresScreen));
    final repo = ProviderScope.containerOf(context)
        .read(storesRepositoryProvider);
    final editFuture = showStoreFormSheet(
      context,
      existing: created,
      repository: repo,
    );
    await pumpApp(tester, harness);
    expect(find.byType(StoreFormSheet), findsOneWidget);
    expect(find.text('Edit store'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('store_form_name')),
      'Lidl City',
    );
    await tester.enterText(
      find.byKey(const Key('store_form_note')),
      'Weekly offers',
    );
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_form_save'), harness);

    final saved = await tester.runAsync(() => editFuture);
    expect(saved, isNotNull);
    await pumpApp(tester, harness);

    expect(find.text('Lidl City'), findsOneWidget);
    expect(find.text('Lidl'), findsNothing);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(row!.name, 'Lidl City');
    expect(row.note, 'Weekly offers');
    await harness.dispose(tester);
  });

  testWidgets('archive icon opens archive route', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );

    await tester.tap(find.byKey(const Key('stores_archive')));
    await pumpApp(tester, harness);
    expect(find.byType(ArchiveScreen), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('draft mode returns StoreDraft without writing', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
    );

    final context = tester.element(find.byType(StoresScreen));
    final draftFuture = showStoreFormDraftSheet(
      context,
      initialColorKey: 'sky',
    );
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('store_form_name')), 'Ghost');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_form_save'), harness);

    final draft = await tester.runAsync(() => draftFuture);
    expect(draft!.name, 'Ghost');
    expect(draft.colorKey, 'sky');

    final rows = await tester.runAsync(
      () => harness.db.select(harness.db.stores).get(),
    );
    expect(rows, isEmpty);
    await harness.dispose(tester);
  });
}
