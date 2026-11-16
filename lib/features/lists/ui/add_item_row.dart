import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/ui/error_messages.dart';
import 'package:zero_cart/features/lists/add_item_notifier.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
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
  bool _submitting = false;
  String? _addError;
  String? _writeError;

  @override
  void dispose() {
    _addController.dispose();
    _descriptionController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _doAddItem() async {
    if (_submitting) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final title = _addController.text;
    if (title.trim().isEmpty) {
      setState(() {
        _addError = l10n.titleRequired;
        _writeError = null;
      });
      return;
    }
    setState(() {
      _addError = null;
      _writeError = null;
      _submitting = true;
    });
    try {
      final created = await ref
          .read(listsRepositoryProvider)
          .addItem(
            listId: widget.listId,
            title: title,
            description: _showDetails ? _descriptionController.text : null,
          );
      if (!mounted) {
        return;
      }
      ref
          .read(addItemNotifierProvider(widget.listId).notifier)
          .setPendingScroll(created.id);
      _addController.clear();
      _descriptionController.clear();
      setState(() => _submitting = false);
      _addFocus.requestFocus();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _writeError = messageFor(l10n, error);
      });
      _addFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;

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
                  enabled: !_submitting,
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
                    errorText: _addError ?? _writeError,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    if (_addError != null || _writeError != null) {
                      setState(() {
                        _addError = null;
                        _writeError = null;
                      });
                    }
                  },
                  onSubmitted: (_) {
                    if (!_submitting) {
                      _doAddItem();
                    }
                  },
                ),
              ),
              TextButton(
                key: const Key('list_add_details_toggle'),
                onPressed: _submitting
                    ? null
                    : () => setState(() => _showDetails = !_showDetails),
                child: Text(l10n.addItemDetailsToggle),
              ),
            ],
          ),
          if (_showDetails)
            TextField(
              key: const Key('list_add_description'),
              controller: _descriptionController,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              maxLength: maxItemDescriptionLength,
              decoration: InputDecoration(
                hintText: l10n.itemDescriptionHint,
                counterText: '',
                border: InputBorder.none,
              ),
              onSubmitted: (_) {
                if (!_submitting) {
                  _doAddItem();
                }
              },
            ),
        ],
      ),
    );
  }
}
