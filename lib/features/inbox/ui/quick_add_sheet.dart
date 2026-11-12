import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/features/inbox/quick_add_controller.dart';
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
    ref.read(quickAddControllerProvider.notifier).clearError();
    if (_titleError != null) {
      setState(() => _titleError = null);
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
      setState(() => _titleError = l10n.titleRequired);
      return;
    }
    setState(() => _titleError = null);
    final ok = await ref
        .read(quickAddControllerProvider.notifier)
        .submit(
          title: _titleController.text,
          description: _descriptionController.text,
          errorMessage: l10n.writeFailed,
        );
    if (!ok || !mounted) {
      return;
    }
    if (addAnother) {
      _titleController.clear();
      _descriptionController.clear();
      _titleFocus.requestFocus();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final ctrl = ref.watch(quickAddControllerProvider);
    final titleIsBlank = _titleIsBlank;
    final canSubmit = !titleIsBlank && !ctrl.submitting;

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
                if (canSubmit || titleIsBlank) {
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
            if (ctrl.error != null) ...[
              SizedBox(height: tokens.spacing8),
              Text(
                ctrl.error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            SizedBox(height: tokens.spacing16),
            Row(
              children: [
                TextButton(
                  key: const Key('quick_add_another'),
                  onPressed: canSubmit
                      ? () => _submit(addAnother: true)
                      : (titleIsBlank
                            ? () => _submit(addAnother: true)
                            : null),
                  child: Text(l10n.addAnother),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('quick_add_submit'),
                  onPressed: canSubmit
                      ? () => _submit(addAnother: false)
                      : (titleIsBlank
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
