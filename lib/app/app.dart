import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zero_cart/app/locale_resolution.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Root widget: themes, localisation, and go_router.
class ZeroCartApp extends StatelessWidget {
  const ZeroCartApp({super.key, this.router});

  /// Optional override for tests.
  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    final goRouter = router ?? AppRouter.create();
    return MaterialApp.router(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: goRouter,
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
