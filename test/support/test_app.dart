import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/app.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/lists/active_list_progress.dart';
import 'package:zero_cart/features/lists/archived_list_with_store.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/active_store_summary.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/wishlist/wishlist_providers.dart';

bool _driftMultiDbWarningSilenced = false;

void _silenceDriftMultiDbWarning() {
  if (_driftMultiDbWarningSilenced) {
    return;
  }
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  _driftMultiDbWarningSilenced = true;
}

List<Store> _sortedByName(Iterable<Store> stores) {
  final rows = stores.toList()
    ..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) {
        return byName;
      }
      return a.id.compareTo(b.id);
    });
  return rows;
}

/// Harness returned by [pumpTestApp].
class TestAppHarness {
  TestAppHarness({
    required this.db,
    required this.refreshInbox,
    required this.refreshStores,
    required this.refreshLists,
    required this.refreshWishlist,
    required StreamController<List<InboxItem>> inboxUpdates,
    required StreamController<List<Store>> storeUpdates,
    required StreamController<List<ActiveStoreSummary>> storeSummaryUpdates,
    required StreamController<List<Store>> archivedStoreUpdates,
    required StreamController<List<Store>> allStoreUpdates,
    required StreamController<void> listsTickUpdates,
    required StreamController<void> listDetailsTickUpdates,
    required StreamController<void> wishlistTickUpdates,
  }) : _inboxController = inboxUpdates,
       _storeController = storeUpdates,
       _storeSummaryController = storeSummaryUpdates,
       _archivedStoreController = archivedStoreUpdates,
       _allStoreController = allStoreUpdates,
       _listsTickController = listsTickUpdates,
       _listDetailsTickController = listDetailsTickUpdates,
       _wishlistTickController = wishlistTickUpdates;

  final AppDatabase db;
  final Future<void> Function() refreshInbox;
  final Future<void> Function() refreshStores;
  final Future<void> Function() refreshLists;
  final Future<void> Function() refreshWishlist;
  final StreamController<List<InboxItem>> _inboxController;
  final StreamController<List<Store>> _storeController;
  final StreamController<List<ActiveStoreSummary>> _storeSummaryController;
  final StreamController<List<Store>> _archivedStoreController;
  final StreamController<List<Store>> _allStoreController;
  final StreamController<void> _listsTickController;
  final StreamController<void> _listDetailsTickController;
  final StreamController<void> _wishlistTickController;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _inboxController.close();
    await _storeController.close();
    await _storeSummaryController.close();
    await _archivedStoreController.close();
    await _allStoreController.close();
    await _listsTickController.close();
    await _listDetailsTickController.close();
    await _wishlistTickController.close();
    await tester.runAsync(db.close);
  }
}

