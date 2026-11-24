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

/// Optional left-side action for [FormSheetScaffold] (ADR-0007 amendment).
///
/// Use [FormSheetSecondaryAction.submit] for a second submit path (e.g. Add
/// another) or [FormSheetSecondaryAction.button] for a custom action (e.g.
/// Remove) that does not run [FormSheetScaffold.onSubmit].
class FormSheetSecondaryAction {
  /// Runs [FormSheetScaffold.onSubmit]; pops only when [popOnSuccess] is true.
  const FormSheetSecondaryAction.submit({
    required this.label,
    this.key,
    this.popOnSuccess = false,
    this.onKeepOpenSuccess,
  }) : onPressed = null,
       _submits = true;

  /// Calls [onPressed] without running submit (disabled while submitting).
  const FormSheetSecondaryAction.button({
    required this.label,
    required VoidCallback this.onPressed,
    this.key,
  }) : popOnSuccess = false,
       onKeepOpenSuccess = null,
       _submits = false;

  final String label;
  final Key? key;
  final bool popOnSuccess;
  final VoidCallback? onPressed;

  /// Called after a successful secondary submit when [popOnSuccess] is false.
  final VoidCallback? onKeepOpenSuccess;

  final bool _submits;
}

/// Shared bottom-sheet form shell: submitting state, inline error, close on
/// success (ADR-0007).
///
/// [onSubmit] performs the write (or returns a draft and writes nothing).
/// On success the sheet pops with the result when [popOnSuccess] is true; on
/// failure it stays open and shows a localised inline error. Actions are
/// disabled while submitting.
class FormSheetScaffold<T> extends StatefulWidget {
  const FormSheetScaffold({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.body,
    this.submitKey,
    this.popOnSuccess = true,
    this.secondaryAction,
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

  /// When true (default), pops with the submit result after a successful
  /// primary submit. Secondary submit uses its own [FormSheetSecondaryAction.popOnSuccess].
  final bool popOnSuccess;

  /// Optional TextButton shown to the left of the primary submit.
  final FormSheetSecondaryAction? secondaryAction;

  @override
  State<FormSheetScaffold<T>> createState() => _FormSheetScaffoldState<T>();
}

/// Handle exposed to [FormSheetScaffold.body].
class FormSheetController {
  const FormSheetController({
    required this.isSubmitting,
    required this.error,
    required this.clearError,
    required this.submit,
  });

  final bool isSubmitting;
  final String? error;
  final VoidCallback clearError;

  /// Runs the primary submit path (same as the FilledButton).
  final VoidCallback submit;
}

class _FormSheetScaffoldState<T> extends State<FormSheetScaffold<T>> {
  bool _submitting = false;
  String? _error;

  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  Future<void> _submit({
    required bool shouldPop,
    VoidCallback? onKeepOpenSuccess,
  }) async {
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
      if (shouldPop) {
        Navigator.of(context).pop(result);
      } else {
        setState(() => _submitting = false);
        onKeepOpenSuccess?.call();
      }
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
      submit: () => _submit(shouldPop: widget.popOnSuccess),
    );
    final secondary = widget.secondaryAction;

    final primaryButton = FilledButton(
      key: widget.submitKey,
      onPressed: _submitting
          ? null
          : () => _submit(shouldPop: widget.popOnSuccess),
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
    );

    final Widget actions;
    if (secondary == null) {
      actions = primaryButton;
    } else {
      final VoidCallback? secondaryPressed;
      if (_submitting) {
        secondaryPressed = null;
      } else if (secondary._submits) {
        secondaryPressed = () => _submit(
          shouldPop: secondary.popOnSuccess,
          onKeepOpenSuccess: secondary.onKeepOpenSuccess,
        );
      } else {
        secondaryPressed = secondary.onPressed;
      }
      actions = Row(
        children: [
          TextButton(
            key: secondary.key,
            onPressed: secondaryPressed,
            child: Text(secondary.label),
          ),
          const Spacer(),
          primaryButton,
        ],
      );
    }

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
              // Shrink-wrap when the fields fit. Scroll only the body when
              // the keyboard leaves less room than the fields need, so the
              // title, inline error and actions stay above the keyboard.
              // Zero padding: a default ListView would re-apply the status-bar
              // inset that SafeArea intentionally leaves in MediaQuery.
              Flexible(
                child: ListView(
                  primary: false,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [widget.body(context, controller)],
                ),
              ),
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
              actions,
            ],
          ),
        ),
      ),
    );
  }
}
