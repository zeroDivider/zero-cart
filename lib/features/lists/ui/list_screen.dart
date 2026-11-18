import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/share_service.dart';
import 'package:zero_cart/core/share_text.dart';
import 'package:zero_cart/core/ui/app_messenger.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/core/widgets/swipe_to_remove_row.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/add_item_notifier.dart';
import 'package:zero_cart/features/lists/finish_list_undo.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/remove_item_undo.dart';
import 'package:zero_cart/features/lists/ui/add_item_row.dart';
import 'package:zero_cart/features/lists/ui/sheets/finish_list_sheet.dart';
import 'package:zero_cart/features/lists/ui/sheets/item_edit_sheet.dart';
import 'package:zero_cart/features/lists/ui/item_row.dart';
import 'package:zero_cart/features/lists/ui/purchased_header.dart';
import 'package:zero_cart/features/lists/ui/sheets/list_form_sheet.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Shopping list details: active items, inline add, purchased section (APP-012).
class ListScreen extends ConsumerWidget {
  const ListScreen({required this.listId, super.key});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncList = ref.watch(listByIdProvider(listId));
    final list = asyncList.asData?.value;
    final store = list == null
        ? null
        : ref.watch(storeByIdProvider(list.storeId)).asData?.value;
    final listArchived = list?.archivedAt != null;
    final storeArchived = store?.archivedAt != null;
    // LI-5: Restore only when the store is known and active.
    final canRestoreList = listArchived && store != null && !storeArchived;

