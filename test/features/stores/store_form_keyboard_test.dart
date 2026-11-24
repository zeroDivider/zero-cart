import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/stores/ui/sheets/store_form_sheet.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

const _screen = Size(400, 800);
const _keyboard = 300.0;

Widget _app({required Widget home, double textScale = 1}) {
  return MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      );
    },
    home: home,
  );
}

Store _store() {
  return Store(
    id: 'store-1',
    name: 'Lidl',
    colorKey: 'lime',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

/// Opens the edit-store sheet on a short surface with the keyboard up.
Future<AppLocalizations> _openEditStore(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
  addTearDown(tester.view.reset);

  late AppLocalizations l10n;
  await tester.pumpWidget(
    _app(
      textScale: textScale,
      home: Builder(
        builder: (context) {
          l10n = AppLocalizations.of(context);
          return Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showStoreFormSheet(
                  context,
                  draftMode: true,
                  existing: _store(),
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return l10n;
}

void main() {
  testWidgets('edit store note scrolls above the keyboard', (tester) async {
    final l10n = await _openEditStore(tester);

    expect(tester.takeException(), isNull);
    _expectChromeAboveKeyboard(tester, l10n);

    await _scrollSheetToEnd(tester);
    _expectNoteAboveSave(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit store note scrolls above the keyboard at 200% text', (
    tester,
  ) async {
    final l10n = await _openEditStore(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    _expectChromeAboveKeyboard(tester, l10n);

    await _scrollSheetToEnd(tester);
    _expectNoteAboveSave(tester);
    expect(tester.takeException(), isNull);
  });
}

void _expectChromeAboveKeyboard(WidgetTester tester, AppLocalizations l10n) {
  final keyboardTop = _screen.height - _keyboard;
  expect(
    tester.getRect(find.text(l10n.editStore)).top,
    greaterThanOrEqualTo(0),
  );
  expect(
    tester.getRect(find.byKey(const Key('store_form_save'))).bottom,
    lessThanOrEqualTo(keyboardTop),
  );
}

/// Text fields own their own [Scrollable]. Jump the sheet list, which is the
/// tallest one, so the note can sit above Save.
Future<void> _scrollSheetToEnd(WidgetTester tester) async {
  final scrollable = _sheetScrollable(tester, find.byType(StoreFormSheet));
  expect(scrollable.position.maxScrollExtent, greaterThan(0));
  scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
  await tester.pump();
}

/// The sheet list, not a text field's inner scroller.
ScrollableState _sheetScrollable(WidgetTester tester, Finder scope) {
  final matches = find
      .descendant(of: scope, matching: find.byType(Scrollable))
      .evaluate()
      .toList();
  matches.sort((a, b) {
    final aHeight = (a.renderObject! as RenderBox).size.height;
    final bHeight = (b.renderObject! as RenderBox).size.height;
    return bHeight.compareTo(aHeight);
  });
  return tester.state<ScrollableState>(find.byWidget(matches.first.widget));
}

void _expectNoteAboveSave(WidgetTester tester) {
  expect(
    tester.getRect(find.byKey(const Key('store_form_note'))).bottom,
    lessThanOrEqualTo(
      tester.getRect(find.byKey(const Key('store_form_save'))).top,
    ),
  );
}
