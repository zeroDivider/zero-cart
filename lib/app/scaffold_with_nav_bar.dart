import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/core/widgets/quick_add_fab.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/inbox/ui/quick_add_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Three-tab shell with [NavigationBar] (D-01). Inbox badge shows count (IB-4).
class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final inboxCount = ref
        .watch(inboxItemsProvider)
        .maybeWhen(data: (items) => items.length, orElse: () => 0);
    final badgeLabel = inboxCount >= 100
        ? '99+'
        : (inboxCount > 0 ? '$inboxCount' : null);

    return Scaffold(
      body: navigationShell,
      floatingActionButton: QuickAddFab(
        heroTag: 'quick_add_shell',
        onPressed: () => showQuickAddSheet(context),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: badgeLabel != null,
              label: badgeLabel == null ? null : Text(badgeLabel),
              child: const Icon(Icons.inbox_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: badgeLabel != null,
              label: badgeLabel == null ? null : Text(badgeLabel),
              child: const Icon(Icons.inbox),
            ),
            label: l10n.navInbox,
          ),
          NavigationDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront),
            label: l10n.navStores,
          ),
        ],
      ),
    );
  }
}
