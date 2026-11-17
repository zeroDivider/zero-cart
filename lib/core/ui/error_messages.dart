import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Maps a caught error to a localised user message (ADR-0007).
///
/// Every [RepositoryException] has its own string; anything else uses the
/// generic fallback. Callers must capture [l10n] before awaiting.
String messageFor(AppLocalizations l10n, Object error) {
  if (error is RepositoryException) {
    return switch (error) {
      StoreArchivedException() => l10n.errorStoreArchived,
      ListArchivedException() => l10n.errorListArchived,
      ListUnavailableException() => l10n.errorListUnavailable,
      StaleOrderException() => l10n.errorStaleOrder,
      // Defensive copy path; UI cannot produce it — same copy as unknown errors.
      InvalidWishlistCopyException() => l10n.errorGeneric,
    };
  }
  return l10n.errorGeneric;
}