    return Scaffold(
      appBar: AppBar(
        title: Text(list?.name ?? l10n.listDetailsPlaceholder),
        actions: [
          if (list != null && !listArchived && !storeArchived) ...[
            _ShareAction(list: list),
            _FinishAction(list: list),
            _ListMenu(list: list),
          ],
          if (listArchived) ...[
            if (storeArchived)
              Padding(
                padding: EdgeInsets.only(
                  right: Theme.of(context).extension<AppTokens>()!.spacing8,
                ),
                child: Center(
                  child: Text(
                    key: const Key('list_details_restore_hint'),
                    l10n.restoreStoreFirstHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            TextButton(
              key: const Key('list_details_restore'),
              onPressed: canRestoreList
                  ? () => _restoreList(context, ref, list!)
                  : null,
              child: Text(l10n.restore),
            ),
          ],
        ],
      ),
      body: AsyncBody(
        value: asyncList,
        onRetry: () => ref.invalidate(listByIdProvider(listId)),
        builder: (context, data) {
          if (data == null) {
            return Center(child: Text(l10n.listNotFound));
          }
          return _ListScreenBody(list: data);
        },
      ),
    );
  }

  Future<void> _restoreList(
    BuildContext context,
    WidgetRef ref,
    ShoppingList list,
  ) async {
    final l10n = AppLocalizations.of(context);
    await runWrite(
      () => ref.read(listsRepositoryProvider).restore(list.id),
      l10n: l10n,
    );
  }
}

/// App-bar Share: unpurchased items as plain text via [ShareService] (SH-1).
class _ShareAction extends ConsumerWidget {
  const _ShareAction({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const Key('list_share'),
      tooltip: l10n.shareList,
      onPressed: () => _share(context, ref),
      icon: const Icon(Icons.ios_share),
    );
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final items = ref.read(listItemsProvider(list.id)).asData?.value;
    if (items == null) {
      return;
    }

    // D-20: name-only formatter output must not open the share sheet.
    if (!items.any((item) => !item.isPurchased)) {
      AppMessenger.info(l10n.nothingLeftToShare);
      return;
    }

    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final origin = box.localToGlobal(Offset.zero) & box.size;

    final text = formatShareText(list.name, [
      for (final item in items)
        ShareableItem(
          title: item.title,
          description: item.description,
          isPurchased: item.isPurchased,
        ),
    ]);

    await runWrite(
      () => ref
          .read(shareServiceProvider)
          .shareText(text, sharePositionOrigin: origin),
      l10n: l10n,
    );
  }
}

/// App-bar Finish: immediate archive + Undo when nothing left; else the sheet.
class _FinishAction extends ConsumerWidget {
  const _FinishAction({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return TextButton(
      key: const Key('list_finish'),
      onPressed: () => _finish(context, ref),
      child: Text(l10n.finishAction),
    );
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final items = ref.read(listItemsProvider(list.id)).asData?.value;
    if (items == null) {
      return;
    }
    final leftCount = items.where((item) => !item.isPurchased).length;
    final ListsRepository repository = ref.read(listsRepositoryProvider);

    if (leftCount == 0) {
      final result = await finishListWithUndo(
        repository: repository,
        listId: list.id,
        l10n: l10n,
      );
      if (result != null && context.mounted) {
        AppRouter.goToStoreDetails(context, list.storeId);
      }
      return;
    }

    final result = await showFinishListSheet(
      context,
      list: list,
      leftCount: leftCount,
    );
    if (result != null && context.mounted) {
      AppRouter.goToStoreDetails(context, list.storeId);
    }
  }
}

class _ListMenu extends ConsumerWidget {
  const _ListMenu({required this.list});

  final ShoppingList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      key: const Key('list_menu'),
      onSelected: (value) {
        if (value == 'rename') {
          _rename(context, ref);
        } else if (value == 'archive') {
          _archive(context, ref);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          key: const Key('list_menu_rename'),
          value: 'rename',
          child: Text(l10n.listMenuRename),
        ),
        PopupMenuItem(
          key: const Key('list_menu_archive'),
          value: 'archive',
          child: Text(l10n.listMenuArchive),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    await showListFormSheet(
      context,
      existing: list,
      onSubmit: (draft) {
        return ref
            .read(listsRepositoryProvider)
            .rename(id: list.id, name: draft.name);
      },
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('archive_list_dialog'),
          title: Text(l10n.archiveListTitle),
          content: Text(l10n.archiveListBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              key: const Key('archive_list_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.archiveAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final ok = await runWrite(
      () => ref.read(listsRepositoryProvider).archive(list.id),
      l10n: l10n,
    );
    if (ok && context.mounted) {
      AppRouter.goToStoreDetails(context, list.storeId);
    }
  }
}

class _ListScreenBody extends ConsumerStatefulWidget {
  const _ListScreenBody({required this.list});

  final ShoppingList list;

  @override
  ConsumerState<_ListScreenBody> createState() => _ListScreenBodyState();
}

class _ListScreenBodyState extends ConsumerState<_ListScreenBody> {
  final _scrollController = ScrollController();
  final _itemKeys = <String, GlobalKey>{};

  /// Local active order while a reorder write is in flight (architecture 2.4).
  List<String>? _optimisticActiveIds;

  ShoppingList get list => widget.list;

  /// Archived list, or any list whose store is archived (prototype / D-14).
  bool _isReadOnly(Store? store) {
    if (list.archivedAt != null) {
      return true;
    }
    return store?.archivedAt != null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _setPurchased(ListItem item, bool value) async {
    final l10n = AppLocalizations.of(context);
    await runWrite(
      () => ref.read(listsRepositoryProvider).setPurchased(item.id, value),
      l10n: l10n,
    );
  }

  List<ListItem> _activeForDisplay(List<ListItem> fromDb) {
    final optimistic = _optimisticActiveIds;
    if (optimistic == null) {
      return fromDb;
    }
    final byId = {for (final item in fromDb) item.id: item};
    if (optimistic.length != fromDb.length ||
        !optimistic.every(byId.containsKey)) {
      return fromDb;
    }
    return [for (final id in optimistic) byId[id]!];
  }

  Future<void> _applyActiveOrder(List<String> orderedActiveIds) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _optimisticActiveIds = List<String>.from(orderedActiveIds));
    try {
      await ref
          .read(listsRepositoryProvider)
          .reorderActive(list.id, orderedActiveIds);
    } on Object catch (error) {
      // Drop optimistic order; stream is source of truth (F6 / ADR-0007).
      AppMessenger.error(messageFor(l10n, error));
    } finally {
      if (mounted) {
        setState(() => _optimisticActiveIds = null);
      }
    }
  }

  void _onReorderItem(List<ListItem> active, int oldIndex, int newIndex) {
    // Flutter 3.47+ [onReorderItem] already adjusts newIndex for removal.
    if (oldIndex == newIndex) {
      return;
    }
    final ids = active.map((item) => item.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    _applyActiveOrder(ids);
  }

  void _moveActive(List<ListItem> active, int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= active.length) {
      return;
    }
    final ids = active.map((item) => item.id).toList();
    final moved = ids.removeAt(index);
    ids.insert(newIndex, moved);
    _applyActiveOrder(ids);
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(animation.value);
        final elevation = lerpDouble(0, 6, t)!;
        final scale = lerpDouble(1, 1.02, t)!;
        return Material(
          elevation: elevation,
          color: Theme.of(context).colorScheme.surface,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: child,
    );
  }

  void _scrollToPending(String id) {
    final ctx = _keyFor(id).currentContext;
    if (ctx == null) {
      return;
    }
    ref.read(addItemNotifierProvider(list.id).notifier).clearPendingScroll();
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 200),
      alignment: 0.8,
    );
  }

  Future<void> _removeItem(ListItem item) async {
    final l10n = AppLocalizations.of(context);
    final ListsRepository repository = ref.read(listsRepositoryProvider);
    await removeListItemWithUndo(
      repository: repository,
      itemId: item.id,
      l10n: l10n,
    );
  }

  Widget _wrapRemovable(ListItem item, Widget child, {required bool readOnly}) {
    if (readOnly) {
      return child;
    }
    final l10n = AppLocalizations.of(context);
    return SwipeToRemoveRow(
      itemKey: ValueKey<String>('list-dismiss-${item.id}'),
      semanticRemoveLabel: l10n.remove,
      onRemove: () => _removeItem(item),
      child: child,
    );
  }

  Widget _activeRow(
    ListItem item,
    List<ListItem> active,
    int index, {
    required bool readOnly,
  }) {
    return KeyedSubtree(
      key: _keyFor(item.id),
      child: _wrapRemovable(
        item,
        ItemRow(
          item: item,
          readOnly: readOnly,
          reorderIndex: readOnly ? null : index,
          onPurchasedChanged: readOnly
              ? null
              : (value) => _setPurchased(item, value),
          onOpenEdit: readOnly ? null : () => showItemEditSheet(context, item),
          onMoveUp: !readOnly && index > 0
              ? () => _moveActive(active, index, -1)
              : null,
          onMoveDown: !readOnly && index < active.length - 1
              ? () => _moveActive(active, index, 1)
              : null,
        ),
        readOnly: readOnly,
      ),
    );
  }

  Widget _statusTag(BuildContext context, AppLocalizations l10n) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final finished =
        list.archiveReason == ListsRepository.archiveReasonFinished;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing16,
        tokens.spacing8,
        tokens.spacing16,
        tokens.spacing4,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          key: const Key('list_status_tag'),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing8,
            vertical: tokens.spacing4,
          ),
          decoration: BoxDecoration(
            color: tokens.success,
            borderRadius: BorderRadius.circular(tokens.radiusPill),
          ),
          child: Text(
            finished ? l10n.listStatusFinished : l10n.listStatusArchived,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: tokens.onSuccess),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final asyncItems = ref.watch(listItemsProvider(list.id));
    final store = ref.watch(storeByIdProvider(list.storeId)).asData?.value;
    final readOnly = _isReadOnly(store);
    final purchasedExpanded = ref.watch(purchasedExpandedProvider(list.id));
    final pendingScrollId = ref.watch(addItemNotifierProvider(list.id));

    return AsyncBody(
      value: asyncItems,
      onRetry: () => ref.invalidate(listItemsProvider(list.id)),
      builder: (context, items) {
        final activeFromDb = items.where((i) => !i.isPurchased).toList();
        final active = _activeForDisplay(activeFromDb);
        final purchased = items.where((i) => i.isPurchased).toList();
        if (pendingScrollId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollToPending(pendingScrollId);
            }
          });
        }

        return CustomScrollView(
          key: const Key('list_items_scroll'),
          controller: _scrollController,
          slivers: [
            if (list.archivedAt != null)
              SliverToBoxAdapter(child: _statusTag(context, l10n)),
            if (readOnly)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = active[index];
                  return KeyedSubtree(
                    key: ValueKey(item.id),
                    child: _activeRow(item, active, index, readOnly: readOnly),
                  );
                }, childCount: active.length),
              )
            else
              SliverReorderableList(
                itemCount: active.length,
                onReorderItem: (oldIndex, newIndex) {
                  _onReorderItem(active, oldIndex, newIndex);
                },
                onReorderStart: (_) {
                  HapticFeedback.lightImpact();
                },
                proxyDecorator: _proxyDecorator,
                itemBuilder: (context, index) {
                  final item = active[index];
                  return KeyedSubtree(
                    key: ValueKey(item.id),
                    child: _activeRow(item, active, index, readOnly: readOnly),
                  );
                },
              ),
            if (!readOnly)
              SliverToBoxAdapter(child: AddItemRow(listId: list.id)),
            if (items.isEmpty && !readOnly)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(tokens.spacing24),
                  child: Column(
                    children: [
                      Text(
                        l10n.listEmptyTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: tokens.spacing8),
                      Text(
                        l10n.listEmptyBody,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            if (purchased.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: PurchasedHeader(
                  listId: list.id,
                  count: purchased.length,
                  expanded: purchasedExpanded,
                ),
              ),
              if (purchasedExpanded)
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = purchased[index];
                    return KeyedSubtree(
                      key: _keyFor(item.id),
                      child: _wrapRemovable(
                        item,
                        ItemRow(
                          item: item,
                          readOnly: readOnly,
                          onPurchasedChanged: readOnly
                              ? null
                              : (value) => _setPurchased(item, value),
                          onOpenEdit: readOnly
                              ? null
                              : () => showItemEditSheet(context, item),
                        ),
                        readOnly: readOnly,
                      ),
                    );
                  }, childCount: purchased.length),
                ),
            ],
            SliverToBoxAdapter(child: SizedBox(height: tokens.spacing24)),
          ],
        );
      },
    );
  }
}
