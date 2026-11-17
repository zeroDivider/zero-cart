import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Store-details Past trips entry card with live finished-list count.
class StorePastTripsCard extends ConsumerWidget {
  const StorePastTripsCard({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final asyncCount = ref.watch(finishedCountForStoreProvider(storeId));

    return AsyncBody(
      value: asyncCount,
      onRetry: () => ref.invalidate(finishedCountForStoreProvider(storeId)),
      builder: (context, count) {
        return Semantics(
          button: true,
          label: l10n.pastTripsCardSemantics(count),
          child: Material(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            child: InkWell(
              key: const Key('store_past_trips_card'),
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              onTap: () => context.push(AppRoutes.pastTripsLocation(storeId)),
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
                        l10n.storePastTripsSection,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SizedBox(height: tokens.spacing4),
                      Text(
                        l10n.pastTripsCount(count),
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
      },
    );
  }
}
