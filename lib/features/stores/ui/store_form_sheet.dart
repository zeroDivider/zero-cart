import 'package:flutter/material.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/stores/store_draft.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the store form. Returns a [StoreDraft] on Save, or null if dismissed.
///
/// Does not write to the database — callers perform create/update (APP-015 reuse).
Future<StoreDraft?> showStoreFormSheet(
  BuildContext context, {
  Store? existing,
  String? initialColorKey,
}) {
  return showModalBottomSheet<StoreDraft>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: StoreFormSheet(
          existing: existing,
          initialColorKey: initialColorKey,
        ),
      );
    },
  );
}

/// Create/edit store form: name, colour chips, optional address and note.
class StoreFormSheet extends StatefulWidget {
  const StoreFormSheet({this.existing, this.initialColorKey, super.key});

  final Store? existing;
  final String? initialColorKey;

  @override
  State<StoreFormSheet> createState() => _StoreFormSheetState();
}

class _StoreFormSheetState extends State<StoreFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;
  final _nameFocus = FocusNode();
  late String _colorKey;
  String? _nameError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _colorKey =
        existing?.colorKey ??
        widget.initialColorKey ??
        AppTokens.storePaletteKeys.first;
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
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    _addressController.dispose();
    _noteController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _nameIsBlank => _nameController.text.trim().isEmpty;

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (_nameIsBlank) {
      setState(() => _nameError = l10n.storeNameRequired);
      return;
    }
    Navigator.of(context).pop(
      StoreDraft(
        name: _nameController.text,
        colorKey: _colorKey,
        address: _addressController.text,
        note: _noteController.text,
      ),
    );
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
              _isEdit ? l10n.editStore : l10n.newStore,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: tokens.spacing16),
            TextField(
              key: const Key('store_form_name'),
              controller: _nameController,
              focusNode: _nameFocus,
              autofocus: true,
              textInputAction: TextInputAction.next,
              maxLength: maxStoreNameLength,
              decoration: InputDecoration(
                labelText: l10n.storeNameLabel,
                hintText: l10n.storeNameHint,
                errorText: _nameError,
              ),
              onSubmitted: (_) {
                if (canSave || _nameIsBlank) {
                  _save();
                }
              },
            ),
            SizedBox(height: tokens.spacing12),
            Text(
              l10n.storeColorLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: tokens.spacing8),
            Wrap(
              spacing: tokens.spacing8,
              runSpacing: tokens.spacing8,
              children: [
                for (final key in AppTokens.storePaletteKeys)
                  _ColorChip(
                    colorKey: key,
                    selected: _colorKey == key,
                    color: tokens.storeColor(key),
                    onSelected: () => setState(() => _colorKey = key),
                  ),
              ],
            ),
            SizedBox(height: tokens.spacing16),
            TextField(
              key: const Key('store_form_address'),
              controller: _addressController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.storeAddressLabel,
                hintText: l10n.storeAddressHint,
              ),
            ),
            SizedBox(height: tokens.spacing12),
            TextField(
              key: const Key('store_form_note'),
              controller: _noteController,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.storeNoteLabel,
                hintText: l10n.storeNoteHint,
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
                  key: const Key('store_form_cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const Spacer(),
                FilledButton(
                  key: const Key('store_form_save'),
                  onPressed: canSave || _nameIsBlank ? _save : null,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  const _ColorChip({
    required this.colorKey,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final String colorKey;
  final bool selected;
  final Color color;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: l10n.storeColorSemantics(colorKey),
      child: InkWell(
        key: Key('store_color_$colorKey'),
        onTap: onSelected,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        // Fixed 48dp target — Center under loose Wrap constraints expands to
        // full width and stacks every colour in its own row.
        child: SizedBox(
          width: tokens.spacing48,
          height: tokens.spacing48,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: tokens.spacing24 + tokens.spacing8,
              height: tokens.spacing24 + tokens.spacing8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.outlineVariant,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
