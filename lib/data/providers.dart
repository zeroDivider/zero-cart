import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/data/database.dart';

/// App-lifetime Drift database. Overridden in [main] and in tests.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError(
    'appDatabaseProvider must be overridden with an open database',
  );
});

/// Injectable clock; widgets and repositories must not call [DateTime.now].
final nowProvider = Provider<Clock>((ref) => systemClock);

/// Injectable UUID generator for portable row ids.
final idGeneratorProvider = Provider<IdGenerator>((ref) => generateUuidV4);
