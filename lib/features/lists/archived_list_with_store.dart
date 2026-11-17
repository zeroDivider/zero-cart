import 'package:zero_cart/data/database.dart';

/// A manually archived list joined with its store (Archive Lists segment).
///
/// Exposes [storeArchivedAt] so the UI can apply LI-5 without a second query.
class ArchivedListWithStore {
  const ArchivedListWithStore({
    required this.list,
    required this.storeName,
    required this.storeColorKey,
    required this.storeArchivedAt,
  });

  final ShoppingList list;

  /// Store display name at query time.
  final String storeName;

  /// Palette key for the store colour dot.
  final String storeColorKey;

  /// Non-null when the parent store is archived (LI-5).
  final DateTime? storeArchivedAt;

  bool get isStoreArchived => storeArchivedAt != null;
}
