import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/features/lists/active_list_progress.dart';
import 'package:zero_cart/features/lists/list_form_sheet.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Active list cards and New list action for store details (LI-1, F9).
///
/// Lives in stores `ui/` and depends on lists providers + feature-root form,
/// not on `features/lists/ui/` (architecture §2.3).
class StoreActiveListsSection extends ConsumerWidget {
  const StoreActiveListsSection({
    required this.storeId,
    required this.readOnly,
    super.key,
  });

  final String storeId;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final asyncLists = ref.watch(activeListsForStoreProvider(storeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.storeListsSection,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: tokens.spacing8),
        asyncLists.when(
          skipLoadingOnReload: true,
          data: (rows) {
            if (rows.isEmpty) {
              return Text(
                l10n.storeListsEmpty,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              );
            }
            return Column(
              children: [
                for (final row in rows) ...[
                  _ListCard(progress: row),
                  SizedBox(height: tokens.spacing8),
                ],
              ],
            );
          },
          loading: () => Text(
            l10n.storeListsEmpty,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          error: (error, _) => Text('$error'),
        ),
        if (!readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('store_details_new_list'),
              onPressed: () => _createList(context, ref),
              child: Text(l10n.newListAction),
            ),
          ),
      ],
    );
  }

  Future<void> _createList(BuildContext context, WidgetRef ref) async {
    final draft = await showListFormSheet(context);
    if (draft == null || !context.mounted) {
      return;
    }
    final list = await ref
        .read(listsRepositoryProvider)
        .create(storeId: storeId, name: draft.name);
    if (!context.mounted) {
      return;
    }
    context.push(AppRoutes.listDetailsLocation(list.id));
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({required this.progress});

  final ActiveListProgress progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final list = progress.list;

    return Semantics(
      button: true,
      label: l10n.listCardSemantics(list.name, progress.itemsLeft),
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        child: InkWell(
          key: Key('store_list_card_${list.id}'),
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          onTap: () => context.push(AppRoutes.listDetailsLocation(list.id)),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tokens.spacing48),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing16,
                vertical: tokens.spacing12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  SizedBox(height: tokens.spacing4),
                  Text(
                    l10n.listItemsLeft(progress.itemsLeft),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
