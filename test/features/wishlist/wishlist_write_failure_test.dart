import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/lists/copy_wishlist_target.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/features/wishlist/ui/sheets/copy_to_list_sheet.dart';
import 'package:zero_cart/features/wishlist/ui/sheets/wishlist_add_sheet.dart';
import 'package:zero_cart/features/wishlist/wishlist_providers.dart';
import 'package:zero_cart/features/wishlist/wishlist_repository.dart';

import '../../support/test_app.dart';

const _genericError = 'Something went wrong. Try again.';

class _ThrowingWishlistRepository extends WishlistRepository {
  _ThrowingWishlistRepository({
    required super.database,
    required super.now,
    required super.newId,
    this.throwOnAdd = false,
  });

  final bool throwOnAdd;

  @override
  Future<WishlistItem> add({
    required String storeId,
    required String title,
    String? description,
  }) {
    if (throwOnAdd) {
      throw Exception('add failed');
    }
    return super.add(storeId: storeId, title: title, description: description);
  }
}

class _ThrowingListsRepository extends ListsRepository {
  _ThrowingListsRepository({
    required super.database,
    required super.now,
    required super.newId,
  });

  @override
  Future<CopyWishlistResult> copyWishlistItems(
    List<String> wishlistIds,
    CopyWishlistTarget target,
  ) {
    throw Exception('copy failed');
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

List<Override> _wishlistOverrides({required bool throwOnAdd}) {
  return [
    wishlistRepositoryProvider.overrideWith((ref) {
      return _ThrowingWishlistRepository(
        database: ref.watch(appDatabaseProvider),
        now: ref.watch(nowProvider),
        newId: ref.watch(idGeneratorProvider),
        throwOnAdd: throwOnAdd,
      );
    }),
  ];
}

void main() {
  testWidgets('add failure keeps sheet open with inline error', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: _wishlistOverrides(throwOnAdd: true),
    );
    final store = await tester.runAsync(
      () => StoresRepository(
        database: harness.db,
        now: () => DateTime.utc(2026, 1, 1, 12),
        newId: () => 'store-1',
      ).create(name: 'DM', colorKey: 'sky'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store!.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('wishlist_fab_add')));
    await pumpApp(tester, harness);

    await tester.enterText(
      find.byKey(const Key('wishlist_add_title')),
      'Heads',
    );
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('wishlist_add_submit'), harness);

    expect(find.byType(WishlistAddSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('copy failure keeps sheet open and wishlist row', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.stores),
      overrides: [
        listsRepositoryProvider.overrideWith((ref) {
          return _ThrowingListsRepository(
            database: ref.watch(appDatabaseProvider),
            now: ref.watch(nowProvider),
            newId: ref.watch(idGeneratorProvider),
          );
        }),
      ],
    );
    final stores = StoresRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 12),
      newId: () => 'store-1',
    );
    final store = (await tester.runAsync(
      () => stores.create(name: 'DM', colorKey: 'sky'),
    ))!;
    final lists = ListsRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 13),
      newId: () => 'list-1',
    );
    final list = await tester.runAsync(
      () => lists.create(storeId: store.id, name: 'Run'),
    );
    final wish = await tester.runAsync(
      () => WishlistRepository(
        database: harness.db,
        now: () => DateTime.utc(2026, 1, 1, 14),
        newId: () => 'wish-1',
      ).add(storeId: store.id, title: 'Heads'),
    );
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(Key('store_row_${store.id}')));
    await pumpApp(tester, harness);
    await tester.tap(find.byKey(const Key('store_wishlist_card')));
    await pumpApp(tester, harness);
    await _tapButton(tester, Key('wishlist_add_to_list_${wish!.id}'), harness);
    await tester.tap(find.byKey(Key('copy_list_${list!.id}')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('copy_to_list_confirm'), harness);

    expect(find.byType(CopyToListSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);
    Navigator.of(tester.element(find.byType(CopyToListSheet))).pop();
    await pumpApp(tester, harness);
    expect(find.text('Heads'), findsOneWidget);
    await harness.dispose(tester);
  });
}
