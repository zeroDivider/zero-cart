import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/stores/ui/store_active_lists_section.dart';
import 'package:zero_cart/features/stores/ui/stores_screen.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Store details at `/stores/:id` (ST-3, ST-4, F12).
class StoreDetailsScreen extends ConsumerWidget {
  const StoreDetailsScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncStore = ref.watch(storeByIdProvider(storeId));

    return asyncStore.when(
      data: (store) {
        if (store == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.storeDetailsPlaceholder)),
            body: Center(child: Text(l10n.storeNotFound)),
          );
        }
        return _StoreDetailsBody(store: store);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.storeDetailsPlaceholder)),
        body: const SizedBox.shrink(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.storeDetailsPlaceholder)),
        body: Center(child: Text('$error')),
      ),
    );
  }
}

class _StoreDetailsBody extends ConsumerWidget {
  const _StoreDetailsBody({required this.store});

  final Store store;

  bool get _isArchived => store.archivedAt != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(store.name),
        actions: [
          if (_isArchived)
            TextButton(
              key: const Key('store_details_restore'),
              onPressed: () => _restore(context, ref),
              child: Text(l10n.restore),
            )
          else ...[
            TextButton(
              key: const Key('store_details_edit'),
              onPressed: () => editStore(context, ref, store),
              child: Text(l10n.edit),
            ),
            TextButton(
              key: const Key('store_details_archive'),
              onPressed: () => _archive(context, ref),
              child: Text(l10n.archiveAction),
            ),
          ],
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(tokens.spacing16),
        children: [
          _StoreHeader(store: store),
          SizedBox(height: tokens.spacing24),
          StoreActiveListsSection(storeId: store.id, readOnly: _isArchived),
          SizedBox(height: tokens.spacing24),
          Text(
            l10n.storeWishlistSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing8),
          Text(
            l10n.storeWishlistPlaceholder,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(storesRepositoryProvider);
    final count = await repository.countActiveLists(store.id);
    if (!context.mounted) {
      return;
    }
    if (count > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            key: const Key('archive_store_dialog'),
            title: Text(l10n.archiveStoreTitle),
            content: Text(l10n.archiveStoreBody(count)),
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
    }
    await repository.archive(store.id);
    if (context.mounted) {
      context.pop();
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    await ref.read(storesRepositoryProvider).restore(store.id);
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
