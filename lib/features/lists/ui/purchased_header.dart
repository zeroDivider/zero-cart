import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Expand/collapse header for the Purchased section on a list screen.
class PurchasedHeader extends ConsumerWidget {
  const PurchasedHeader({
    required this.listId,
    required this.count,
    required this.expanded,
    super.key,
  });

  final String listId;
  final int count;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return InkWell(
      key: const Key('purchased_section_header'),
      onTap: () =>
          ref.read(purchasedExpandedProvider(listId).notifier).toggle(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.spacing48),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing16,
            vertical: tokens.spacing12,
          ),
          child: Row(
            children: [
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                child: const Icon(Icons.expand_more),
              ),
              SizedBox(width: tokens.spacing8),
              Text(
                l10n.purchasedSection(count),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
