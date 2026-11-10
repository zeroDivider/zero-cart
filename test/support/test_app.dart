import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/app.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';

/// Pumps [ZeroCartApp] with an in-memory database and faked clock/ids.
Future<AppDatabase> pumpTestApp(
  WidgetTester tester, {
  GoRouter? router,
  Clock? clock,
  IdGenerator? idGenerator,
  List<Override> overrides = const [],
}) async {
  final db = AppDatabase.memory();
  var idCounter = 0;
  final fixedClock = clock ?? () => DateTime.utc(2026, 1, 1, 12);
  final ids =
      idGenerator ??
      () {
        idCounter += 1;
        return 'test-id-$idCounter';
      };

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        nowProvider.overrideWithValue(fixedClock),
        idGeneratorProvider.overrideWithValue(ids),
        ...overrides,
      ],
      child: ZeroCartApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(db.close);
  return db;
}
