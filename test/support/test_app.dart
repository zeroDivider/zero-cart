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

bool _driftMultiDbWarningSilenced = false;

void _silenceDriftMultiDbWarning() {
  if (_driftMultiDbWarningSilenced) {
    return;
  }
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  _driftMultiDbWarningSilenced = true;
}

/// Harness returned by [pumpTestApp].
class TestAppHarness {
  TestAppHarness({
    required this.db,
    required this.refreshInbox,
    required StreamController<List<InboxItem>> inboxUpdates,
  }) : _inboxController = inboxUpdates;

  final AppDatabase db;
  final Future<void> Function() refreshInbox;
  final StreamController<List<InboxItem>> _inboxController;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _inboxController.close();
    await tester.runAsync(db.close);
  }
}

/// Pumps [ZeroCartApp] with an in-memory database and faked clock/ids.
///
/// Drift's `.watch()` does not emit under FakeAsync on Windows widget tests, so
/// [inboxItemsProvider] is fed by a broadcast stream refreshed via [pumpApp]
/// after real repository writes (still against [TestAppHarness.db]).
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

  Future<void> refreshInbox() async {
    final rows =
        await (db.select(db.inboxItems)..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
            .get();
    if (!inboxController.isClosed) {
      inboxController.add(rows);
    }
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(fixedClock),
        idGeneratorProvider.overrideWithValue(ids),
        inboxItemsProvider.overrideWith((ref) => inboxController.stream),
        ...overrides,
      ],
      child: ZeroCartApp(router: router),
    ),
  );

  await tester.runAsync(refreshInbox);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  return TestAppHarness(
    db: db,
    refreshInbox: refreshInbox,
    inboxUpdates: inboxController,
  );
}

/// Flushes real Drift work and rebuilds UI after a write or navigation.
Future<void> pumpApp(WidgetTester tester, [TestAppHarness? harness]) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  if (harness != null) {
    await tester.runAsync(harness.refreshInbox);
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
