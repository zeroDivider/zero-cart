import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/remove_item_undo.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the edit sheet for a list item. Dismiss without Save discards edits.
Future<void> showItemEditSheet(BuildContext context, ListItem item) {
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
        child: ItemEditSheet(item: item),
      );
    },
  );
}

/// Edit title/description; Remove deletes with Undo (D-07, IT-6).
class ItemEditSheet extends ConsumerStatefulWidget {
  const ItemEditSheet({required this.item, super.key});

  final ListItem item;

  @override
  ConsumerState<ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<ItemEditSheet> {
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
        .read(listsRepositoryProvider)
        .updateItem(
          id: widget.item.id,
          title: _titleController.text,
          description: _descriptionController.text,
        );
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final ListsRepository repository = ref.read(listsRepositoryProvider);
    final id = widget.item.id;
    Navigator.of(context).pop();
    await removeListItemWithUndo(
      repository: repository,
      itemId: id,
      l10n: l10n,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return FormSheetScaffold<void>(
      title: Text(l10n.editItem),
      submitLabel: l10n.save,
      submitKey: const Key('item_edit_save'),
      onSubmit: _onSubmit,
      secondaryAction: FormSheetSecondaryAction.button(
        label: l10n.remove,
        key: const Key('item_edit_remove'),
        onPressed: _remove,
      ),
      body: (context, controller) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('item_edit_title'),
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
              key: const Key('item_edit_description'),
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
