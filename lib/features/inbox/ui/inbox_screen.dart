import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/remove_undo_snackbar.dart';
import 'package:zero_cart/core/widgets/swipe_to_remove_row.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';
import 'package:zero_cart/features/inbox/ui/inbox_edit_sheet.dart';
import 'package:zero_cart/features/inbox/ui/quick_add_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Inbox tab: newest-first capture backlog with edit and swipe-remove.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncItems = ref.watch(inboxItemsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navInbox)),
      body: asyncItems.when(
        data: (items) {
          if (items.isEmpty) {
            return const _InboxEmptyState();
          }
          return _InboxList(items: items);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
      ),
    );
  }
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
  const _InboxList({required this.items});

  final List<InboxItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final repository = ref.read(inboxRepositoryProvider);

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        final item = items[index];
        return SwipeToRemoveRow(
          itemKey: ValueKey<String>('inbox-dismiss-${item.id}'),
          semanticRemoveLabel: l10n.remove,
          onRemove: () =>
              _removeItem(l10n: l10n, repository: repository, item: item),
          child: InkWell(
            key: Key('inbox_row_${item.id}'),
            onTap: () => showInboxEditSheet(context, item),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: tokens.spacing48 + 8),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing16,
                  vertical: tokens.spacing12,
                ),
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _removeItem({
    required AppLocalizations l10n,
    required InboxRepository repository,
    required InboxItem item,
  }) async {
    final snapshot = await repository.remove(item.id);
    showRemoveUndoSnackBar(
      message: l10n.removedItem(snapshot.title),
      undoLabel: l10n.undo,
      onUndo: () => repository.restore(snapshot),
    );
  }
}
