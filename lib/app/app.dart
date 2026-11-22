import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/locale_resolution.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/features/settings/settings_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Root widget: themes, localisation, and go_router.
class ZeroCartApp extends ConsumerWidget {
  ZeroCartApp({super.key, GoRouter? router})
    : router = router ?? AppRouter.create();

  /// Router for the app; injectable in tests.
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While the settings stream loads, follow the system (SE-1 default).
    final themeMode =
        ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      localeResolutionCallback: resolveAppLocale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    );
  }
}
