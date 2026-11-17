import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';
import 'package:zero_cart/features/stores/ui/store_active_lists_section.dart';
import 'package:zero_cart/features/stores/ui/store_past_trips_card.dart';
import 'package:zero_cart/features/stores/ui/wishlist_card.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Store details at `/stores/:id` (ST-3, ST-4, F12).
class StoreDetailsScreen extends ConsumerWidget {
  const StoreDetailsScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncStore = ref.watch(storeByIdProvider(storeId));
    final store = asyncStore.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(store?.name ?? l10n.storeDetailsPlaceholder),
        actions: [
          if (store != null) ..._storeActions(context, ref, store, l10n),
        ],
      ),
      body: AsyncBody(
        value: asyncStore,
        onRetry: () => ref.invalidate(storeByIdProvider(storeId)),
        builder: (context, data) {
          if (data == null) {
            return Center(child: Text(l10n.storeNotFound));
          }
          return _StoreDetailsBody(store: data);
        },
      ),
    );
  }

  List<Widget> _storeActions(
    BuildContext context,
    WidgetRef ref,
    Store store,
    AppLocalizations l10n,
  ) {
    final isArchived = store.archivedAt != null;
    if (isArchived) {
      return [
        TextButton(
          key: const Key('store_details_restore'),
          onPressed: () => _restore(context, ref, store),
          child: Text(l10n.restore),
        ),
      ];
    }
    return [
      TextButton(
        key: const Key('store_details_edit'),
        onPressed: () => _edit(context, ref, store),
        child: Text(l10n.edit),
      ),
      TextButton(
        key: const Key('store_details_archive'),
        onPressed: () => _archive(context, ref, store),
        child: Text(l10n.archiveAction),
      ),
    ];
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Store store) async {
    await showStoreFormSheet(
      context,
      existing: store,
      repository: ref.read(storesRepositoryProvider),
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Store store,
  ) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(storesRepositoryProvider);
    final count = await repository.countActiveLists(store.id);
    if (!context.mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('archive_store_dialog'),
          title: Text(l10n.archiveStoreTitle),
          content: Text(
            count > 0
                ? l10n.archiveStoreBody(count)
                : l10n.archiveStoreBodyNone,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              key: const Key('archive_store_confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.archiveAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final ok = await runWrite(() => repository.archive(store.id), l10n: l10n);
    if (ok && context.mounted) {
      context.pop();
    }
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    Store store,
  ) async {
    final l10n = AppLocalizations.of(context);
    await runWrite(
      () => ref.read(storesRepositoryProvider).restore(store.id),
      l10n: l10n,
    );
  }
}

class _StoreDetailsBody extends StatelessWidget {
  const _StoreDetailsBody({required this.store});

  final Store store;

  bool get _isArchived => store.archivedAt != null;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return ListView(
      padding: EdgeInsets.all(tokens.spacing16),
      children: [
        _StoreHeader(store: store),
        SizedBox(height: tokens.spacing24),
        StoreActiveListsSection(storeId: store.id, readOnly: _isArchived),
        SizedBox(height: tokens.spacing24),
        StoreWishlistCard(storeId: store.id),
        SizedBox(height: tokens.spacing16),
        StorePastTripsCard(storeId: store.id),
      ],
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final address = store.address;
    final note = store.note;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: tokens.spacing4),
          child: Container(
            width: tokens.spacing16,
            height: tokens.spacing16,
            decoration: BoxDecoration(
              color: tokens.storeColor(store.colorKey),
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(store.name, style: Theme.of(context).textTheme.titleLarge),
              if (address != null && address.isNotEmpty) ...[
                SizedBox(height: tokens.spacing4),
                Text(
                  address,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
              if (note != null && note.isNotEmpty) ...[
                SizedBox(height: tokens.spacing4),
                Text(
                  note,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
