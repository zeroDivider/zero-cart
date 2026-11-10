import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Three-tab shell with [NavigationBar] (D-01). Inbox has a badge slot.
class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
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
            icon: const Badge(
              isLabelVisible: false,
              child: Icon(Icons.inbox_outlined),
            ),
            selectedIcon: const Badge(
              isLabelVisible: false,
              child: Icon(Icons.inbox),
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
