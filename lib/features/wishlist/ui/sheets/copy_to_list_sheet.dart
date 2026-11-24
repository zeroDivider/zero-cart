import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/features/lists/active_list_progress.dart';
import 'package:zero_cart/features/lists/copy_wishlist_target.dart';
import 'package:zero_cart/features/lists/list_draft.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/ui/sheets/list_form_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the wishlist copy-to-list picker (F13).
Future<CopyWishlistResult?> showCopyToListSheet(
  BuildContext context, {
  required String storeId,
  required List<String> wishlistIds,
  String? itemTitle,
}) {
  assert(wishlistIds.isNotEmpty, 'wishlistIds must not be empty');
  return showModalBottomSheet<CopyWishlistResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: CopyToListSheet(
          storeId: storeId,
          wishlistIds: wishlistIds,
          itemTitle: itemTitle,
        ),
      );
    },
  );
}

/// Active lists of one store plus New list; nothing written until Confirm.
class CopyToListSheet extends ConsumerStatefulWidget {
  const CopyToListSheet({
    required this.storeId,
    required this.wishlistIds,
    this.itemTitle,
    super.key,
  });

  final String storeId;
  final List<String> wishlistIds;
  final String? itemTitle;

  @override
  ConsumerState<CopyToListSheet> createState() => _CopyToListSheetState();
}

class _CopyToListSheetState extends ConsumerState<CopyToListSheet> {
  String? _listId;
  String? _newListName;
  bool _preselected = false;
  String? _targetError;
  ProviderSubscription<AsyncValue<List<ActiveListProgress>>>? _listsSub;

  bool get _hasList => _listId != null || _newListName != null;

  @override
  void initState() {
    super.initState();
    void tryPreselect() {
      if (_preselected) {
        return;
      }
      final listsAsync = ref.read(activeListsForStoreProvider(widget.storeId));
      if (listsAsync.hasValue) {
        _applyPreselect(listsAsync.requireValue);
      }
    }

    _listsSub = ref.listenManual(
      activeListsForStoreProvider(widget.storeId),
      (_, _) => tryPreselect(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _listsSub?.close();
    super.dispose();
  }

  void _applyPreselect(List<ActiveListProgress> progressLists) {
    if (_preselected || !mounted) {
      return;
    }
    _preselected = true;
    if (progressLists.isEmpty) {
      return;
    }
    setState(() {
      _listId = progressLists.first.list.id;
      _newListName = null;
    });
  }

  Future<void> _pickNewList() async {
    final draft = await showListFormSheet<ListDraft>(
      context,
      onSubmit: (listDraft) async => listDraft,
    );
    if (!mounted || draft == null) {
      return;
    }
    setState(() {
      _newListName = draft.name;
      _listId = null;
      _targetError = null;
    });
  }

  void _selectList(String id) {
    setState(() {
      _listId = id;
      _newListName = null;
      _targetError = null;
    });
  }

  Future<CopyWishlistResult> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (!_hasList) {
      setState(() => _targetError = l10n.copyNeedsList);
      throw const FormValidationAbort();
    }

    final CopyWishlistTarget target;
    final newListName = _newListName;
    if (newListName != null) {
      target = NewList(newListName);
    } else {
      target = ExistingList(_listId!);
    }

    return ref
        .read(listsRepositoryProvider)
        .copyWishlistItems(widget.wishlistIds, target);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final listsAsync = ref.watch(activeListsForStoreProvider(widget.storeId));

    final title = widget.itemTitle != null
        ? l10n.copyToListItemTitle(widget.itemTitle!)
        : l10n.copyToListTitle;

    return FormSheetScaffold<CopyWishlistResult>(
      title: Text(title),
      submitLabel: l10n.addToList,
      submitKey: const Key('copy_to_list_confirm'),
      onSubmit: _onSubmit,
      body: (context, controller) {
        return listsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(l10n.asyncLoadFailed),
          data: (progressLists) {
            final lists = [for (final progress in progressLists) progress.list];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.storeListsSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: tokens.spacing8),
                Wrap(
                  spacing: tokens.spacing8,
                  runSpacing: tokens.spacing8,
                  children: [
                    for (final list in lists)
                      FilterChip(
                        key: Key('copy_list_${list.id}'),
                        label: Text(list.name),
                        selected: _newListName == null && _listId == list.id,
                        showCheckmark: false,
                        onSelected: controller.isSubmitting
                            ? null
                            : (_) => _selectList(list.id),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        visualDensity: VisualDensity.standard,
                        padding: EdgeInsets.symmetric(
                          horizontal: tokens.spacing8,
                          vertical: tokens.spacing8,
                        ),
                      ),
                    ActionChip(
                      key: const Key('copy_new_list'),
                      label: Text(l10n.newListAction),
                      avatar: _newListName != null
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      onPressed: controller.isSubmitting ? null : _pickNewList,
                    ),
                  ],
                ),
                if (_newListName != null) ...[
                  SizedBox(height: tokens.spacing8),
                  Text(
                    _newListName!,
                    key: const Key('copy_new_list_name'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                if (_targetError != null) ...[
                  SizedBox(height: tokens.spacing8),
                  Text(
                    _targetError!,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
