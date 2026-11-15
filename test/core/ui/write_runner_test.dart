import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

void main() {
  tearDown(() {
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
  });

  testWidgets('runWrite returns true on success and shows nothing', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final ok = await runWrite(() async {}, l10n: l10n);
    await tester.pump();

    expect(ok, isTrue);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('runWrite shows mapped error snackbar and returns false', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final ok = await runWrite(() async {
      throw const StoreArchivedException();
    }, l10n: l10n);
    await tester.pump();

    expect(ok, isFalse);
    expect(find.text(l10n.errorStoreArchived), findsOneWidget);
  });
}
