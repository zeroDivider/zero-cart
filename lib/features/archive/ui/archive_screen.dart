import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/archived_list_with_store.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

enum _ArchiveSegment { stores, lists }

/// Archive screen with Stores / Lists segments (ST-4, F12; Lists = manual only).
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  _ArchiveSegment _segment = _ArchiveSegment.stores;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.archive)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing16,
              tokens.spacing8,
              tokens.spacing16,
              tokens.spacing8,
            ),
            child: SegmentedButton<_ArchiveSegment>(
              segments: [
                ButtonSegment(
                  value: _ArchiveSegment.stores,
                  label: Text(l10n.archiveSegmentStores),
                ),
                ButtonSegment(
                  value: _ArchiveSegment.lists,
                  label: Text(l10n.archiveSegmentLists),
                ),
              ],
              selected: {_segment},
              onSelectionChanged: (next) {
                setState(() => _segment = next.single);
              },
            ),
          ),
          Expanded(
            child: _segment == _ArchiveSegment.stores
                ? const _ArchivedStoresPane()
                : const _ArchivedListsPane(),
          ),
        ],
      ),
    );
  }
}

class _ArchivedStoresPane extends ConsumerWidget {
  const _ArchivedStoresPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncStores = ref.watch(archivedStoresProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return AsyncBody(
      value: asyncStores,
      onRetry: () => ref.invalidate(archivedStoresProvider),
      builder: (context, stores) {
        if (stores.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing24),
              child: Text(
                l10n.archiveStoresEmpty,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: stores.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: colorScheme.outlineVariant),
          itemBuilder: (context, index) {
            final store = stores[index];
            return _ArchivedStoreRow(store: store);
          },
        );
      },
    );
  }
}

class _ArchivedStoreRow extends ConsumerWidget {
  const _ArchivedStoreRow({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.spacing48 + 8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing16,
          vertical: tokens.spacing8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: store.name,
                child: InkWell(
                  key: Key('archived_store_row_${store.id}'),
                  onTap: () =>
                      context.push(AppRoutes.storeDetailsLocation(store.id)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.spacing8),
                    child: Row(
                      children: [
                        Container(
                          width: tokens.spacing16,
                          height: tokens.spacing16,
                          decoration: BoxDecoration(
                            color: tokens.storeColor(store.colorKey),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: tokens.spacing12),
                        Expanded(
                          child: Text(
                            store.name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              key: Key('archived_store_restore_${store.id}'),
              onPressed: () {
                final captured = AppLocalizations.of(context);
                runWrite(
                  () => ref.read(storesRepositoryProvider).restore(store.id),
                  l10n: captured,
                );
              },
              child: Text(l10n.restore),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedListsPane extends ConsumerWidget {
  const _ArchivedListsPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncLists = ref.watch(manualArchivedListsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return AsyncBody(
      value: asyncLists,
      onRetry: () => ref.invalidate(manualArchivedListsProvider),
      builder: (context, rows) {
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing24),
              child: Text(
                l10n.archiveListsEmpty,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) =>
              Divider(height: 1, color: colorScheme.outlineVariant),
          itemBuilder: (context, index) {
            return _ArchivedListRow(row: rows[index]);
          },
        );
      },
    );
  }
}

class _ArchivedListRow extends ConsumerWidget {
  const _ArchivedListRow({required this.row});

  final ArchivedListWithStore row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final list = row.list;
    final storeArchived = row.isStoreArchived;
    final reasonLabel =
        list.archiveReason == ListsRepository.archiveReasonFinished
        ? l10n.archiveReasonFinishedLabel
        : l10n.archiveReasonManualLabel;
    final subtitle = storeArchived
        ? l10n.archivedListSubtitleStoreArchived(
            row.storeName,
            reasonLabel,
            l10n.restoreStoreFirstHint,
          )
        : l10n.archivedListSubtitle(row.storeName, reasonLabel);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: tokens.spacing48 + 8),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing16,
          vertical: tokens.spacing8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: '${list.name}, $subtitle',
                child: InkWell(
                  key: Key('archived_list_row_${list.id}'),
                  onTap: () =>
                      context.push(AppRoutes.listDetailsLocation(list.id)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.spacing8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        SizedBox(height: tokens.spacing4),
                        Text(
                          key: Key('archived_list_subtitle_${list.id}'),
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              key: Key('archived_list_restore_${list.id}'),
              onPressed: storeArchived
                  ? null
                  : () {
                      final captured = AppLocalizations.of(context);
                      runWrite(
                        () =>
                            ref.read(listsRepositoryProvider).restore(list.id),
                        l10n: captured,
                      );
                    },
              child: Text(l10n.restore),
            ),
          ],
        ),
      ),
    );
  }
}
