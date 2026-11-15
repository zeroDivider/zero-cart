import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/core/repository_exceptions.dart';
import 'package:zero_cart/core/widgets/form_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

Widget _app({required Widget home}) {
  return MaterialApp(
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
  testWidgets('stays open and shows inline error when onSubmit throws', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return FormSheetScaffold<void>(
                        title: const Text('Edit'),
                        submitLabel: l10n.save,
                        onSubmit: () async {
                          throw const ListArchivedException();
                        },
                        body: (context, controller) => const SizedBox.shrink(),
                      );
                    },
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
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text(l10n.errorListArchived), findsOneWidget);
  });

  testWidgets('FormValidationAbort stays open without scaffold error', (
    tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (sheetContext) {
                      return FormSheetScaffold<void>(
                        title: const Text('Edit'),
                        submitLabel: l10n.save,
                        onSubmit: () async {
                          throw const FormValidationAbort();
                        },
                        body: (context, controller) => const SizedBox.shrink(),
                      );
                    },
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
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text(l10n.errorGeneric), findsNothing);
  });

  testWidgets('closes with the result on success', (tester) async {
    late AppLocalizations l10n;
    late BuildContext hostContext;
    await tester.pumpWidget(
      _app(
        home: Builder(
          builder: (context) {
            hostContext = context;
            l10n = AppLocalizations.of(context);
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final resultFuture = showModalBottomSheet<String>(
      context: hostContext,
      isScrollControlled: true,
      builder: (sheetContext) {
        return FormSheetScaffold<String>(
          title: const Text('Edit'),
          submitLabel: l10n.save,
          onSubmit: () async => 'draft-value',
          body: (context, controller) {
            return TextField(
              onChanged: (_) => controller.clearError(),
              decoration: const InputDecoration(labelText: 'Name'),
            );
          },
        );
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(await resultFuture, 'draft-value');
    expect(find.byType(FormSheetScaffold<String>), findsNothing);
  });
}
