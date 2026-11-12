import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/widgets/remove_undo_snackbar.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/inbox/inbox_edit_controller.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the edit sheet for an inbox item. Dismiss without Save discards edits.
Future<void> showInboxEditSheet(BuildContext context, InboxItem item) {
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
        child: InboxEditSheet(item: item),
      );
    },
  );
}

/// Edit title/description; Save writes, Remove deletes with Undo (D-19, D-22).
class InboxEditSheet extends ConsumerStatefulWidget {
  const InboxEditSheet({required this.item, super.key});

  final InboxItem item;

  @override
  ConsumerState<InboxEditSheet> createState() => _InboxEditSheetState();
}

class _InboxEditSheetState extends ConsumerState<InboxEditSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(
      text: widget.item.description ?? '',
    );
    _titleController.addListener(_onTitleChanged);
  }

  void _onTitleChanged() {
    ref.read(inboxEditControllerProvider(widget.item.id).notifier).clearError();
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
    super.dispose();
  }

  bool get _titleIsBlank => _titleController.text.trim().isEmpty;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_titleIsBlank) {
      setState(() => _titleError = l10n.titleRequired);
      return;
    }
    setState(() => _titleError = null);
    final ok = await ref
        .read(inboxEditControllerProvider(widget.item.id).notifier)
        .save(
          title: _titleController.text,
          description: _descriptionController.text,
          errorMessage: l10n.writeFailed,
        );
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final InboxRepository repository = ref.read(inboxRepositoryProvider);
    final id = widget.item.id;
    Navigator.of(context).pop();
    final snapshot = await repository.remove(id);
    showRemoveUndoSnackBar(
      message: l10n.removedItem(snapshot.title),
      undoLabel: l10n.undo,
      onUndo: () => repository.restore(snapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final ctrl = ref.watch(inboxEditControllerProvider(widget.item.id));
    final titleIsBlank = _titleIsBlank;
    final canSave = !titleIsBlank && !ctrl.submitting;

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
            Text(l10n.editItem, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: tokens.spacing16),
            TextField(
              key: const Key('inbox_edit_title'),
              controller: _titleController,
              textInputAction: TextInputAction.done,
              maxLength: maxItemTitleLength,
              buildCounter: _titleCounter,
              decoration: InputDecoration(
                labelText: l10n.itemTitleLabel,
                hintText: l10n.itemTitleHint,
                errorText: _titleError,
              ),
              onSubmitted: (_) {
                if (canSave || titleIsBlank) {
                  _save();
                }
              },
            ),
            SizedBox(height: tokens.spacing12),
            TextField(
              key: const Key('inbox_edit_description'),
              controller: _descriptionController,
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
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            SizedBox(height: tokens.spacing16),
            Row(
              children: [
                TextButton(
                  key: const Key('inbox_edit_remove'),
                  onPressed: ctrl.submitting ? null : _remove,
                  child: Text(l10n.remove),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('inbox_edit_save'),
                  onPressed: canSave ? _save : (titleIsBlank ? _save : null),
                  child: Text(l10n.save),
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
