import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/data/database.dart';

import 'generated_migrations/schema.dart';

/// Migration test scaffold for schema version 1 (APP-006).
///
/// When a later task bumps [AppDatabase.schemaVersion], add upgrade cases
/// with [SchemaVerifier.migrateAndValidate] and keep exporting snapshots to
/// `drift_schemas/`.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v1 schema matches the committed snapshot', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);

    // No upgrade path yet: opening at v1 and validating against the generated
    // helper confirms createAll matches drift_schemas/drift_schema_v1.json.
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });
}
