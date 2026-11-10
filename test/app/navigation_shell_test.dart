import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/app.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/features/home/ui/home_screen.dart';
import 'package:zero_cart/features/inbox/ui/inbox_screen.dart';
import 'package:zero_cart/features/settings/ui/settings_placeholder_screen.dart';
import 'package:zero_cart/features/stores/ui/stores_screen.dart';

void main() {
  testWidgets('tabs switch and keep branch widgets mounted', (tester) async {
    final router = AppRouter.create();
    await tester.pumpWidget(ZeroCartApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(InboxScreen), findsNothing);

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();

    expect(find.byType(InboxScreen), findsOneWidget);
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.inbox,
    );

    await tester.tap(find.text('Stores'));
    await tester.pumpAndSettle();

    expect(find.byType(StoresScreen), findsOneWidget);
    expect(find.byType(InboxScreen, skipOffstage: false), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      AppRoutes.stores,
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.home);
  });

  testWidgets('settings icon appears only on Home', (tester) async {
    await tester.pumpWidget(ZeroCartApp(router: AppRouter.create()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_settings_button')), findsOneWidget);

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_settings_button')), findsNothing);

    await tester.tap(find.text('Stores'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_settings_button')), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_settings_button')), findsOneWidget);
  });

  testWidgets('back from settings returns to Home', (tester) async {
    final router = AppRouter.create();
    await tester.pumpWidget(ZeroCartApp(router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_settings_button')));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPlaceholderScreen), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      AppRoutes.settings,
    );

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPlaceholderScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(router.canPop(), isFalse);
    expect(router.routerDelegate.currentConfiguration.uri.path, AppRoutes.home);
  });
}
