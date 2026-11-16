import 'package:flutter/material.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/core/ui/error_messages.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Root snackbars for info, error and Undo (ADR-0007).
///
/// Always uses [rootScaffoldMessengerKey]. One snackbar at a time: each call
/// clears the current before showing. Feature code must not call
/// `ScaffoldMessenger.of(context)`.
abstract final class AppMessenger {
  static ScaffoldMessengerState? get _messenger =>
      rootScaffoldMessengerKey.currentState;

  /// Floating info snackbar (no action).
  static void info(String message) {
    _show(SnackBar(content: Text(message)));
  }

  /// Floating error snackbar (no action).
  static void error(String message) {
    _show(SnackBar(content: Text(message)));
  }

  /// Info snackbar with a single action (e.g. Open after assign or copy).
  static void action({
    required String message,
    required String actionLabel,
    required VoidCallback onPressed,
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(label: actionLabel, onPressed: onPressed),
      ),
    );
  }

  /// Undo snackbar. [onUndo] must capture repositories, not a disposed [ref].
  ///
  /// If [onUndo] throws, an error snackbar replaces this one immediately
  /// using [messageFor] and the captured [l10n].
  static void undo({
    required String message,
    required String undoLabel,
    required Future<void> Function() onUndo,
    required AppLocalizations l10n,
    Duration duration = const Duration(seconds: 5),
  }) {
    _show(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(
          label: undoLabel,
          onPressed: () {
            onUndo().then(
              (_) {},
              onError: (Object error, StackTrace stackTrace) {
                AppMessenger.error(messageFor(l10n, error));
              },
            );
          },
        ),
      ),
    );
  }

  static void _show(SnackBar snackBar) {
    final messenger = _messenger;
    if (messenger == null) {
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(snackBar);
  }
}
