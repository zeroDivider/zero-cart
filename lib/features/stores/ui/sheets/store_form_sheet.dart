import 'package:flutter/material.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/stores/store_draft.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the store create/edit form.
///
/// When [draftMode] is true, Save returns a [StoreDraft] and writes nothing
/// (APP-015 assignment). Otherwise [repository] is required and the sheet
/// persists on submit; failure keeps the sheet open with an inline error.
Future<StoreDraft?> showStoreFormSheet(
  BuildContext context, {
  Store? existing,
  String? initialColorKey,
  bool draftMode = false,
  StoresRepository? repository,
}) {
  assert(
    draftMode || repository != null,
    'repository is required when draftMode is false',
  );
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
          draftMode: draftMode,
          repository: repository,
        ),
      );
    },
  );
}

/// Create/edit store form: name, colour chips, optional address and note.
class StoreFormSheet extends StatefulWidget {
  const StoreFormSheet({
    this.existing,
    this.initialColorKey,
    this.draftMode = false,
    this.repository,
    super.key,
  });

  final Store? existing;
  final String? initialColorKey;
  final bool draftMode;
  final StoresRepository? repository;

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

  StoreDraft _draft() {
    return StoreDraft(
      name: _nameController.text,
      colorKey: _colorKey,
      address: _addressController.text,
      note: _noteController.text,
    );
  }

  Future<StoreDraft> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (_nameIsBlank) {
      setState(() => _nameError = l10n.storeNameRequired);
      throw const FormValidationAbort();
    }
    final draft = _draft();
    if (widget.draftMode) {
      return draft;
    }
    final repository = widget.repository!;
    final existing = widget.existing;
    if (existing != null) {
      await repository.updateFromDraft(existing.id, draft);
    } else {
      await repository.createFromDraft(draft);
    }
    return draft;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return FormSheetScaffold<StoreDraft>(
      title: Text(_isEdit ? l10n.editStore : l10n.newStore),
      submitLabel: l10n.save,
      submitKey: const Key('store_form_save'),
      onSubmit: _onSubmit,
      body: (context, controller) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('store_form_name'),
                controller: _nameController,
                focusNode: _nameFocus,
                autofocus: true,
                enabled: !controller.isSubmitting,
                textInputAction: TextInputAction.next,
                maxLength: maxStoreNameLength,
                decoration: InputDecoration(
                  labelText: l10n.storeNameLabel,
                  hintText: l10n.storeNameHint,
                  errorText: _nameError,
                ),
                onChanged: (_) => controller.clearError(),
                onSubmitted: (_) {
                  if (!controller.isSubmitting) {
                    // Scaffold submit is the Save button; Enter still validates.
                    FocusScope.of(context).unfocus();
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
                      onSelected: controller.isSubmitting
                          ? null
                          : () {
                              setState(() => _colorKey = key);
                              controller.clearError();
                            },
                    ),
                ],
              ),
              SizedBox(height: tokens.spacing16),
              TextField(
                key: const Key('store_form_address'),
                controller: _addressController,
                enabled: !controller.isSubmitting,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.storeAddressLabel,
                  hintText: l10n.storeAddressHint,
                ),
                onChanged: (_) => controller.clearError(),
              ),
              SizedBox(height: tokens.spacing12),
              TextField(
                key: const Key('store_form_note'),
                controller: _noteController,
                enabled: !controller.isSubmitting,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.storeNoteLabel,
                  hintText: l10n.storeNoteHint,
                ),
                onChanged: (_) => controller.clearError(),
              ),
            ],
          ),
        );
      },
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
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onSelected != null,
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
