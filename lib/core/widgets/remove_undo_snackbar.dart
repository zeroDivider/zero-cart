import 'package:flutter/material.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';

/// Shows a floating Undo snackbar on the root messenger (D-07: one Undo at a time).
///
/// When [undoFailureMessage] is set and [onUndo] throws, that message is shown
/// after this snackbar finishes closing so the dismiss does not clear it.
void showRemoveUndoSnackBar({
  required String message,
  required String undoLabel,
  required Future<void> Function() onUndo,
  String? undoFailureMessage,
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) {
    return;
  }
  messenger.clearSnackBars();
  late final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
  controller;
  controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: duration,
      action: SnackBarAction(
        label: undoLabel,
        onPressed: () {
          onUndo().then(
            (_) {},
            onError: (Object error, StackTrace stackTrace) async {
              if (undoFailureMessage == null) {
                return;
              }
              await controller.closed;
              rootScaffoldMessengerKey.currentState?.showSnackBar(
                SnackBar(content: Text(undoFailureMessage)),
              );
            },
          );
        },
      ),
    ),
  );
}
