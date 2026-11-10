import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// Local SQLite database for ZeroCart (schema version 1).
@DriftDatabase(
  tables: [
    Stores,
    ShoppingLists,
    ListItems,
    InboxItems,
    WishlistItems,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens with an explicit [executor] (tests pass an in-memory one).
  AppDatabase(super.executor);

  /// File database `zero_cart.sqlite` in the app documents directory.
  AppDatabase.file() : super(_openFileConnection());

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  static QueryExecutor _openFileConnection() {
    // drift_flutter stores `$name.sqlite` under the application documents dir.
    return driftDatabase(name: 'zero_cart');
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        // SQLite does not enforce foreign keys unless this pragma is set.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }
}
