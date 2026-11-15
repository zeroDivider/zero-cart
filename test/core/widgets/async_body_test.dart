import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders loading', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AsyncBody<int>(
          value: const AsyncLoading(),
          onRetry: () {},
          builder: (context, data) => Text('$data'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders data', (tester) async {
    await tester.pumpWidget(
      _wrap(
        AsyncBody<String>(
          value: const AsyncData('hello'),
          onRetry: () {},
          builder: (context, data) => Text(data),
        ),
      ),
    );

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('renders localised error and Retry reloads', (tester) async {
    var retries = 0;
    late AppLocalizations l10n;

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return AsyncBody<int>(
              value: const AsyncError(
                StoreArchivedException(),
                StackTrace.empty,
              ),
              onRetry: () => retries++,
              builder: (context, data) => Text('$data'),
            );
          },
        ),
      ),
    );

    expect(find.text(l10n.errorStoreArchived), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pump();

    expect(retries, 1);
  });

  testWidgets('unknown load errors use asyncLoadFailed', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return AsyncBody<int>(
              value: AsyncError(Exception('raw'), StackTrace.empty),
              onRetry: () {},
              builder: (context, data) => Text('$data'),
            );
          },
        ),
      ),
    );

    expect(find.text(l10n.asyncLoadFailed), findsOneWidget);
    expect(find.textContaining('raw'), findsNothing);
  });
}