/// Pumps [ZeroCartApp] with an in-memory database and faked clock/ids.
///
/// Widget tests using this harness cover UI → repository → DB behaviour.
/// They do **not** prove live Drift `.watch()` → Riverpod wiring: under
/// FakeAsync on Windows, `.watch()` does not emit, so [inboxItemsProvider],
/// [activeStoresProvider], [activeStoreSummariesProvider],
/// [archivedStoresProvider], [storeByIdProvider],
/// [activeListsForStoreProvider], [activeListsByRecencyProvider],
/// [listByIdProvider], [listItemsProvider], [finishedListsForStoreProvider],
/// [finishedCountForStoreProvider] and [manualArchivedListsProvider] are
/// bridged by broadcast streams that [pumpApp] refreshes after real writes
/// against [TestAppHarness.db].
/// See `inbox_providers_test.dart` for a live-stream check without FakeAsync.
Future<TestAppHarness> pumpTestApp(
  WidgetTester tester, {
  GoRouter? router,
  Clock? clock,
  IdGenerator? idGenerator,
  List<Override> overrides = const [],
}) async {
  _silenceDriftMultiDbWarning();
  final db = AppDatabase.memory();
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  var idCounter = 0;
  final fixedClock = clock ?? () => DateTime.utc(2026, 1, 1, 12);
  final ids =
      idGenerator ??
      () {
        idCounter += 1;
        return 'test-id-$idCounter';
      };

  final inboxController = StreamController<List<InboxItem>>.broadcast();
  final storeController = StreamController<List<Store>>.broadcast();
  final storeSummaryController =
      StreamController<List<ActiveStoreSummary>>.broadcast();
  final archivedStoreController = StreamController<List<Store>>.broadcast();
  final allStoreController = StreamController<List<Store>>.broadcast();
  final listsTickController = StreamController<void>.broadcast();
  final listDetailsTickController = StreamController<void>.broadcast();
  final wishlistTickController = StreamController<void>.broadcast();

  var latestInbox = <InboxItem>[];
  var latestActive = <Store>[];
  var latestSummaries = <ActiveStoreSummary>[];
  var latestArchived = <Store>[];
  var latestAll = <Store>[];
  final latestListsByStore = <String, List<ActiveListProgress>>{};
  final latestFinishedByStore = <String, List<ShoppingList>>{};
  var latestManualArchived = <ArchivedListWithStore>[];
  final latestListById = <String, ShoppingList?>{};
  final latestItemsByList = <String, List<ListItem>>{};
  final latestWishlistByStore = <String, List<WishlistItem>>{};

  Future<List<ActiveListProgress>> loadActiveLists(String storeId) async {
    final lists =
        await (db.select(db.shoppingLists)
              ..where((t) => t.storeId.equals(storeId) & t.archivedAt.isNull())
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final result = <ActiveListProgress>[];
    for (final list in lists) {
      final items = await (db.select(
        db.listItems,
      )..where((t) => t.listId.equals(list.id))).get();
      result.add(
        ActiveListProgress(
          list: list,
          itemsLeft: items.where((i) => !i.isPurchased).length,
          itemsTotal: items.length,
        ),
      );
    }
    return result;
  }

  Future<void> refreshInbox() async {
    final rows =
        await (db.select(db.inboxItems)..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
            .get();
    latestInbox = rows;
    if (!inboxController.isClosed) {
      inboxController.add(rows);
    }
  }

  Future<void> publishSummaries() async {
    final lists = await db.select(db.shoppingLists).get();
    final counts = <String, int>{};
    for (final list in lists) {
      if (list.archivedAt != null) {
        continue;
      }
      counts[list.storeId] = (counts[list.storeId] ?? 0) + 1;
    }
    latestSummaries = [
      for (final store in latestActive)
        ActiveStoreSummary(
          store: store,
          activeListCount: counts[store.id] ?? 0,
        ),
    ];
    if (!storeSummaryController.isClosed) {
      storeSummaryController.add(latestSummaries);
    }
  }

  Future<void> refreshStores() async {
    final rows = await db.select(db.stores).get();
    latestAll = rows;
    latestActive = _sortedByName(rows.where((s) => s.archivedAt == null));
    latestArchived = _sortedByName(rows.where((s) => s.archivedAt != null));
    if (!allStoreController.isClosed) {
      allStoreController.add(latestAll);
    }
    if (!storeController.isClosed) {
      storeController.add(latestActive);
    }
    if (!archivedStoreController.isClosed) {
      archivedStoreController.add(latestArchived);
    }
    await publishSummaries();
  }

  Future<List<ShoppingList>> loadFinishedLists(String storeId) async {
    final lists =
        await (db.select(db.shoppingLists)
              ..where(
                (t) =>
                    t.storeId.equals(storeId) &
                    t.archivedAt.isNotNull() &
                    t.archiveReason.equals(
                      ListsRepository.archiveReasonFinished,
                    ),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.updatedAt),
                (t) => OrderingTerm.desc(t.id),
              ]))
            .get();
    return lists;
  }

  Future<List<ArchivedListWithStore>> loadManualArchived() async {
    final storesById = {for (final store in latestAll) store.id: store};
    final lists =
        await (db.select(db.shoppingLists)..where(
              (t) =>
                  t.archivedAt.isNotNull() &
                  t.archiveReason.equals(ListsRepository.archiveReasonManual),
            ))
            .get();
    lists.sort((a, b) {
      final storeA = storesById[a.storeId];
      final storeB = storesById[b.storeId];
      final nameA = storeA?.name.toLowerCase() ?? '';
      final nameB = storeB?.name.toLowerCase() ?? '';
      final byName = nameA.compareTo(nameB);
      if (byName != 0) {
        return byName;
      }
      final byStoreId = a.storeId.compareTo(b.storeId);
      if (byStoreId != 0) {
        return byStoreId;
      }
      final byUpdated = b.updatedAt.compareTo(a.updatedAt);
      if (byUpdated != 0) {
        return byUpdated;
      }
      return b.id.compareTo(a.id);
    });
    return [
      for (final list in lists)
        ArchivedListWithStore(
          list: list,
          storeName: storesById[list.storeId]?.name ?? '',
          storeColorKey: storesById[list.storeId]?.colorKey ?? 'lime',
          storeArchivedAt: storesById[list.storeId]?.archivedAt,
        ),
    ];
  }

  Future<void> refreshLists() async {
    final storeIds = <String>{
      ...latestAll.map((s) => s.id),
      ...latestListsByStore.keys,
      ...latestFinishedByStore.keys,
    };
    for (final storeId in storeIds) {
      latestListsByStore[storeId] = await loadActiveLists(storeId);
      latestFinishedByStore[storeId] = await loadFinishedLists(storeId);
    }
    latestManualArchived = await loadManualArchived();
    if (!listsTickController.isClosed) {
      listsTickController.add(null);
    }

    final listIds = <String>{
      ...latestListById.keys,
      ...latestItemsByList.keys,
      for (final lists in latestListsByStore.values)
        for (final row in lists) row.list.id,
      for (final lists in latestFinishedByStore.values)
        for (final list in lists) list.id,
      for (final row in latestManualArchived) row.list.id,
    };
    final allLists = await db.select(db.shoppingLists).get();
    for (final shoppingList in allLists) {
      listIds.add(shoppingList.id);
    }
    for (final listId in listIds) {
      ShoppingList? found;
      for (final shoppingList in allLists) {
        if (shoppingList.id == listId) {
          found = shoppingList;
          break;
        }
      }
      latestListById[listId] = found;
      final items =
          await (db.select(db.listItems)
                ..where((t) => t.listId.equals(listId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.position),
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
      latestItemsByList[listId] = items;
    }
    if (!listDetailsTickController.isClosed) {
      listDetailsTickController.add(null);
    }
    await publishSummaries();
  }

  Future<void> refreshWishlist() async {
    final storeIds = <String>{
      ...latestAll.map((s) => s.id),
      ...latestWishlistByStore.keys,
    };
    for (final storeId in storeIds) {
      latestWishlistByStore[storeId] =
          await (db.select(db.wishlistItems)
                ..where((t) => t.storeId.equals(storeId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();
    }
    if (!wishlistTickController.isClosed) {
      wishlistTickController.add(null);
    }
  }

  Stream<List<InboxItem>> inboxBridge() async* {
    yield latestInbox;
    yield* inboxController.stream;
  }

  Stream<List<Store>> activeStoresBridge() async* {
    yield latestActive;
    yield* storeController.stream;
  }

  Stream<List<ActiveStoreSummary>> storeSummariesBridge() async* {
    yield latestSummaries;
    yield* storeSummaryController.stream;
  }

  Stream<List<Store>> archivedStoresBridge() async* {
    yield latestArchived;
    yield* archivedStoreController.stream;
  }

  Stream<Store?> storeByIdBridge(String id) async* {
    Store? find() {
      for (final store in latestAll) {
        if (store.id == id) {
          return store;
        }
      }
      return null;
    }

    yield find();
    await for (final _ in allStoreController.stream) {
      yield find();
    }
  }

  Stream<List<ActiveListProgress>> listsBridge(String storeId) async* {
    yield latestListsByStore[storeId] ?? const <ActiveListProgress>[];
    await for (final _ in listsTickController.stream) {
      yield latestListsByStore[storeId] ?? const <ActiveListProgress>[];
    }
  }

  Stream<List<ShoppingList>> activeListsByRecencyBridge() async* {
    List<ShoppingList> snapshot() {
      final lists =
          <ShoppingList>[
            for (final rows in latestListsByStore.values)
              for (final row in rows) row.list,
          ]..sort((a, b) {
            final byUpdated = b.updatedAt.compareTo(a.updatedAt);
            if (byUpdated != 0) {
              return byUpdated;
            }
            return b.id.compareTo(a.id);
          });
      return lists;
    }

    yield snapshot();
    await for (final _ in listsTickController.stream) {
      yield snapshot();
    }
  }

  Stream<ShoppingList?> listByIdBridge(String id) async* {
    yield latestListById[id];
    await for (final _ in listDetailsTickController.stream) {
      yield latestListById[id];
    }
  }

  Stream<List<ListItem>> listItemsBridge(String listId) async* {
    yield latestItemsByList[listId] ?? const <ListItem>[];
    await for (final _ in listDetailsTickController.stream) {
      yield latestItemsByList[listId] ?? const <ListItem>[];
    }
  }

  Stream<List<WishlistItem>> wishlistBridge(String storeId) async* {
    yield latestWishlistByStore[storeId] ?? const <WishlistItem>[];
    await for (final _ in wishlistTickController.stream) {
      yield latestWishlistByStore[storeId] ?? const <WishlistItem>[];
    }
  }

  Stream<int> wishlistCountBridge(String storeId) async* {
    yield (latestWishlistByStore[storeId] ?? const <WishlistItem>[]).length;
    await for (final _ in wishlistTickController.stream) {
      yield (latestWishlistByStore[storeId] ?? const <WishlistItem>[]).length;
    }
  }

  Stream<List<ShoppingList>> finishedListsBridge(String storeId) async* {
    yield latestFinishedByStore[storeId] ?? const <ShoppingList>[];
    await for (final _ in listsTickController.stream) {
      yield latestFinishedByStore[storeId] ?? const <ShoppingList>[];
    }
  }

  Stream<int> finishedCountBridge(String storeId) async* {
    yield (latestFinishedByStore[storeId] ?? const <ShoppingList>[]).length;
    await for (final _ in listsTickController.stream) {
      yield (latestFinishedByStore[storeId] ?? const <ShoppingList>[]).length;
    }
  }

  Stream<List<ArchivedListWithStore>> manualArchivedBridge() async* {
    yield latestManualArchived;
    await for (final _ in listsTickController.stream) {
      yield latestManualArchived;
    }
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(fixedClock),
        idGeneratorProvider.overrideWithValue(ids),
        inboxItemsProvider.overrideWith((ref) => inboxBridge()),
        activeStoresProvider.overrideWith((ref) => activeStoresBridge()),
        activeStoreSummariesProvider.overrideWith(
          (ref) => storeSummariesBridge(),
        ),
        archivedStoresProvider.overrideWith((ref) => archivedStoresBridge()),
        storeByIdProvider.overrideWith((ref, id) => storeByIdBridge(id)),
        activeListsForStoreProvider.overrideWith(
          (ref, storeId) => listsBridge(storeId),
        ),
        activeListsByRecencyProvider.overrideWith(
          (ref) => activeListsByRecencyBridge(),
        ),
        finishedListsForStoreProvider.overrideWith(
          (ref, storeId) => finishedListsBridge(storeId),
        ),
        finishedCountForStoreProvider.overrideWith(
          (ref, storeId) => finishedCountBridge(storeId),
        ),
        manualArchivedListsProvider.overrideWith(
          (ref) => manualArchivedBridge(),
        ),
        listByIdProvider.overrideWith((ref, id) => listByIdBridge(id)),
        listItemsProvider.overrideWith(
          (ref, listId) => listItemsBridge(listId),
        ),
        wishlistItemsProvider.overrideWith(
          (ref, storeId) => wishlistBridge(storeId),
        ),
        wishlistCountProvider.overrideWith(
          (ref, storeId) => wishlistCountBridge(storeId),
        ),
        ...overrides,
      ],
      child: ZeroCartApp(router: router),
    ),
  );

  await tester.runAsync(() async {
    await refreshInbox();
    await refreshStores();
    await refreshLists();
    await refreshWishlist();
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return TestAppHarness(
    db: db,
    refreshInbox: refreshInbox,
    refreshStores: refreshStores,
    refreshLists: refreshLists,
    refreshWishlist: refreshWishlist,
    inboxUpdates: inboxController,
    storeUpdates: storeController,
    storeSummaryUpdates: storeSummaryController,
    archivedStoreUpdates: archivedStoreController,
    allStoreUpdates: allStoreController,
    listsTickUpdates: listsTickController,
    listDetailsTickUpdates: listDetailsTickController,
    wishlistTickUpdates: wishlistTickController,
  );
}

/// Flushes real Drift work and rebuilds UI after a write or navigation.
///
/// Pumps first so new routes can subscribe to bridged streams, then refreshes
/// snapshots and pumps again so listeners receive the tick.
Future<void> pumpApp(WidgetTester tester, [TestAppHarness? harness]) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  if (harness != null) {
    await tester.runAsync(() async {
      await harness.refreshInbox();
      await harness.refreshStores();
      await harness.refreshLists();
      await harness.refreshWishlist();
    });
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
