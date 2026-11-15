import 'package:zero_cart/core/ui/app_messenger.dart';
import 'package:zero_cart/core/ui/error_messages.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

export 'package:zero_cart/core/ui/error_messages.dart' show messageFor;

/// Runs a direct-action write and shows an error snackbar on failure.
///
/// Returns `true` on success and `false` after surfacing a localised error.
/// Never shows raw exception text. Callers capture [l10n] before awaiting.
Future<bool> runWrite(
  Future<void> Function() action, {
  required AppLocalizations l10n,
}) async {
  try {
    await action();
    return true;
  } catch (error) {
    AppMessenger.error(messageFor(l10n, error));
    return false;
  }
}
