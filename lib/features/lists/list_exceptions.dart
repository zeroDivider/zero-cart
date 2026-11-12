/// Thrown when a list operation requires a non-archived store (LI-5, create).
class StoreArchivedException implements Exception {
  const StoreArchivedException([this.storeId]);

  final String? storeId;

  @override
  String toString() => storeId == null
      ? 'StoreArchivedException'
      : 'StoreArchivedException($storeId)';
}

/// Thrown when mutating or restoring against an archived list (D-13).
class ListArchivedException implements Exception {
  const ListArchivedException([this.listId]);

  final String? listId;

  @override
  String toString() => listId == null
      ? 'ListArchivedException'
      : 'ListArchivedException($listId)';
}
