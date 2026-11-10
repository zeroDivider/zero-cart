import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the Quick add bottom sheet (D-02 / F1).
Future<void> showQuickAddSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: const QuickAddSheet(),
      );
    },
  );
}

/// Quick add form: title, optional description, Add / Add another.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocus = FocusNode();
  String? _titleError;
  String? _writeError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _titleFocus.requestFocus();
      }
    });
  }

  void _onTitleChanged() {
    if (_titleError != null || _writeError != null) {
      setState(() {
        _titleError = null;
        _writeError = null;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onTitleChanged)
      ..dispose();
    _descriptionController.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  bool get _titleIsBlank => _titleController.text.trim().isEmpty;

  Future<void> _submit({required bool addAnother}) async {
    final l10n = AppLocalizations.of(context);
    if (_titleIsBlank) {
      setState(() {
        _titleError = l10n.titleRequired;
        _writeError = null;
      });
      return;
    }
    if (_submitting) {
      return;
    }
    setState(() {
      _submitting = true;
      _titleError = null;
      _writeError = null;
    });
    try {
      await ref
          .read(inboxRepositoryProvider)
          .add(
            title: _titleController.text,
            description: _descriptionController.text,
          );
      if (!mounted) {
        return;
      }
      if (addAnother) {
        _titleController.clear();
        _descriptionController.clear();
        setState(() => _submitting = false);
        _titleFocus.requestFocus();
      } else {
        Navigator.of(context).pop();
      }
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _writeError = l10n.writeFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final canSubmit = !_titleIsBlank && !_submitting;

    return SafeArea(
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
            Text(l10n.quickAdd, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: tokens.spacing16),
            TextField(
              key: const Key('quick_add_title'),
              controller: _titleController,
              focusNode: _titleFocus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLength: maxItemTitleLength,
              buildCounter: _titleCounter,
              decoration: InputDecoration(
                labelText: l10n.itemTitleLabel,
                hintText: l10n.itemTitleHint,
                errorText: _titleError,
              ),
              onSubmitted: (_) {
                if (canSubmit || _titleIsBlank) {
                  _submit(addAnother: false);
                }
              },
            ),
            SizedBox(height: tokens.spacing12),
            TextField(
              key: const Key('quick_add_description'),
              controller: _descriptionController,
              textInputAction: TextInputAction.done,
              maxLength: maxItemDescriptionLength,
              decoration: InputDecoration(
                labelText: l10n.itemDescriptionLabel,
                hintText: l10n.itemDescriptionHint,
                counterText: '',
              ),
            ),
            if (_writeError != null) ...[
              SizedBox(height: tokens.spacing8),
              Text(
                _writeError!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            SizedBox(height: tokens.spacing16),
            Row(
              children: [
                TextButton(
                  key: const Key('quick_add_another'),
                  onPressed: canSubmit
                      ? () => _submit(addAnother: true)
                      : (_titleIsBlank
                            ? () => _submit(addAnother: true)
                            : null),
                  child: Text(l10n.addAnother),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('quick_add_submit'),
                  onPressed: canSubmit
                      ? () => _submit(addAnother: false)
                      : (_titleIsBlank
                            ? () => _submit(addAnother: false)
                            : null),
                  child: Text(l10n.add),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget? _titleCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (currentLength < 40 || maxLength == null) {
      return const SizedBox.shrink();
    }
    return Text('$currentLength / $maxLength');
  }
}
