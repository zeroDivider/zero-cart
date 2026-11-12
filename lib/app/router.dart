import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/scaffold_with_nav_bar.dart';
import 'package:zero_cart/features/archive/ui/archive_screen.dart';
import 'package:zero_cart/features/home/ui/home_screen.dart';
import 'package:zero_cart/features/inbox/ui/inbox_screen.dart';
import 'package:zero_cart/features/lists/ui/list_screen.dart';
import 'package:zero_cart/features/settings/ui/about_placeholder_screen.dart';
import 'package:zero_cart/features/settings/ui/settings_placeholder_screen.dart';
import 'package:zero_cart/features/stores/ui/store_details_screen.dart';
import 'package:zero_cart/features/stores/ui/stores_screen.dart';
import 'package:zero_cart/features/wishlist/ui/wishlist_placeholder_screen.dart';

export 'package:go_router/go_router.dart' show GoRouter;

/// Route path string constants (ADR-0006).
abstract final class AppRoutes {
  static const String home = '/home';
  static const String inbox = '/inbox';
  static const String stores = '/stores';
  static const String storeDetails = '/stores/:id';
  static const String wishlist = '/stores/:id/wishlist';
  static const String listDetails = '/lists/:id';
  static const String archive = '/archive';
  static const String settings = '/settings';
  static const String about = '/settings/about';

  static String storeDetailsLocation(String id) => '/stores/$id';
  static String wishlistLocation(String id) => '/stores/$id/wishlist';
  static String listDetailsLocation(String id) => '/lists/$id';
}

/// Builds the app [GoRouter] with a stateful three-tab shell.
abstract final class AppRouter {
  static GoRouter create({String initialLocation = AppRoutes.home}) {
    final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: initialLocation,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return ScaffoldWithNavBar(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.inbox,
                  builder: (context, state) => const InboxScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.stores,
                  builder: (context, state) => const StoresScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.storeDetails,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return StoreDetailsScreen(storeId: id);
          },
          routes: [
            GoRoute(
              path: 'wishlist',
              parentNavigatorKey: rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return WishlistPlaceholderScreen(storeId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.listDetails,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return ListScreen(listId: id);
          },
        ),
        GoRoute(
          path: AppRoutes.archive,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const ArchiveScreen(),
        ),
        GoRoute(
          path: AppRoutes.settings,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => const SettingsPlaceholderScreen(),
          routes: [
            GoRoute(
              path: 'about',
              parentNavigatorKey: rootNavigatorKey,
              builder: (context, state) => const AboutPlaceholderScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
