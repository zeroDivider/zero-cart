import 'package:flutter/material.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/core/widgets/remove_undo_snackbar.dart';
import 'package:zero_cart/features/lists/list_exceptions.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Removes [itemId] and shows a 5s Undo snackbar (D-07, IT-6).
///
/// [repository] must be captured by the caller before navigation so Undo still
/// works after leaving the list screen.
Future<void> removeListItemWithUndo({
  required ListsRepository repository,
  required String itemId,
  required AppLocalizations l10n,
}) async {
  final snapshot = await repository.removeItem(itemId);
  showRemoveUndoSnackBar(
    message: l10n.removedItem(snapshot.title),
    undoLabel: l10n.undo,
    onUndo: () async {
      try {
        await repository.restoreItem(snapshot);
      } on ListUnavailableException {
        final messenger = rootScaffoldMessengerKey.currentState;
        if (messenger == null) {
          return;
        }
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.couldNotRestore)));
      }
    },
  );
}
