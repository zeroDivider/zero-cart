import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/features/wishlist/wishlist_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the add-to-wishlist bottom sheet (F13 / F1 pattern).
Future<void> showWishlistAddSheet(
  BuildContext context, {
  required String storeId,
}) {
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
        child: WishlistAddSheet(storeId: storeId),
      );
    },
  );
}

/// Wishlist add form: title, optional description, Add / Add another.
class WishlistAddSheet extends ConsumerStatefulWidget {
  const WishlistAddSheet({required this.storeId, super.key});

  final String storeId;

  @override
  ConsumerState<WishlistAddSheet> createState() => _WishlistAddSheetState();
}

class _WishlistAddSheetState extends ConsumerState<WishlistAddSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocus = FocusNode();
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onTitleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _titleFocus.requestFocus();
      }
    });
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
    _titleFocus.dispose();
    super.dispose();
  }

  bool get _titleIsBlank => _titleController.text.trim().isEmpty;

  void _clearFieldsKeepFocus() {
    _titleController.clear();
    _descriptionController.clear();
    _titleFocus.requestFocus();
  }

  Future<void> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (_titleIsBlank) {
      setState(() => _titleError = l10n.titleRequired);
      throw const FormValidationAbort();
    }
    setState(() => _titleError = null);
    await ref
        .read(wishlistRepositoryProvider)
        .add(
          storeId: widget.storeId,
          title: _titleController.text,
          description: _descriptionController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return FormSheetScaffold<void>(
      title: Text(l10n.addToWishlist),
      submitLabel: l10n.add,
      submitKey: const Key('wishlist_add_submit'),
      onSubmit: _onSubmit,
      secondaryAction: FormSheetSecondaryAction.submit(
        label: l10n.addAnother,
        key: const Key('wishlist_add_another'),
        popOnSuccess: false,
        onKeepOpenSuccess: _clearFieldsKeepFocus,
      ),
      body: (context, controller) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('wishlist_add_title'),
              controller: _titleController,
              focusNode: _titleFocus,
              autofocus: true,
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
              key: const Key('wishlist_add_description'),
              controller: _descriptionController,
              enabled: !controller.isSubmitting,
              textInputAction: TextInputAction.done,
              maxLength: maxItemDescriptionLength,
              decoration: InputDecoration(
                labelText: l10n.itemDescriptionLabel,
                hintText: l10n.itemDescriptionHint,
                counterText: '',
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
