import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/core/widgets/swipe_to_remove_row.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/add_item_notifier.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/lists/remove_item_undo.dart';
import 'package:zero_cart/features/lists/ui/add_item_row.dart';
import 'package:zero_cart/features/lists/ui/item_edit_sheet.dart';
import 'package:zero_cart/features/lists/ui/item_row.dart';
import 'package:zero_cart/features/lists/ui/purchased_header.dart';
import 'package:zero_cart/features/lists/ui/sheets/list_form_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Shopping list details: active items, inline add, purchased section (APP-012).
class ListScreen extends ConsumerWidget {
  const ListScreen({required this.listId, super.key});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncList = ref.watch(listByIdProvider(listId));

    return AsyncBody(
      value: asyncList,
      onRetry: () => ref.invalidate(listByIdProvider(listId)),
      builder: (context, list) {
        if (list == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.listNotFound)),
          );
        }
        return _ListScreenBody(list: list);
      },
    );
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
  bool get _readOnly => list.archivedAt != null;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _rename() async {
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

  Future<void> _archive() async {
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
    if (confirmed != true || !mounted) {
      return;
    }
    final ok = await runWrite(
      () => ref.read(listsRepositoryProvider).archive(list.id),
      l10n: l10n,
    );
    if (ok && mounted) {
      context.go(AppRoutes.storeDetailsLocation(list.storeId));
    }
  }

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
    setState(() => _optimisticActiveIds = List<String>.from(orderedActiveIds));
    try {
      await ref
          .read(listsRepositoryProvider)
          .reorderActive(list.id, orderedActiveIds);
    } on Object {
      // Stale or other failure: drop optimistic order; stream reloads (F6).
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

  Widget _wrapRemovable(ListItem item, Widget child) {
    if (_readOnly) {
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

  Widget _activeRow(ListItem item, List<ListItem> active, int index) {
    return KeyedSubtree(
      key: _keyFor(item.id),
      child: _wrapRemovable(
        item,
        ItemRow(
          item: item,
          readOnly: _readOnly,
          reorderIndex: _readOnly ? null : index,
          onPurchasedChanged: _readOnly
              ? null
              : (value) => _setPurchased(item, value),
          onOpenEdit: _readOnly ? null : () => showItemEditSheet(context, item),
          onMoveUp: !_readOnly && index > 0
              ? () => _moveActive(active, index, -1)
              : null,
          onMoveDown: !_readOnly && index < active.length - 1
              ? () => _moveActive(active, index, 1)
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final asyncItems = ref.watch(listItemsProvider(list.id));
    final purchasedExpanded = ref.watch(purchasedExpandedProvider(list.id));
    final addCtrl = ref.watch(addItemNotifierProvider(list.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          if (!_readOnly)
            PopupMenuButton<String>(
              key: const Key('list_menu'),
              onSelected: (value) {
                if (value == 'rename') {
                  _rename();
                } else if (value == 'archive') {
                  _archive();
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
            ),
        ],
      ),
      body: AsyncBody(
        value: asyncItems,
        onRetry: () => ref.invalidate(listItemsProvider(list.id)),
        builder: (context, items) {
          final activeFromDb = items.where((i) => !i.isPurchased).toList();
          final active = _activeForDisplay(activeFromDb);
          final purchased = items.where((i) => i.isPurchased).toList();
          final pendingScrollId = addCtrl.pendingScrollId;
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
              if (_readOnly)
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = active[index];
                    return KeyedSubtree(
                      key: ValueKey(item.id),
                      child: _activeRow(item, active, index),
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
                      child: _activeRow(item, active, index),
                    );
                  },
                ),
              if (!_readOnly)
                SliverToBoxAdapter(child: AddItemRow(listId: list.id)),
              if (items.isEmpty && !_readOnly)
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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
                            readOnly: _readOnly,
                            onPurchasedChanged: _readOnly
                                ? null
                                : (value) => _setPurchased(item, value),
                            onOpenEdit: _readOnly
                                ? null
                                : () => showItemEditSheet(context, item),
                          ),
                        ),
                      );
                    }, childCount: purchased.length),
                  ),
              ],
              SliverToBoxAdapter(child: SizedBox(height: tokens.spacing24)),
            ],
          );
        },
      ),
    );
  }
}
