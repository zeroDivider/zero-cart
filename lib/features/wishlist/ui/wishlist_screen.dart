import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/ui/app_messenger.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/core/widgets/swipe_to_remove_row.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/copy_wishlist_target.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/wishlist/ui/sheets/copy_to_list_sheet.dart';
import 'package:zero_cart/features/wishlist/ui/sheets/wishlist_add_sheet.dart';
import 'package:zero_cart/features/wishlist/ui/sheets/wishlist_edit_sheet.dart';
import 'package:zero_cart/features/wishlist/wishlist_providers.dart';
import 'package:zero_cart/features/wishlist/wishlist_repository.dart';
import 'package:zero_cart/features/wishlist/wishlist_selection.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Store wishlist at `/stores/:id/wishlist` (WL-1, WL-2, F13).
class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncItems = ref.watch(wishlistItemsProvider(storeId));
    final asyncStore = ref.watch(storeByIdProvider(storeId));
    final selected = ref.watch(wishlistSelectionProvider);
    final selecting = selected.isNotEmpty;
    final store = asyncStore.asData?.value;
    final readOnly = store?.archivedAt != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selecting
              ? l10n.wishlistSelectedCount(selected.length)
              : l10n.wishlistPlaceholder,
        ),
        leading: selecting
            ? IconButton(
                key: const Key('wishlist_clear_selection'),
                tooltip: l10n.clearSelection,
                onPressed: () =>
                    ref.read(wishlistSelectionProvider.notifier).clear(),
                icon: const Icon(Icons.close),
              )
            : null,
        actions: [
          if (selecting && !readOnly)
            TextButton(
              key: const Key('wishlist_add_selected'),
              onPressed: () => _copyIds(
                context,
                ref,
                storeId: storeId,
                ids: selected.toList(),
              ),
              child: Text(l10n.addSelectedToList),
            ),
        ],
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              key: const Key('wishlist_fab_add'),
              onPressed: () => showWishlistAddSheet(context, storeId: storeId),
              icon: const Icon(Icons.add),
              label: Text(l10n.add),
            ),
      body: AsyncBody(
        value: asyncItems,
        onRetry: () => ref.invalidate(wishlistItemsProvider(storeId)),
        builder: (context, items) {
          if (items.isEmpty) {
            return _WishlistEmptyState(storeId: storeId, readOnly: readOnly);
          }
          return _WishlistList(
            storeId: storeId,
            items: items,
            readOnly: readOnly,
          );
        },
      ),
    );
  }
}

Future<void> _copyIds(
  BuildContext context,
  WidgetRef ref, {
  required String storeId,
  required List<String> ids,
  String? itemTitle,
}) async {
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final CopyWishlistResult? result = await showCopyToListSheet(
    context,
    storeId: storeId,
    wishlistIds: ids,
    itemTitle: itemTitle,
  );
  if (result == null) {
    return;
  }
  ref.read(wishlistSelectionProvider.notifier).clear();
  AppMessenger.action(
    message: l10n.addedToList(result.listName),
    actionLabel: l10n.open,
    onPressed: () => router.push(AppRoutes.listDetailsLocation(result.listId)),
  );
}

class _WishlistEmptyState extends StatelessWidget {
  const _WishlistEmptyState({required this.storeId, required this.readOnly});

  final String storeId;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.wishlistEmptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing8),
            Text(
              l10n.wishlistEmptyBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (!readOnly) ...[
              SizedBox(height: tokens.spacing24),
              FilledButton(
                key: const Key('wishlist_empty_add'),
                onPressed: () =>
                    showWishlistAddSheet(context, storeId: storeId),
                child: Text(l10n.add),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WishlistList extends ConsumerWidget {
  const _WishlistList({
    required this.storeId,
    required this.items,
    required this.readOnly,
  });

  final String storeId;
  final List<WishlistItem> items;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final repository = ref.watch(wishlistRepositoryProvider);
    final selected = ref.watch(wishlistSelectionProvider);
    final selecting = selected.isNotEmpty;

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selected.contains(item.id);
        final row = _WishlistRow(
          item: item,
          readOnly: readOnly,
          selecting: selecting,
          isSelected: isSelected,
          onTap: () {
            if (readOnly) {
              return;
            }
            if (selecting) {
              ref.read(wishlistSelectionProvider.notifier).toggle(item.id);
            } else {
              showWishlistEditSheet(context, item);
            }
          },
          onLongPress: readOnly || selecting
              ? null
              : () =>
                    ref.read(wishlistSelectionProvider.notifier).start(item.id),
          onAddToList: readOnly || selecting
              ? null
              : () => _copyIds(
                  context,
                  ref,
                  storeId: storeId,
                  ids: [item.id],
                  itemTitle: item.title,
                ),
          onSelect: readOnly
              ? null
              : () =>
                    ref.read(wishlistSelectionProvider.notifier).start(item.id),
        );

        if (readOnly) {
          return row;
        }

        return SwipeToRemoveRow(
          itemKey: ValueKey<String>('wishlist-dismiss-${item.id}'),
          semanticRemoveLabel: l10n.remove,
          onRemove: () =>
              _removeItem(l10n: l10n, repository: repository, item: item),
          child: row,
        );
      },
    );
  }

  Future<void> _removeItem({
    required AppLocalizations l10n,
    required WishlistRepository repository,
    required WishlistItem item,
  }) async {
    await runWrite(() async {
      final snapshot = await repository.remove(item.id);
      AppMessenger.undo(
        message: l10n.removedItem(snapshot.title),
        undoLabel: l10n.undo,
        l10n: l10n,
        onUndo: () => repository.restore(snapshot),
      );
    }, l10n: l10n);
  }
}

class _WishlistRow extends StatelessWidget {
  const _WishlistRow({
    required this.item,
    required this.readOnly,
    required this.selecting,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onAddToList,
    required this.onSelect,
  });

  final WishlistItem item;
  final bool readOnly;
  final bool selecting;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAddToList;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Semantics(
      selected: selecting ? isSelected : null,
      customSemanticsActions: selecting || readOnly
          ? null
          : <CustomSemanticsAction, VoidCallback>{
              CustomSemanticsAction(label: l10n.selectItem): onSelect!,
              CustomSemanticsAction(label: l10n.addToList): onAddToList!,
            },
      child: InkWell(
        key: Key('wishlist_row_${item.id}'),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: tokens.spacing48 + 8),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing16,
              vertical: tokens.spacing12,
            ),
            child: Row(
              children: [
                if (selecting) ...[
                  Icon(
                    isSelected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: tokens.spacing12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (item.description != null &&
                          item.description!.isNotEmpty) ...[
                        SizedBox(height: tokens.spacing4),
                        Text(
                          item.description!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onAddToList != null)
                  TextButton(
                    key: Key('wishlist_add_to_list_${item.id}'),
                    onPressed: onAddToList,
                    child: Text(l10n.addToList),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
