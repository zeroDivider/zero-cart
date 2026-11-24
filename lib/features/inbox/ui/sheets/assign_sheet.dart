import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/assign_inbox_target.dart';
import 'package:zero_cart/features/lists/list_draft.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/ui/sheets/list_form_sheet.dart';
import 'package:zero_cart/features/stores/store_draft.dart';
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

/// Store/list chips plus Confirm; drafts write nothing until Confirm (D-16).
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
  StoreDraft? _newStoreDraft;
  String? _newListName;
  bool _preselected = false;
  String? _targetError;
  ProviderSubscription<AsyncValue<List<Store>>>? _storesSub;
  ProviderSubscription<AsyncValue<List<ShoppingList>>>? _listsSub;

  bool get _hasStore => _storeId != null || _newStoreDraft != null;

  bool get _hasList => _listId != null || _newListName != null;

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
        _newStoreDraft = null;
        _newListName = null;
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
        _newStoreDraft = null;
        _newListName = null;
      });
    }
  }

  Future<void> _pickNewStore() async {
    final storesRepo = ref.read(storesRepositoryProvider);
    final colorKey = await storesRepo.nextFreeColorKey();
    if (!mounted) {
      return;
    }
    final draft = await showStoreFormSheet(
      context,
      draftMode: true,
      initialColorKey: colorKey,
    );
    if (!mounted || draft == null) {
      return;
    }
    setState(() {
      _newStoreDraft = draft;
      _storeId = null;
      _listId = null;
      _newListName = null;
      _targetError = null;
    });
    // A new store has no existing lists (D-16); prompt for the list name next
    // so the draft is not left looking like a failed create (F4 / ST-1).
    await _pickNewList();
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

  void _selectStore(String id) {
    setState(() {
      _storeId = id;
      _newStoreDraft = null;
      _listId = null;
      _newListName = null;
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

  Future<AssignInboxResult> _onSubmit() async {
    final l10n = AppLocalizations.of(context);
    if (!_hasStore || !_hasList) {
      setState(() => _targetError = l10n.assignNeedsTarget);
      throw const FormValidationAbort();
    }

    final AssignStoreTarget storeTarget;
    final newStore = _newStoreDraft;
    if (newStore != null) {
      storeTarget = NewStore(newStore);
    } else {
      storeTarget = ExistingStore(_storeId!);
    }

    final AssignListTarget listTarget;
    final newListName = _newListName;
    if (newListName != null) {
      listTarget = NewList(newListName);
    } else {
      listTarget = ExistingList(_listId!);
    }

    return ref
        .read(listsRepositoryProvider)
        .assignInbox(
          widget.inboxIds,
          AssignInboxTarget(store: storeTarget, list: listTarget),
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
                  selectedId: _newStoreDraft == null ? _storeId : null,
                  newStoreDraft: _newStoreDraft,
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
                  selectedId: _newListName == null ? _listId : null,
                  showExistingLists: _newStoreDraft == null,
                  showNewList: _hasStore,
                  newListName: _newListName,
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
    required this.newStoreDraft,
    required this.enabled,
    required this.onStoreSelected,
    required this.onNewStore,
  });

  final List<Store> stores;
  final String? selectedId;
  final StoreDraft? newStoreDraft;
  final bool enabled;
  final ValueChanged<String> onStoreSelected;
  final VoidCallback onNewStore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final draft = newStoreDraft;
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
        if (draft != null)
          _ChoiceChip(
            key: const Key('assign_new_store_name'),
            label: draft.name,
            selected: true,
            color: tokens.storeColor(draft.colorKey),
            // Absorb taps; draft is replaced via "+ New store".
            onSelected: enabled ? () {} : null,
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
    required this.showExistingLists,
    required this.showNewList,
    required this.newListName,
    required this.enabled,
    required this.onListSelected,
    required this.onNewList,
  });

  final List<ShoppingList> lists;
  final String? selectedId;
  final bool showExistingLists;
  final bool showNewList;
  final String? newListName;
  final bool enabled;
  final ValueChanged<String> onListSelected;
  final VoidCallback onNewList;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final draftName = newListName;
    return Wrap(
      spacing: tokens.spacing8,
      runSpacing: tokens.spacing8,
      children: [
        if (showExistingLists)
          for (final list in lists)
            _ChoiceChip(
              key: Key('assign_list_${list.id}'),
              label: list.name,
              selected: selectedId == list.id,
              onSelected: enabled ? () => onListSelected(list.id) : null,
            ),
        if (draftName != null)
          _ChoiceChip(
            key: const Key('assign_new_list_name'),
            label: draftName,
            selected: true,
            // Absorb taps; draft is replaced via "+ New list".
            onSelected: enabled ? () {} : null,
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
