import 'package:zero_cart/core/ui/app_messenger.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/features/lists/finish_list_result.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Finishes a list with no leftovers and shows a 5s Undo snackbar (LI-4, F10).
///
/// [repository] must be captured by the caller before navigation so Undo still
/// works after leaving the list screen. A failed Undo shows [messageFor]
/// immediately via [AppMessenger.undo] (ADR-0007).
///
/// Returns the [FinishListResult] on success, or `null` when the write failed.
Future<FinishListResult?> finishListWithUndo({
  required ListsRepository repository,
  required String listId,
  required AppLocalizations l10n,
}) async {
  FinishListResult? result;
  final ok = await runWrite(() async {
    result = await repository.finishList(listId, carryForward: false);
    final archivedId = result!.archivedListId;
    AppMessenger.undo(
      message: l10n.listFinished,
      undoLabel: l10n.undo,
      l10n: l10n,
      onUndo: () => repository.restore(archivedId),
    );
  }, l10n: l10n);
  return ok ? result : null;
}
