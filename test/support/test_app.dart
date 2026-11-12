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
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';

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
    required StreamController<List<InboxItem>> inboxUpdates,
    required StreamController<List<Store>> storeUpdates,
    required StreamController<List<Store>> archivedStoreUpdates,
    required StreamController<List<Store>> allStoreUpdates,
    required StreamController<void> listsTickUpdates,
  }) : _inboxController = inboxUpdates,
       _storeController = storeUpdates,
       _archivedStoreController = archivedStoreUpdates,
       _allStoreController = allStoreUpdates,
       _listsTickController = listsTickUpdates;

  final AppDatabase db;
  final Future<void> Function() refreshInbox;
  final Future<void> Function() refreshStores;
  final Future<void> Function() refreshLists;
  final StreamController<List<InboxItem>> _inboxController;
  final StreamController<List<Store>> _storeController;
  final StreamController<List<Store>> _archivedStoreController;
  final StreamController<List<Store>> _allStoreController;
  final StreamController<void> _listsTickController;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _inboxController.close();
    await _storeController.close();
    await _archivedStoreController.close();
    await _allStoreController.close();
    await _listsTickController.close();
    await tester.runAsync(db.close);
  }
}

/// Pumps [ZeroCartApp] with an in-memory database and faked clock/ids.
///
/// Widget tests using this harness cover UI → repository → DB behaviour.
/// They do **not** prove live Drift `.watch()` → Riverpod wiring: under
/// FakeAsync on Windows, `.watch()` does not emit, so [inboxItemsProvider],
/// [activeStoresProvider], [archivedStoresProvider], [storeByIdProvider] and
/// [activeListsForStoreProvider] are bridged by broadcast streams that
/// [pumpApp] refreshes after real writes against [TestAppHarness.db].
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
  final archivedStoreController = StreamController<List<Store>>.broadcast();
  final allStoreController = StreamController<List<Store>>.broadcast();
  final listsTickController = StreamController<void>.broadcast();

  var latestInbox = <InboxItem>[];
  var latestActive = <Store>[];
  var latestArchived = <Store>[];
  var latestAll = <Store>[];
  final latestListsByStore = <String, List<ActiveListProgress>>{};

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
  }

  Future<void> refreshLists() async {
    final storeIds = <String>{
      ...latestAll.map((s) => s.id),
      ...latestListsByStore.keys,
    };
    for (final storeId in storeIds) {
      latestListsByStore[storeId] = await loadActiveLists(storeId);
    }
    if (!listsTickController.isClosed) {
      listsTickController.add(null);
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(fixedClock),
        idGeneratorProvider.overrideWithValue(ids),
        inboxItemsProvider.overrideWith((ref) => inboxBridge()),
        activeStoresProvider.overrideWith((ref) => activeStoresBridge()),
        archivedStoresProvider.overrideWith((ref) => archivedStoresBridge()),
        storeByIdProvider.overrideWith((ref, id) => storeByIdBridge(id)),
        activeListsForStoreProvider.overrideWith(
          (ref, storeId) => listsBridge(storeId),
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
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return TestAppHarness(
    db: db,
    refreshInbox: refreshInbox,
    refreshStores: refreshStores,
    refreshLists: refreshLists,
    inboxUpdates: inboxController,
    storeUpdates: storeController,
    archivedStoreUpdates: archivedStoreController,
    allStoreUpdates: allStoreController,
    listsTickUpdates: listsTickController,
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
    });
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
