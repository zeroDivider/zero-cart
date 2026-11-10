import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zero_cart/app/locale_resolution.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Root widget: themes, localisation, and go_router.
class ZeroCartApp extends StatelessWidget {
  ZeroCartApp({super.key, GoRouter? router})
    : router = router ?? AppRouter.create();

  /// Router for the app; injectable in tests.
  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
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
