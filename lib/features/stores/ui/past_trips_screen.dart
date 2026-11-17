import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Finished lists for one store (Past trips). Imports lists providers only.
class PastTripsScreen extends ConsumerWidget {
  const PastTripsScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncLists = ref.watch(finishedListsForStoreProvider(storeId));
    final asyncStore = ref.watch(storeByIdProvider(storeId));
    // Disable Restore until the store is known active (LI-5).
    final store = asyncStore.asData?.value;
    final storeArchived = store == null || store.archivedAt != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pastTripsScreenTitle)),
      body: AsyncBody(
        value: asyncLists,
        onRetry: () => ref.invalidate(finishedListsForStoreProvider(storeId)),
        builder: (context, lists) {
          if (lists.isEmpty) {
            final tokens = Theme.of(context).extension<AppTokens>()!;
            final colorScheme = Theme.of(context).colorScheme;
            return Center(
              child: Padding(
                padding: EdgeInsets.all(tokens.spacing24),
                child: Text(
                  l10n.pastTripsEmpty,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final colorScheme = Theme.of(context).colorScheme;
          return ListView.separated(
            itemCount: lists.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, index) {
              final list = lists[index];
              return _PastTripRow(list: list, storeArchived: storeArchived);
            },
          );
        },
      ),
    );
  }
}

class _PastTripRow extends ConsumerWidget {
  const _PastTripRow({required this.list, required this.storeArchived});

  final ShoppingList list;
  final bool storeArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;

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
                label: list.name,
                child: InkWell(
                  key: Key('past_trip_row_${list.id}'),
                  onTap: () =>
                      context.push(AppRoutes.listDetailsLocation(list.id)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.spacing8),
                    child: Text(
                      list.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
            ),
            if (storeArchived)
              Padding(
                padding: EdgeInsets.only(left: tokens.spacing8),
                child: Text(
                  key: Key('past_trip_restore_hint_${list.id}'),
                  l10n.restoreStoreFirstHint,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            TextButton(
              key: Key('past_trip_restore_${list.id}'),
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
