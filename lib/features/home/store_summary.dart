import 'package:zero_cart/data/database.dart';

/// One active store as the Home board draws it (design system 3.12 / ST-2).
///
/// Richer than [ActiveStoreSummary]: item counts across active lists plus
/// last-activity for recency ordering. Do not reuse the Stores-tab summary.
class StoreSummary {
  const StoreSummary({
    required this.store,
    required this.activeListCount,
    required this.unpurchasedCount,
    required this.totalItemCount,
    required this.lastActivity,
  });

  final Store store;

  /// Active (non-archived) shopping lists for [store].
  final int activeListCount;

  /// Unpurchased items across all active lists of [store].
  final int unpurchasedCount;

  /// All items (purchased + unpurchased) across active lists of [store].
  final int totalItemCount;

  /// Latest active-list [ShoppingList.updatedAt], or the store's own
  /// [Store.updatedAt] when there are no active lists.
  final DateTime lastActivity;

  /// Purchased share of [totalItemCount], or 0 when the store has no items.
  double get purchasedProgress {
    if (totalItemCount == 0) {
      return 0;
    }
    return (totalItemCount - unpurchasedCount) / totalItemCount;
  }
}
