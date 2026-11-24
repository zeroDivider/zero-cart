import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/assign_inbox_target.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/ui/sheets/list_form_sheet.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Opens the Inbox assignment sheet for [inboxIds] (F3, F4).
Future<AssignInboxResult?> showAssignSheet(
  BuildContext context, {
  required List<String> inboxIds,
  String? itemTitle,
}) {
  assert(inboxIds.isNotEmpty, 'inboxIds must not be empty');
  return showModalBottomSheet<AssignInboxResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: AssignSheet(inboxIds: inboxIds, itemTitle: itemTitle),
      );
    },
  );
}

/// Store/list chips plus Confirm.
///
/// New store / New list persist in their form sheets; Confirm only assigns
/// Inbox rows to the selected existing store and list (D-16 / D-17).
class AssignSheet extends ConsumerStatefulWidget {
  const AssignSheet({required this.inboxIds, this.itemTitle, super.key});

  final List<String> inboxIds;
  final String? itemTitle;

  @override
  ConsumerState<AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends ConsumerState<AssignSheet> {
  String? _storeId;
  String? _listId;
  bool _preselected = false;
  String? _targetError;
  ProviderSubscription<AsyncValue<List<Store>>>? _storesSub;
  ProviderSubscription<AsyncValue<List<ShoppingList>>>? _listsSub;

  bool get _hasStore => _storeId != null;

  bool get _hasList => _listId != null;

  @override
  void initState() {
    super.initState();
    void tryPreselect() {
      if (_preselected) {
        return;
      }
      final storesAsync = ref.read(activeStoresProvider);
      final listsAsync = ref.read(activeListsByRecencyProvider);
      if (storesAsync.hasValue && listsAsync.hasValue) {
        _applyPreselect(storesAsync.requireValue, listsAsync.requireValue);
      }
    }

    _storesSub = ref.listenManual(
      activeStoresProvider,
      (_, _) => tryPreselect(),
      fireImmediately: true,
    );
    _listsSub = ref.listenManual(
      activeListsByRecencyProvider,
      (_, _) => tryPreselect(),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _storesSub?.close();
    _listsSub?.close();
    super.dispose();
  }

  void _applyPreselect(List<Store> stores, List<ShoppingList> lists) {
    if (_preselected || !mounted) {
      return;
    }
    _preselected = true;
    if (lists.isNotEmpty) {
      final list = lists.first;
      setState(() {
        _storeId = list.storeId;
        _listId = list.id;
      });
      return;
    }
    if (stores.isNotEmpty) {
      Store? newest;
      for (final store in stores) {
        if (newest == null || store.updatedAt.isAfter(newest.updatedAt)) {
          newest = store;
        }
      }
      setState(() {
        _storeId = newest!.id;
        _listId = null;
      });
    }
  }

  Future<void> _pickNewStore() async {
    final storesRepo = ref.read(storesRepositoryProvider);
    final colorKey = await storesRepo.nextFreeColorKey();
    if (!mounted) {
      return;
    }
    final store = await showStoreFormSheet(
      context,
      initialColorKey: colorKey,
      repository: storesRepo,
    );
    if (!mounted || store == null) {
      return;
    }
    setState(() {
      _storeId = store.id;
      _listId = null;
      _targetError = null;
    });
    // New store has no lists yet; offer Create so the user can pick a target.
    await _pickNewList();
  }

  Future<void> _pickNewList() async {
    final storeId = _storeId;
    if (storeId == null) {
      return;
    }
    final list = await showListFormSheet(
      context,
      onSubmit: (draft) {
        return ref
            .read(listsRepositoryProvider)
            .create(storeId: storeId, name: draft.name);
      },
    );
    if (!mounted || list == null) {
      return;
    }
    setState(() {
      _listId = list.id;
      _targetError = null;
    });
  }

  void _selectStore(String id) {
    setState(() {
      _storeId = id;
      _listId = null;
      _targetError = null;
    });
  }

  void _selectList(String id) {
    setState(() {
      _listId = id;
      _targetError = null;
    });
  }

  Future<AssignInboxResult> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (!_hasStore || !_hasList) {
      setState(() => _targetError = l10n.assignNeedsTarget);
      throw const FormValidationAbort();
    }

    return ref
        .read(listsRepositoryProvider)
        .assignInbox(
          widget.inboxIds,
          AssignInboxTarget(
            store: ExistingStore(_storeId!),
            list: ExistingList(_listId!),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final storesAsync = ref.watch(activeStoresProvider);
    final storeListsAsync = _storeId == null
        ? null
        : ref.watch(activeListsForStoreProvider(_storeId!));

    final title = widget.itemTitle != null
        ? l10n.assignItemTitle(widget.itemTitle!)
        : l10n.assignTitle;

    return FormSheetScaffold<AssignInboxResult>(
      title: Text(title),
      submitLabel: l10n.addToList,
      submitKey: const Key('assign_confirm'),
      onSubmit: _onSubmit,
      body: (context, controller) {
        return storesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(l10n.asyncLoadFailed),
          data: (stores) {
            final progressLists = storeListsAsync?.asData?.value;
            final lists = <ShoppingList>[
              if (progressLists != null)
                for (final progress in progressLists) progress.list,
            ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.assignStoreLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: tokens.spacing8),
                _StoreChipsSection(
                  stores: stores,
                  selectedId: _storeId,
                  enabled: !controller.isSubmitting,
                  onStoreSelected: _selectStore,
                  onNewStore: _pickNewStore,
                ),
                SizedBox(height: tokens.spacing16),
                Text(
                  l10n.assignListLabel,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                SizedBox(height: tokens.spacing8),
                _ListChipsSection(
                  lists: lists,
                  selectedId: _listId,
                  showNewList: _hasStore,
                  enabled: !controller.isSubmitting,
                  onListSelected: _selectList,
                  onNewList: _pickNewList,
                ),
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

class _StoreChipsSection extends StatelessWidget {
  const _StoreChipsSection({
    required this.stores,
    required this.selectedId,
    required this.enabled,
    required this.onStoreSelected,
    required this.onNewStore,
  });

  final List<Store> stores;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String> onStoreSelected;
  final VoidCallback onNewStore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Wrap(
      spacing: tokens.spacing8,
      runSpacing: tokens.spacing8,
      children: [
        for (final store in stores)
          _ChoiceChip(
            key: Key('assign_store_${store.id}'),
            label: store.name,
            selected: selectedId == store.id,
            color: tokens.storeColor(store.colorKey),
            onSelected: enabled ? () => onStoreSelected(store.id) : null,
          ),
        ActionChip(
          key: const Key('assign_new_store'),
          label: Text(l10n.newStoreAction),
          onPressed: enabled ? onNewStore : null,
        ),
      ],
    );
  }
}

class _ListChipsSection extends StatelessWidget {
  const _ListChipsSection({
    required this.lists,
    required this.selectedId,
    required this.showNewList,
    required this.enabled,
    required this.onListSelected,
    required this.onNewList,
  });

  final List<ShoppingList> lists;
  final String? selectedId;
  final bool showNewList;
  final bool enabled;
  final ValueChanged<String> onListSelected;
  final VoidCallback onNewList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Wrap(
      spacing: tokens.spacing8,
      runSpacing: tokens.spacing8,
      children: [
        for (final list in lists)
          _ChoiceChip(
            key: Key('assign_list_${list.id}'),
            label: list.name,
            selected: selectedId == list.id,
            onSelected: enabled ? () => onListSelected(list.id) : null,
          ),
        if (showNewList)
          ActionChip(
            key: const Key('assign_new_list'),
            label: Text(l10n.newListAction),
            onPressed: enabled ? onNewList : null,
          ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final dot = color;
    return FilterChip(
      avatar: dot == null
          ? null
          : ExcludeSemantics(
              child: SizedBox(
                width: tokens.spacing16,
                height: tokens.spacing16,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
              ),
            ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: onSelected == null ? null : (_) => onSelected!(),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing8,
        vertical: tokens.spacing8,
      ),
    );
  }
}
