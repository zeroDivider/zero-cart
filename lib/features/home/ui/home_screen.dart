import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_text.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/quick_add_fab.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Home tab: wordmark, settings entry (D-01), placeholder body, Quick add FAB.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

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
      body: Center(
        child: Text(
          l10n.homePlaceholder,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      floatingActionButton: const QuickAddFab(),
    );
  }
}
