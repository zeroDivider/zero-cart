import 'package:flutter/material.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/list_draft.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the list form. Returns a [ListDraft] on Save/Create, or null if dismissed.
///
/// Lives outside `ui/` so other features (e.g. store details) can open it without
/// importing `features/lists/ui/` (architecture §2.3). Callers write via repository.
Future<ListDraft?> showListFormSheet(
  BuildContext context, {
  ShoppingList? existing,
}) {
  return showModalBottomSheet<ListDraft>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ListFormSheet(existing: existing),
      );
    },
  );
}

/// Create/rename list form: name required, max 60, not unique (LI-1, D-08, D-09).
class ListFormSheet extends StatefulWidget {
  const ListFormSheet({this.existing, super.key});

  final ShoppingList? existing;

  @override
  State<ListFormSheet> createState() => _ListFormSheetState();
}

class _ListFormSheetState extends State<ListFormSheet> {
  late final TextEditingController _nameController;
  final _nameFocus = FocusNode();
  String? _nameError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _nameController.addListener(_onNameChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _nameFocus.requestFocus();
      }
    });
  }

  void _onNameChanged() {
    if (_nameError != null) {
      setState(() => _nameError = null);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _nameIsBlank => _nameController.text.trim().isEmpty;

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_nameIsBlank) {
      setState(() => _nameError = l10n.listNameRequired);
      return;
    }
    Navigator.of(context).pop(ListDraft(name: _nameController.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final canSave = !_nameIsBlank;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
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
            Text(
              _isEdit ? l10n.renameList : l10n.newList,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: tokens.spacing16),
            TextField(
              key: const Key('list_form_name'),
              controller: _nameController,
              focusNode: _nameFocus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              maxLength: maxListNameLength,
              decoration: InputDecoration(
                labelText: l10n.listNameLabel,
                hintText: l10n.listNameHint,
                errorText: _nameError,
              ),
              onSubmitted: (_) {
                if (canSave || _nameIsBlank) {
                  _save();
                }
              },
            ),
            SizedBox(height: tokens.spacing16),
            Row(
              children: [
                TextButton(
                  key: const Key('list_form_cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('list_form_save'),
                  onPressed: canSave || _nameIsBlank ? _save : null,
                  child: Text(_isEdit ? l10n.save : l10n.create),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
