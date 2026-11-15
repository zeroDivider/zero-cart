import 'package:flutter/material.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/list_draft.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the list create/rename form.
///
/// [onSubmit] performs the write (or returns a draft). Failure keeps the sheet
/// open with an inline error (ADR-0007). Lives in `ui/sheets/` so other
/// features may import it without importing list screens.
Future<T?> showListFormSheet<T>(
  BuildContext context, {
  ShoppingList? existing,
  required Future<T> Function(ListDraft draft) onSubmit,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ListFormSheet<T>(existing: existing, onSubmit: onSubmit),
      );
    },
  );
}

/// Create/rename list form: name required, max 60, not unique (LI-1, D-08, D-09).
class ListFormSheet<T> extends StatefulWidget {
  const ListFormSheet({this.existing, required this.onSubmit, super.key});

  final ShoppingList? existing;
  final Future<T> Function(ListDraft draft) onSubmit;

  @override
  State<ListFormSheet<T>> createState() => _ListFormSheetState<T>();
}

class _ListFormSheetState<T> extends State<ListFormSheet<T>> {
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

  Future<T> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (_nameIsBlank) {
      setState(() => _nameError = l10n.listNameRequired);
      throw const FormValidationAbort();
    }
    return widget.onSubmit(ListDraft(name: _nameController.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return FormSheetScaffold<T>(
      title: Text(_isEdit ? l10n.renameList : l10n.newList),
      submitLabel: _isEdit ? l10n.save : l10n.create,
      submitKey: const Key('list_form_save'),
      onSubmit: _submit,
      body: (context, controller) {
        return TextField(
          key: const Key('list_form_name'),
          controller: _nameController,
          focusNode: _nameFocus,
          autofocus: true,
          enabled: !controller.isSubmitting,
          textInputAction: TextInputAction.done,
          maxLength: maxListNameLength,
          decoration: InputDecoration(
            labelText: l10n.listNameLabel,
            hintText: l10n.listNameHint,
            errorText: _nameError,
          ),
          onChanged: (_) => controller.clearError(),
        );
      },
    );
  }
}
