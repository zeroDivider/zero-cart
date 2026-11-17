/// Typed repository failures surfaced to the UI via [messageFor] (ADR-0007).
///
/// Exhaustive: a new subtype forces an update to `messageFor`.
sealed class RepositoryException implements Exception {
  const RepositoryException();
}

/// Thrown when a list operation requires a non-archived store (LI-5, create).
final class StoreArchivedException extends RepositoryException {
  const StoreArchivedException([this.storeId]);

  final String? storeId;

  @override
  String toString() => storeId == null
      ? 'StoreArchivedException'
      : 'StoreArchivedException($storeId)';
}

/// Thrown when mutating or restoring against an archived list (D-13).
final class ListArchivedException extends RepositoryException {
  const ListArchivedException([this.listId]);

  final String? listId;

  @override
  String toString() => listId == null
      ? 'ListArchivedException'
      : 'ListArchivedException($listId)';
}

/// Thrown when restore cannot re-insert because the target list is missing
/// or archived (data-model op 2, APP-014).
final class ListUnavailableException extends RepositoryException {
  const ListUnavailableException([this.listId]);

  final String? listId;

  @override
  String toString() => listId == null
      ? 'ListUnavailableException'
      : 'ListUnavailableException($listId)';
}

/// Thrown when [orderedActiveIds] does not match the current active set.
final class StaleOrderException extends RepositoryException {
  const StaleOrderException();

  @override
  String toString() => 'StaleOrderException';
}

/// Defensive failure for an invalid wishlist copy (missing ids, mixed stores,
/// or a target that is not an active list in the wishlist's store).
///
/// Mapped to the generic user string; the UI cannot produce this case.
final class InvalidWishlistCopyException extends RepositoryException {
  const InvalidWishlistCopyException();

  @override
  String toString() => 'InvalidWishlistCopyException';
}
