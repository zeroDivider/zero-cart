import 'package:zero_cart/features/lists/assign_inbox_target.dart';

export 'package:zero_cart/features/lists/assign_inbox_target.dart'
    show AssignListTarget, ExistingList, NewList;

/// Where to place wishlist copies (data model operation 7).
///
/// Same shapes as assign's list target: existing active list or a new list name.
/// Store is taken from the wishlist rows; targets are same-store lists only.
typedef CopyWishlistTarget = AssignListTarget;

/// Result of a successful [ListsRepository.copyWishlistItems] for UI feedback.
final class CopyWishlistResult {
  const CopyWishlistResult({required this.listId, required this.listName});

  final String listId;
  final String listName;
}
