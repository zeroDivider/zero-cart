import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_text.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/features/home/home_providers.dart';
import 'package:zero_cart/features/home/store_summary.dart';
import 'package:zero_cart/features/home/ui/store_card.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Home tab: wordmark, settings, Inbox pill, staggered store board (D-01 / 3.12).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final summariesAsync = ref.watch(homeStoreSummariesProvider);
    final inboxAsync = ref.watch(inboxItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              l10n.appTitle,
              style: AppText.wordmark(color: colorScheme.primary),
            ),
            SizedBox(width: tokens.spacing8),
            Container(
              width: tokens.spacing8,
              height: tokens.spacing8,
              decoration: BoxDecoration(
                color: colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('home_settings_button'),
            tooltip: l10n.settings,
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: AsyncBody(
        value: summariesAsync,
        onRetry: () => ref.invalidate(homeStoreSummariesProvider),
        builder: (context, summaries) {
          return AsyncBody(
            value: inboxAsync,
            onRetry: () => ref.invalidate(inboxItemsProvider),
            builder: (context, inboxItems) {
              if (summaries.isEmpty) {
                return _HomeEmptyState(inboxCount: inboxItems.length);
              }
              return _HomeBoard(
                summaries: summaries,
                inboxCount: inboxItems.length,
              );
            },
          );
        },
      ),
    );
  }
}

class _HomeEmptyState extends ConsumerWidget {
  const _HomeEmptyState({required this.inboxCount});

  final int inboxCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return ListView(
      padding: EdgeInsets.all(tokens.spacing16),
      children: [
        if (inboxCount > 0) ...[
          _InboxPill(count: inboxCount),
          SizedBox(height: tokens.spacing16),
        ],
        SizedBox(height: tokens.spacing48),
        Text(
          l10n.storesEmptyTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing8),
        Text(
          l10n.storesEmptyBody,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing24),
        Center(
          child: FilledButton(
            key: const Key('home_empty_create'),
            onPressed: () => _createStore(context, ref),
            child: Text(l10n.createStore),
          ),
        ),
      ],
    );
  }
}

class _HomeBoard extends StatelessWidget {
  const _HomeBoard({required this.summaries, required this.inboxCount});

  final List<StoreSummary> summaries;
  final int inboxCount;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final singleColumn = textScale > tokens.homeTextScaleSingleColumn;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing16,
            tokens.spacing8,
            tokens.spacing16,
            tokens.spacing24,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (inboxCount > 0) ...[
                _InboxPill(count: inboxCount),
                SizedBox(height: tokens.spacing16),
              ],
              if (singleColumn)
                _SingleColumnBoard(summaries: summaries)
              else
                _TwoColumnBoard(summaries: summaries),
            ]),
          ),
        ),
      ],
    );
  }
}

class _InboxPill extends StatelessWidget {
  const _InboxPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
        child: InkWell(
          key: const Key('home_inbox_pill'),
          borderRadius: BorderRadius.circular(tokens.radiusPill),
          onTap: () => context.go(AppRoutes.inbox),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tokens.spacing48),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing16,
                vertical: tokens.spacing8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: tokens.spacing16,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  SizedBox(width: tokens.spacing8),
                  Flexible(
                    child: Text(
                      l10n.homeInboxPill(count),
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: colorScheme.onSecondaryContainer),
                    ),
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

class _SingleColumnBoard extends StatelessWidget {
  const _SingleColumnBoard({required this.summaries});

  final List<StoreSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    return Column(
      children: [
        for (var i = 0; i < summaries.length; i++) ...[
          if (i > 0) SizedBox(height: tokens.homeBoardGap),
          StoreCard(
            summary: summaries[i],
            index: i,
            tilt: false,
            onTap: () =>
                AppRouter.goToStoreDetails(context, summaries[i].store.id),
          ),
        ],
      ],
    );
  }
}

class _TwoColumnBoard extends StatelessWidget {
  const _TwoColumnBoard({required this.summaries});

  final List<StoreSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final left = <Widget>[];
    final right = <Widget>[];

    for (var i = 0; i < summaries.length; i++) {
      final card = StoreCard(
        summary: summaries[i],
        index: i,
        onTap: () => AppRouter.goToStoreDetails(context, summaries[i].store.id),
      );
      if (i.isEven) {
        left.add(card);
      } else {
        right.add(card);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < left.length; i++) ...[
                if (i > 0) SizedBox(height: tokens.homeBoardGap),
                left[i],
              ],
            ],
          ),
        ),
        SizedBox(width: tokens.homeBoardGap),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: tokens.homeBoardRightOffset),
            child: Column(
              children: [
                for (var i = 0; i < right.length; i++) ...[
                  if (i > 0) SizedBox(height: tokens.homeBoardGap),
                  right[i],
                ],
              ],
            ),
          ),
        ),
      ],
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
