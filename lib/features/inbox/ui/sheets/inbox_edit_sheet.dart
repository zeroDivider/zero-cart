import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/ui/app_messenger.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/data/database.dart';
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

  Future<void> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (_titleIsBlank) {
      setState(() => _titleError = l10n.titleRequired);
      throw const FormValidationAbort();
    }
    setState(() => _titleError = null);
    await ref
        .read(inboxRepositoryProvider)
        .update(
          id: widget.item.id,
          title: _titleController.text,
          description: _descriptionController.text,
        );
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final InboxRepository repository = ref.read(inboxRepositoryProvider);
    final id = widget.item.id;
    Navigator.of(context).pop();
    await runWrite(() async {
      final snapshot = await repository.remove(id);
      AppMessenger.undo(
        message: l10n.removedItem(snapshot.title),
        undoLabel: l10n.undo,
        l10n: l10n,
        onUndo: () => repository.restore(snapshot),
      );
    }, l10n: l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return FormSheetScaffold<void>(
      title: Text(l10n.editItem),
      submitLabel: l10n.save,
      submitKey: const Key('inbox_edit_save'),
      onSubmit: _onSubmit,
      secondaryAction: FormSheetSecondaryAction.button(
        label: l10n.remove,
        key: const Key('inbox_edit_remove'),
        onPressed: _remove,
      ),
      body: (context, controller) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('inbox_edit_title'),
              controller: _titleController,
              enabled: !controller.isSubmitting,
              textInputAction: TextInputAction.done,
              maxLength: maxItemTitleLength,
              buildCounter: _titleCounter,
              decoration: InputDecoration(
                labelText: l10n.itemTitleLabel,
                hintText: l10n.itemTitleHint,
                errorText: _titleError,
              ),
              onChanged: (_) => controller.clearError(),
              onSubmitted: (_) {
                if (!controller.isSubmitting) {
                  controller.submit();
                }
              },
            ),
            SizedBox(height: tokens.spacing12),
            TextField(
              key: const Key('inbox_edit_description'),
              controller: _descriptionController,
              enabled: !controller.isSubmitting,
              maxLength: maxItemDescriptionLength,
              decoration: InputDecoration(
                labelText: l10n.itemDescriptionLabel,
                hintText: l10n.itemDescriptionHint,
                counterText: '',
              ),
              onChanged: (_) => controller.clearError(),
            ),
          ],
        );
      },
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
