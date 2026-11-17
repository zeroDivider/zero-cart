/// Outcome of finishing a shopping list (data model ops 8–9).
final class FinishListResult {
  const FinishListResult({
    required this.archivedListId,
    required this.newListId,
    required this.carriedCount,
  });

  /// The list that was archived with reason `finished`.
  final String archivedListId;

  /// New leftovers list when carry-forward ran; otherwise null.
  final String? newListId;

  /// Number of unpurchased items copied onto [newListId] (0 when none).
  final int carriedCount;
}
