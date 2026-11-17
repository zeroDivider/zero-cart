import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/finish_list_result.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the finish-list sheet when unpurchased leftovers remain (LI-4, F10).
///
/// Returns [FinishListResult] on success; `null` if dismissed. Failure keeps the
/// sheet open with an inline error (ADR-0007).
Future<FinishListResult?> showFinishListSheet(
  BuildContext context, {
  required ShoppingList list,
  required int leftCount,
}) {
  return showModalBottomSheet<FinishListResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: FinishListSheet(list: list, leftCount: leftCount),
      );
    },
  );
}

/// Finish shopping form: leftovers count, name field, carry / archive actions.
class FinishListSheet extends ConsumerStatefulWidget {
  const FinishListSheet({
    required this.list,
    required this.leftCount,
    super.key,
  });

  final ShoppingList list;
  final int leftCount;

  @override
  ConsumerState<FinishListSheet> createState() => _FinishListSheetState();
}

class _FinishListSheetState extends ConsumerState<FinishListSheet> {
  late final TextEditingController _nameController;
  final _nameFocus = FocusNode();
  String? _nameError;
  bool _didPrefillName = false;

  /// Secondary "Archive without carrying" sets this false then calls submit.
  bool _carryForward = true;

  FormSheetController? _sheetController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _nameController.addListener(_onNameChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrefillName) {
      _didPrefillName = true;
      final l10n = AppLocalizations.of(context);
      final raw = l10n.leftoversName(widget.list.name);
      _nameController.text = raw.length <= maxListNameLength
          ? raw
          : raw.substring(0, maxListNameLength);
    }
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

  Future<FinishListResult> _submit() async {
    final carry = _carryForward;
    _carryForward = true;
    final l10n = AppLocalizations.of(context);
    if (carry && _nameIsBlank) {
      setState(() => _nameError = l10n.listNameRequired);
      throw const FormValidationAbort();
    }
    return ref
        .read(listsRepositoryProvider)
        .finishList(
          widget.list.id,
          carryForward: carry,
          newName: carry ? _nameController.text : null,
        );
  }

  void _archiveWithoutCarrying() {
    _carryForward = false;
    _sheetController?.submit();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return FormSheetScaffold<FinishListResult>(
      title: Text(l10n.finishSheetTitle),
      submitLabel: l10n.finishCarryForward,
      submitKey: const Key('finish_carry_forward'),
      onSubmit: _submit,
      secondaryAction: FormSheetSecondaryAction.button(
        label: l10n.finishArchiveWithout,
        key: const Key('finish_archive_without'),
        onPressed: _archiveWithoutCarrying,
      ),
      body: (context, controller) {
        _sheetController = controller;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              key: const Key('finish_left_count'),
              l10n.finishSheetLeftCount(widget.leftCount),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: tokens.spacing16),
            TextField(
              key: const Key('finish_leftovers_name'),
              controller: _nameController,
              focusNode: _nameFocus,
              enabled: !controller.isSubmitting,
              textInputAction: TextInputAction.done,
              maxLength: maxListNameLength,
              decoration: InputDecoration(
                labelText: l10n.listNameLabel,
                hintText: l10n.listNameHint,
                errorText: _nameError,
              ),
              onChanged: (_) => controller.clearError(),
              onSubmitted: (_) {
                if (!controller.isSubmitting) {
                  controller.submit();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
