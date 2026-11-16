import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/ui/app_messenger.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/core/widgets/swipe_to_remove_row.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';
import 'package:zero_cart/features/inbox/inbox_selection.dart';
import 'package:zero_cart/features/inbox/ui/sheets/assign_sheet.dart';
import 'package:zero_cart/features/inbox/ui/sheets/inbox_edit_sheet.dart';
import 'package:zero_cart/features/inbox/ui/sheets/quick_add_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Inbox tab: newest-first capture backlog with edit, assign and multi-select.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncItems = ref.watch(inboxItemsProvider);
    final selected = ref.watch(inboxSelectionProvider);
    final selecting = selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selecting ? l10n.inboxSelectedCount(selected.length) : l10n.navInbox,
        ),
        leading: selecting
            ? IconButton(
                key: const Key('inbox_clear_selection'),
                tooltip: l10n.clearSelection,
                onPressed: () =>
                    ref.read(inboxSelectionProvider.notifier).clear(),
                icon: const Icon(Icons.close),
              )
            : null,
        actions: [
          if (selecting)
            TextButton(
              key: const Key('inbox_assign_selected'),
              onPressed: () => _assignIds(
                context: context,
                ref: ref,
                ids: selected.toList(),
              ),
              child: Text(l10n.assignSelected),
            ),
        ],
      ),
      body: AsyncBody(
        value: asyncItems,
        onRetry: () => ref.invalidate(inboxItemsProvider),
        builder: (context, items) {
          if (items.isEmpty) {
            return const _InboxEmptyState();
          }
          return _InboxList(items: items, selecting: selecting);
        },
      ),
    );
  }
}

Future<void> _assignIds({
  required BuildContext context,
  required WidgetRef ref,
  required List<String> ids,
  String? itemTitle,
}) async {
  final l10n = AppLocalizations.of(context);
  final router = GoRouter.of(context);
  final result = await showAssignSheet(
    context,
    inboxIds: ids,
    itemTitle: itemTitle,
  );
  if (result == null) {
    return;
  }
  ref.read(inboxSelectionProvider.notifier).clear();
  AppMessenger.action(
    message: l10n.addedToList(result.listName),
    actionLabel: l10n.open,
    onPressed: () => router.push(AppRoutes.listDetailsLocation(result.listId)),
  );
}

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState();

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
              l10n.inboxEmptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing8),
            Text(
              l10n.inboxEmptyBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing24),
            FilledButton(
              key: const Key('inbox_empty_quick_add'),
              onPressed: () => showQuickAddSheet(context),
              child: Text(l10n.quickAdd),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxList extends ConsumerWidget {
  const _InboxList({required this.items, required this.selecting});

  final List<InboxItem> items;
  final bool selecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final repository = ref.watch(inboxRepositoryProvider);
    final selected = ref.watch(inboxSelectionProvider);

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selected.contains(item.id);
        final row = InkWell(
          key: Key('inbox_row_${item.id}'),
          onTap: () {
            if (selecting) {
              ref.read(inboxSelectionProvider.notifier).toggle(item.id);
            } else {
              showInboxEditSheet(context, item);
            }
          },
          onLongPress: selecting
              ? null
              : () => ref.read(inboxSelectionProvider.notifier).start(item.id),
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
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      key: Key('inbox_select_${item.id}'),
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
                  if (!selecting)
                    TextButton(
                      key: Key('inbox_assign_${item.id}'),
                      onPressed: () => _assignIds(
                        context: context,
                        ref: ref,
                        ids: [item.id],
                        itemTitle: item.title,
                      ),
                      child: Text(l10n.assign),
                    ),
                ],
              ),
            ),
          ),
        );

        if (selecting) {
          return row;
        }

        return SwipeToRemoveRow(
          itemKey: ValueKey<String>('inbox-dismiss-${item.id}'),
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
    required InboxRepository repository,
    required InboxItem item,
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
