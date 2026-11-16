import 'package:zero_cart/core/ui/app_messenger.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Removes [itemId] and shows a 5s Undo snackbar (D-07, IT-6).
///
/// [repository] must be captured by the caller before navigation so Undo still
/// works after leaving the list screen. A failed Undo shows [messageFor]
/// immediately via [AppMessenger.undo] (ADR-0007).
Future<void> removeListItemWithUndo({
  required ListsRepository repository,
  required String itemId,
  required AppLocalizations l10n,
}) async {
  await runWrite(() async {
    final snapshot = await repository.removeItem(itemId);
    AppMessenger.undo(
      message: l10n.removedItem(snapshot.title),
      undoLabel: l10n.undo,
      l10n: l10n,
      onUndo: () => repository.restoreItem(snapshot),
    );
  }, l10n: l10n);
}
