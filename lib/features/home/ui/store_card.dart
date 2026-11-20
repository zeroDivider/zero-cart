import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zero_cart/app/theme/app_text.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/features/home/store_summary.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Large Home store card (design system 3.12).
class StoreCard extends StatelessWidget {
  const StoreCard({
    super.key,
    required this.summary,
    required this.index,
    required this.onTap,
    this.tilt = true,
  });

  final StoreSummary summary;
  final int index;
  final VoidCallback onTap;

  /// When false (large text scale), cards sit flat in one column.
  final bool tilt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final store = summary.store;
    final storeColor = tokens.storeColor(store.colorKey);
    final fill = tokens.homeCardFill(store.colorKey, colorScheme.surface);
    final tall = index % 3 == 0;
    final minHeight = tall
        ? tokens.homeCardTallMinHeight
        : tokens.homeCardMinHeight;
    final label = summary.activeListCount == 0
        ? l10n.homeNoListsYet
        : (summary.unpurchasedCount > 0
              ? l10n.homeLeftToBuy
              : l10n.homeCartIsEmpty);
    final semantics = l10n.homeStoreCardSemantics(
      store.name,
      summary.unpurchasedCount,
      summary.activeListCount,
    );

    Widget card = Material(
      color: fill,
      borderRadius: BorderRadius.circular(tokens.radiusXl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('home_store_card_${store.id}'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: ExcludeSemantics(
            child: Stack(
              children: [
                Positioned(
                  right: -tokens.homeCardBlobSize / 3.7,
                  top: -tokens.homeCardBlobSize / 3.7,
                  child: Container(
                    width: tokens.homeCardBlobSize,
                    height: tokens.homeCardBlobSize,
                    decoration: BoxDecoration(
                      color: storeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(tokens.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: tokens.spacing48),
                      Text(
                        '${summary.unpurchasedCount}',
                        style: AppText.storeCount(color: colorScheme.onSurface),
                      ),
                      SizedBox(height: tokens.spacing4),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: colorScheme.onSurface),
                      ),
                      SizedBox(height: tokens.spacing8),
                      Text(
                        store.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: tokens.spacing8),
                      _ProgressBar(
                        progress: summary.purchasedProgress,
                        height: tokens.homeCardProgressHeight,
                        trackColor: colorScheme.onSurface.withValues(
                          alpha: 0.12,
                        ),
                        fillColor: colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      SizedBox(height: tokens.spacing8),
                      Text(
                        l10n.homeListCount(summary.activeListCount),
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
      ),
    );

    if (tilt) {
      final sign = index.isEven ? -1.0 : 1.0;
      card = Transform.rotate(
        angle: sign * tokens.homeCardTiltDegrees * math.pi / 180,
        child: card,
      );
    }

    return Semantics(button: true, label: semantics, child: card);
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.progress,
    required this.height,
    required this.trackColor,
    required this.fillColor,
  });

  final double progress;
  final double height;
  final Color trackColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: trackColor),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: clamped,
              child: ColoredBox(color: fillColor),
            ),
          ],
        ),
      ),
    );
  }
}
