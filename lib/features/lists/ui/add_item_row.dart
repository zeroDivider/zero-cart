import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/features/lists/add_item_notifier.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Inline quick-add row at the end of the active section (IT-1).
class AddItemRow extends ConsumerStatefulWidget {
  const AddItemRow({required this.listId, super.key});

  final String listId;

  @override
  ConsumerState<AddItemRow> createState() => _AddItemRowState();
}

class _AddItemRowState extends ConsumerState<AddItemRow> {
  final _addController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addFocus = FocusNode();
  bool _showDetails = false;
  String? _addError;

  @override
  void dispose() {
    _addController.dispose();
    _descriptionController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _doAddItem() async {
    final l10n = AppLocalizations.of(context);
    final title = _addController.text;
    if (title.trim().isEmpty) {
      setState(() => _addError = l10n.titleRequired);
      return;
    }
    setState(() => _addError = null);
    await ref
        .read(addItemNotifierProvider(widget.listId).notifier)
        .addItem(
          title: title,
          description: _showDetails ? _descriptionController.text : null,
          errorMessage: l10n.writeFailed,
        );
    if (!mounted) {
      return;
    }
    final ctrl = ref.read(addItemNotifierProvider(widget.listId));
    if (ctrl.error == null && !ctrl.submitting) {
      _addController.clear();
      _descriptionController.clear();
      _addFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final addCtrl = ref.watch(addItemNotifierProvider(widget.listId));

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing16,
        vertical: tokens.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('list_add_title'),
                  controller: _addController,
                  focusNode: _addFocus,
                  textInputAction: TextInputAction.done,
                  maxLength: maxItemTitleLength,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) {
                        if (currentLength < 40 || maxLength == null) {
                          return const SizedBox.shrink();
                        }
                        return Text('$currentLength / $maxLength');
                      },
                  decoration: InputDecoration(
                    hintText: l10n.addItemHint,
                    errorText: _addError ?? addCtrl.error,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    ref
                        .read(addItemNotifierProvider(widget.listId).notifier)
                        .clearError();
                    if (_addError != null) {
                      setState(() => _addError = null);
                    }
                  },
                  onSubmitted: (_) {
                    if (!addCtrl.submitting) {
                      _doAddItem();
                    }
                  },
                ),
              ),
              TextButton(
                key: const Key('list_add_details_toggle'),
                onPressed: () => setState(() => _showDetails = !_showDetails),
                child: Text(l10n.addItemDetailsToggle),
              ),
            ],
          ),
          if (_showDetails)
            TextField(
              key: const Key('list_add_description'),
              controller: _descriptionController,
              maxLength: maxItemDescriptionLength,
              decoration: InputDecoration(
                hintText: l10n.itemDescriptionHint,
                counterText: '',
                border: InputBorder.none,
              ),
            ),
        ],
      ),
    );
  }
}
