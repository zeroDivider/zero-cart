import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/stores/store_draft.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';

import '../../support/test_app.dart';

const _genericError = 'Something went wrong. Try again.';

class _ThrowingStoresRepository extends StoresRepository {
  _ThrowingStoresRepository({
    required super.database,
    required super.now,
    required super.newId,
    this.throwOnCreate = false,
    this.throwOnUpdate = false,
    this.throwOnArchive = false,
    this.throwOnRestore = false,
  });

  final bool throwOnCreate;
  final bool throwOnUpdate;
  final bool throwOnArchive;
  final bool throwOnRestore;

  @override
  Future<Store> createFromDraft(StoreDraft draft) {
    if (throwOnCreate) {
      throw Exception('create failed');
    }
    return super.createFromDraft(draft);
  }

  @override
  Future<Store> updateFromDraft(String id, StoreDraft draft) {
    if (throwOnUpdate) {
      throw Exception('update failed');
    }
    return super.updateFromDraft(id, draft);
  }

  @override
  Future<void> archive(String id) async {
    if (throwOnArchive) {
      throw Exception('archive failed');
    }
    await super.archive(id);
  }

  @override
  Future<void> restore(String id) async {
    if (throwOnRestore) {
      throw Exception('restore failed');
    }
    await super.restore(id);
  }
}

StoresRepository _seedRepo(TestAppHarness harness) {
  return StoresRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12),
    newId: () => 'seed-store',
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

List<Override> _throwingStoresOverrides({
  bool throwOnCreate = false,
  bool throwOnUpdate = false,
  bool throwOnArchive = false,
  bool throwOnRestore = false,
}) {
  return [
    storesRepositoryProvider.overrideWith((ref) {
      return _ThrowingStoresRepository(
        database: ref.watch(appDatabaseProvider),
        now: ref.watch(nowProvider),
        newId: ref.watch(idGeneratorProvider),
        throwOnCreate: throwOnCreate,
        throwOnUpdate: throwOnUpdate,
        throwOnArchive: throwOnArchive,
        throwOnRestore: throwOnRestore,
      );
    }),
  ];
}

void main() {
  testWidgets('store create failure keeps sheet open with inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingStoresOverrides(throwOnCreate: true),
    );

    await tester.tap(find.byKey(const Key('stores_empty_create')));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('store_form_name')), 'Lidl');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_form_save'), harness);

    expect(find.byType(StoreFormSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);

    final rows = await tester.runAsync(
      () => harness.db.select(harness.db.stores).get(),
    );
    expect(rows, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets('store edit failure keeps sheet open with inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingStoresOverrides(throwOnUpdate: true),
    );
    final store = await tester.runAsync(
      () => _seedRepo(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_details_edit'), harness);
    await tester.enterText(
      find.byKey(const Key('store_form_name')),
      'Lidl City',
    );
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('store_form_save'), harness);

    expect(find.byType(StoreFormSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(row!.name, 'Lidl');
    await harness.dispose(tester);
  });

  testWidgets(
    'store archive failure shows error snackbar and stays on details',
    (tester) async {
      final harness = await pumpTestApp(
        tester,
        router: AppRouter.create(initialLocation: AppRoutes.stores),
        overrides: _throwingStoresOverrides(throwOnArchive: true),
      );
      final store = await tester.runAsync(
        () => _seedRepo(harness).create(name: 'Lidl', colorKey: 'lime'),
      );
      await pumpApp(tester, harness);

      await tester.tap(find.byKey(Key('store_row_${store!.id}')));
      await pumpApp(tester, harness);
      await _tapButton(tester, const Key('store_details_archive'), harness);

      expect(find.text(_genericError), findsOneWidget);
      expect(find.byKey(const Key('store_details_archive')), findsOneWidget);

      final row = await tester.runAsync(
        () => harness.db.select(harness.db.stores).getSingle(),
      );
      expect(row!.archivedAt, isNull);
      await harness.dispose(tester);
    },
  );

  testWidgets('store restore failure shows error snackbar', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _throwingStoresOverrides(throwOnRestore: true),
    );
    final store = await tester.runAsync(
      () => _seedRepo(harness).create(name: 'Lidl', colorKey: 'lime'),
    );
    await tester.runAsync(() => _seedRepo(harness).archive(store!.id));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('stores_archive')));
    await pumpApp(tester, harness);
    await _tapButton(
      tester,
      Key('archived_store_restore_${store!.id}'),
      harness,
    );

    expect(find.text(_genericError), findsOneWidget);
    expect(find.text('Lidl'), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.stores).getSingle(),
    );
    expect(row!.archivedAt, isNotNull);
    await harness.dispose(tester);
  });
}
