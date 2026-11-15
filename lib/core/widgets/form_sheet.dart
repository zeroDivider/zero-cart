import 'package:flutter/material.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/ui/error_messages.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Thrown from [FormSheetScaffold.onSubmit] when sync field validation fails.
///
/// The sheet stays open and [FormSheetScaffold] shows no scaffold-level error;
/// the form body owns the field message (architecture: blank-title validation).
class FormValidationAbort implements Exception {
  const FormValidationAbort();
}

/// Shared bottom-sheet form shell: submitting state, inline error, close on
/// success (ADR-0007).
///
/// [onSubmit] performs the write (or returns a draft and writes nothing).
/// On success the sheet pops with the result; on failure it stays open and
/// shows a localised inline error. Actions are disabled while submitting.
class FormSheetScaffold<T> extends StatefulWidget {
  const FormSheetScaffold({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.body,
    this.submitKey,
  });

  final Widget title;
  final String submitLabel;

  /// Runs the write or returns a draft. Must not show its own snackbars.
  final Future<T> Function() onSubmit;

  /// Form fields. Use [FormSheetController.clearError] when the user edits.
  final Widget Function(BuildContext context, FormSheetController controller)
  body;

  /// Optional key for the submit button (widget tests).
  final Key? submitKey;

  @override
  State<FormSheetScaffold<T>> createState() => _FormSheetScaffoldState<T>();
}

/// Handle exposed to [FormSheetScaffold.body].
class FormSheetController {
  const FormSheetController({
    required this.isSubmitting,
    required this.error,
    required this.clearError,
  });

  final bool isSubmitting;
  final String? error;
  final VoidCallback clearError;
}

class _FormSheetScaffoldState<T> extends State<FormSheetScaffold<T>> {
  bool _submitting = false;
  String? _error;

  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } on FormValidationAbort {
      if (!mounted) {
        return;
      }
      setState(() => _submitting = false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = messageFor(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final theme = Theme.of(context);
    final controller = FormSheetController(
      isSubmitting: _submitting,
      error: _error,
      clearError: _clearError,
    );

    return PopScope(
      canPop: !_submitting,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing16,
            tokens.spacing8,
            tokens.spacing16,
            tokens.spacing16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DefaultTextStyle.merge(
                style: theme.textTheme.titleLarge,
                child: widget.title,
              ),
              SizedBox(height: tokens.spacing16),
              widget.body(context, controller),
              if (_error != null) ...[
                SizedBox(height: tokens.spacing8),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              SizedBox(height: tokens.spacing16),
              FilledButton(
                key: widget.submitKey,
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? SizedBox(
                        height: tokens.spacing24,
                        width: tokens.spacing24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
