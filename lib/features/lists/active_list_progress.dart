import 'package:zero_cart/data/database.dart';

/// An active shopping list with live item progress for store details.
class ActiveListProgress {
  const ActiveListProgress({
    required this.list,
    required this.itemsLeft,
    required this.itemsTotal,
  });

  final ShoppingList list;

  /// Unpurchased item count (`!is_purchased`).
  final int itemsLeft;

  /// All items on the list.
  final int itemsTotal;
}
