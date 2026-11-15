import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/core/ui/app_messenger.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

Widget _app({required Widget home}) {
  return MaterialApp(
    scaffoldMessengerKey: rootScaffoldMessengerKey,
    theme: AppTheme.light,
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  tearDown(() {
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
  });

  testWidgets('error snackbar shows the message', (tester) async {
    await tester.pumpWidget(
      _app(home: const Scaffold(body: SizedBox.shrink())),
    );

    AppMessenger.error('Boom');
    await tester.pump();

    expect(find.text('Boom'), findsOneWidget);
  });

  testWidgets('a new snackbar replaces the current one', (tester) async {
    await tester.pumpWidget(
      _app(home: const Scaffold(body: SizedBox.shrink())),
    );

    AppMessenger.info('First');
    await tester.pump();
    AppMessenger.error('Second');
    await tester.pump();

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('Undo works after the originating route is popped', (
    tester,
  ) async {
    var undone = false;

    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (routeContext) {
                        return Scaffold(
                          body: ElevatedButton(
                            key: const Key('show-undo'),
                            onPressed: () {
                              final capturedL10n = AppLocalizations.of(
                                routeContext,
                              );
                              AppMessenger.undo(
                                message: 'Removed',
                                undoLabel: capturedL10n.undo,
                                l10n: capturedL10n,
                                onUndo: () async {
                                  undone = true;
                                },
                              );
                              Navigator.of(routeContext).pop();
                            },
                            child: const Text('Remove'),
                          ),
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('show-undo')));
    await tester.pumpAndSettle();

    expect(find.text('Removed'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);

    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    action.onPressed();
    await tester.pumpAndSettle();

    expect(undone, isTrue);
  });

  testWidgets('failed Undo replaces the snackbar with a mapped error', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    AppMessenger.undo(
      message: 'Removed',
      undoLabel: l10n.undo,
      l10n: l10n,
      onUndo: () async {
        throw const ListUnavailableException();
      },
    );
    await tester.pump();

    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    action.onPressed();
    await tester.pumpAndSettle();

    expect(find.text('Removed'), findsNothing);
    expect(find.text(l10n.errorListUnavailable), findsOneWidget);
  });
}
