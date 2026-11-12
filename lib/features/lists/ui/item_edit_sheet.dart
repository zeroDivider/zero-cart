import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/item_edit_notifier.dart';
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

/// Edit title/description; Save writes (Remove arrives in APP-014).
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
    ref.read(itemEditNotifierProvider(widget.item.id).notifier).clearError();
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
        .read(itemEditNotifierProvider(widget.item.id).notifier)
        .save(
          title: _titleController.text,
          description: _descriptionController.text,
          errorMessage: l10n.writeFailed,
        );
    if (ok && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final ctrl = ref.watch(itemEditNotifierProvider(widget.item.id));
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
              key: const Key('item_edit_title'),
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
              key: const Key('item_edit_description'),
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
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: const Key('item_edit_save'),
                onPressed: canSave ? _save : (titleIsBlank ? _save : null),
                child: Text(l10n.save),
              ),
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
