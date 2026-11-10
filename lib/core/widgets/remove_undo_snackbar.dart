import 'package:flutter/material.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';

/// Shows a floating Undo snackbar on the root messenger (D-07: one Undo at a time).
void showRemoveUndoSnackBar({
  required String message,
  required String undoLabel,
  required Future<void> Function() onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) {
    return;
  }
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: SnackBarAction(
        label: undoLabel,
        onPressed: () {
          onUndo();
        },
      ),
    ),
  );
}
