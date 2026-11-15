import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/features/stores/active_store_summary.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Stores tab: active stores alphabetically with New store and Archive (ST-1/2).
class StoresScreen extends ConsumerWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncStores = ref.watch(activeStoreSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navStores),
        actions: [
          IconButton(
            key: const Key('stores_archive'),
            tooltip: l10n.archive,
            onPressed: () => context.push(AppRoutes.archive),
            icon: const Icon(Icons.inventory_2_outlined),
          ),
        ],
      ),
      body: AsyncBody(
        value: asyncStores,
        onRetry: () => ref.invalidate(activeStoreSummariesProvider),
        builder: (context, summaries) {
          if (summaries.isEmpty) {
            return const _StoresEmptyState();
          }
          return _StoresList(summaries: summaries);
        },
      ),
    );
  }
}

class _StoresEmptyState extends ConsumerWidget {
  const _StoresEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.storesEmptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing8),
            Text(
              l10n.storesEmptyBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spacing24),
            FilledButton(
              key: const Key('stores_empty_create'),
              onPressed: () => _createStore(context, ref),
              child: Text(l10n.createStore),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoresList extends ConsumerWidget {
  const _StoresList({required this.summaries});

  final List<ActiveStoreSummary> summaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return ListView.separated(
      itemCount: summaries.length + 1,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colorScheme.outlineVariant),
      itemBuilder: (context, index) {
        if (index == summaries.length) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing16,
              vertical: tokens.spacing8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('stores_new_store'),
                onPressed: () => _createStore(context, ref),
                child: Text(l10n.newStoreAction),
              ),
            ),
          );
        }
        final summary = summaries[index];
        return _StoreRow(summary: summary);
      },
    );
  }
}

class _StoreRow extends StatelessWidget {
  const _StoreRow({required this.summary});

  final ActiveStoreSummary summary;

  @override
  Widget build(BuildContext context) {
    final store = summary.store;
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final countLabel = l10n.storeActiveLists(summary.activeListCount);

    return InkWell(
      key: Key('store_row_${store.id}'),
      onTap: () => context.push(AppRoutes.storeDetailsLocation(store.id)),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.spacing48 + 8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing16,
            vertical: tokens.spacing12,
          ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: tokens.spacing4),
                    Text(
                      countLabel,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _createStore(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(storesRepositoryProvider);
  final colorKey = await repository.nextFreeColorKey();
  if (!context.mounted) {
    return;
  }
  await showStoreFormSheet(
    context,
    initialColorKey: colorKey,
    repository: repository,
  );
}
