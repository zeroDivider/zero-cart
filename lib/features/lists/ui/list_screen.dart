import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/add_item_notifier.dart';
import 'package:zero_cart/features/lists/list_form_sheet.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/ui/item_edit_sheet.dart';
import 'package:zero_cart/features/lists/ui/item_row.dart';
import 'package:zero_cart/features/lists/ui/purchased_header.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Shopping list details: active items, inline add, purchased section (APP-012).
class ListScreen extends ConsumerWidget {
  const ListScreen({required this.listId, super.key});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncList = ref.watch(listByIdProvider(listId));

    return asyncList.when(
      data: (list) {
        if (list == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.listNotFound)),
          );
        }
        return _ListScreenBody(list: list);
      },
      loading: () => Scaffold(appBar: AppBar(), body: const SizedBox.shrink()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('$error')),
      ),
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

  ShoppingList get list => widget.list;
  bool get _readOnly => list.archivedAt != null;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _itemKeys.putIfAbsent(id, GlobalKey.new);

  Future<void> _rename() async {
    final draft = await showListFormSheet(context, existing: list);
    if (draft == null || !mounted) {
      return;
    }
    await ref
        .read(listsRepositoryProvider)
        .rename(id: list.id, name: draft.name);
  }

  Future<void> _archive() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(listsRepositoryProvider).archive(list.id);
    } on Object {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.archiveListFailed)));
    }
  }

  Future<void> _setPurchased(ListItem item, bool value) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(listsRepositoryProvider).setPurchased(item.id, value);
    } on Object {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.purchaseWriteFailed)));
    }
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
      body: asyncItems.when(
        data: (items) {
          final active = items.where((i) => !i.isPurchased).toList();
          final purchased = items.where((i) => i.isPurchased).toList();
          final pendingScrollId = addCtrl.pendingScrollId;
          if (pendingScrollId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _scrollToPending(pendingScrollId);
              }
            });
          }

          return ListView(
            key: const Key('list_items_scroll'),
            controller: _scrollController,
            padding: EdgeInsets.only(bottom: tokens.spacing24),
            children: [
              for (final item in active)
                KeyedSubtree(
                  key: _keyFor(item.id),
                  child: ItemRow(
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
              if (!_readOnly) _AddItemRow(listId: list.id),
              if (items.isEmpty && !_readOnly)
                Padding(
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
              if (purchased.isNotEmpty) ...[
                PurchasedHeader(
                  listId: list.id,
                  count: purchased.length,
                  expanded: purchasedExpanded,
                ),
                if (purchasedExpanded)
                  for (final item in purchased)
                    KeyedSubtree(
                      key: _keyFor(item.id),
                      child: ItemRow(
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
              ],
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
}

class _AddItemRow extends ConsumerStatefulWidget {
  const _AddItemRow({required this.listId});

  final String listId;

  @override
  ConsumerState<_AddItemRow> createState() => _AddItemRowState();
}

class _AddItemRowState extends ConsumerState<_AddItemRow> {
  final _addController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addFocus = FocusNode();
  bool _showDetails = false;
  String? _addError;

  @override
  void dispose() {
    _addController.dispose();
    _descriptionController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _doAddItem() async {
    final l10n = AppLocalizations.of(context);
    final title = _addController.text;
    if (title.trim().isEmpty) {
      setState(() => _addError = l10n.titleRequired);
      return;
    }
    setState(() => _addError = null);
    await ref
        .read(addItemNotifierProvider(widget.listId).notifier)
        .addItem(
          title: title,
          description: _showDetails ? _descriptionController.text : null,
          errorMessage: l10n.writeFailed,
        );
    if (!mounted) {
      return;
    }
    final ctrl = ref.read(addItemNotifierProvider(widget.listId));
    if (ctrl.error == null && !ctrl.submitting) {
      _addController.clear();
      _descriptionController.clear();
      _addFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final addCtrl = ref.watch(addItemNotifierProvider(widget.listId));

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing16,
        vertical: tokens.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('list_add_title'),
                  controller: _addController,
                  focusNode: _addFocus,
                  textInputAction: TextInputAction.done,
                  maxLength: maxItemTitleLength,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        required maxLength,
                      }) {
                        if (currentLength < 40 || maxLength == null) {
                          return const SizedBox.shrink();
                        }
                        return Text('$currentLength / $maxLength');
                      },
                  decoration: InputDecoration(
                    hintText: l10n.addItemHint,
                    errorText: _addError ?? addCtrl.error,
                    border: InputBorder.none,
                  ),
                  onChanged: (_) {
                    ref
                        .read(addItemNotifierProvider(widget.listId).notifier)
                        .clearError();
                    if (_addError != null) {
                      setState(() => _addError = null);
                    }
                  },
                  onSubmitted: (_) {
                    if (!addCtrl.submitting) {
                      _doAddItem();
                    }
                  },
                ),
              ),
              TextButton(
                key: const Key('list_add_details_toggle'),
                onPressed: () => setState(() => _showDetails = !_showDetails),
                child: Text(l10n.addItemDetailsToggle),
              ),
            ],
          ),
          if (_showDetails)
            TextField(
              key: const Key('list_add_description'),
              controller: _descriptionController,
              maxLength: maxItemDescriptionLength,
              decoration: InputDecoration(
                hintText: l10n.itemDescriptionHint,
                counterText: '',
                border: InputBorder.none,
              ),
            ),
        ],
      ),
    );
  }
}
