import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/app.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';
import 'package:zero_cart/features/inbox/ui/inbox_edit_sheet.dart';
import 'package:zero_cart/features/inbox/ui/quick_add_sheet.dart';

import '../../support/test_app.dart';

/// Invokes a button's onPressed inside [WidgetTester.runAsync] so Drift awaits
/// complete, then refreshes the inbox stream bridge.
Future<void> _tapButton(
  WidgetTester tester,
  Key key,
  TestAppHarness harness,
) async {
  final widget = tester.widget<ButtonStyleButton>(find.byKey(key));
  widget.onPressed!.call();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await pumpApp(tester, harness);
  // Bottom-sheet dismiss animation (design system ~250ms).
  await tester.pump(const Duration(milliseconds: 300));
  await pumpApp(tester, harness);
}

void main() {
  testWidgets('quick add inserts item, closes sheet, and updates badge', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await pumpApp(tester, harness);
    expect(find.byType(QuickAddSheet), findsOneWidget);

    await tester.enterText(find.byKey(const Key('quick_add_title')), 'Milk');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('quick_add_submit'), harness);

    expect(find.byType(QuickAddSheet), findsNothing);
    await tester.tap(find.text('Inbox'));
    await pumpApp(tester, harness);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    await harness.dispose(tester);
  });

  testWidgets('add another clears fields and keeps sheet open', (tester) async {
    final harness = await pumpTestApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('quick_add_title')), 'Bread');
    await tester.enterText(
      find.byKey(const Key('quick_add_description')),
      'sourdough',
    );
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('quick_add_another'), harness);

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('quick_add_title')))
          .controller!
          .text,
      isEmpty,
    );

    Navigator.of(tester.element(find.byType(QuickAddSheet))).pop();
    await pumpApp(tester, harness);
    await tester.tap(find.text('Inbox'));
    await pumpApp(tester, harness);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('sourdough'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('empty title shows inline error and keeps sheet open', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('quick_add_submit'), harness);

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.text('Enter a title'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('edit save updates row; dismiss without save keeps original', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    final repo = InboxRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 12),
      newId: () => 'edit-1',
    );
    await tester.runAsync(() => repo.add(title: 'Eggs', description: 'large'));
    await pumpApp(tester, harness);

    await tester.tap(find.text('Inbox'));
    await pumpApp(tester, harness);
    await tester.tap(find.text('Eggs'));
    await pumpApp(tester, harness);

    // Sheet is on the root navigator so the shell FAB cannot intercept CTAs.
    expect(find.byType(InboxEditSheet), findsOneWidget);
    expect(find.byType(FloatingActionButton).hitTestable(), findsNothing);

    await tester.enterText(
      find.byKey(const Key('inbox_edit_title')),
      'Eggs free-range',
    );
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('inbox_edit_save'), harness);
    expect(find.byType(InboxEditSheet), findsNothing);
    expect(find.text('Eggs free-range'), findsOneWidget);

    await tester.tap(find.text('Eggs free-range'));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('inbox_edit_title')), 'Nope');
    await pumpApp(tester, harness);
    Navigator.of(tester.element(find.byType(InboxEditSheet))).pop();
    await pumpApp(tester, harness);
    expect(find.text('Eggs free-range'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('remove shows snackbar; Undo restores the row', (tester) async {
    final harness = await pumpTestApp(tester);
    final repo = InboxRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 12),
      newId: () => 'rm-1',
    );
    await tester.runAsync(() => repo.add(title: 'Butter'));
    await pumpApp(tester, harness);

    await tester.tap(find.text('Inbox'));
    await pumpApp(tester, harness);
    expect(find.text('Butter'), findsOneWidget);

    await tester.tap(find.text('Butter'));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('inbox_edit_remove'), harness);

    expect(find.text('Butter'), findsNothing);
    expect(find.text('Removed Butter'), findsOneWidget);

    final snackBarAction = tester.widget<SnackBarAction>(
      find.byType(SnackBarAction),
    );
    await tester.runAsync(() async {
      snackBarAction.onPressed();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumpApp(tester, harness);
    expect(find.text('Butter'), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('removed row stays gone after snackbar ends', (tester) async {
    final harness = await pumpTestApp(tester);
    final repo = InboxRepository(
      database: harness.db,
      now: () => DateTime.utc(2026, 1, 1, 12),
      newId: () => 'gone-1',
    );
    await tester.runAsync(() => repo.add(title: 'Jam'));
    await pumpApp(tester, harness);

    await tester.tap(find.text('Inbox'));
    await pumpApp(tester, harness);
    await tester.tap(find.text('Jam'));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('inbox_edit_remove'), harness);
    expect(find.text('Jam'), findsNothing);

    rootScaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Jam'), findsNothing);
    expect(find.text('Removed Jam'), findsNothing);
    await harness.dispose(tester);
  });

  testWidgets('badge hides at zero and caps at 99+', (tester) async {
    final empty = await pumpTestApp(tester);
    expect(find.text('99+'), findsNothing);
    await empty.dispose(tester);

    final db = AppDatabase.memory();
    final many = List<InboxItem>.generate(
      100,
      (i) => InboxItem(
        id: 'badge-$i',
        title: 'Item $i',
        createdAt: DateTime.utc(2026, 1, 1, 12),
        updatedAt: DateTime.utc(2026, 1, 1, 12),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          inboxItemsProvider.overrideWith((ref) => Stream.value(many)),
        ],
        child: ZeroCartApp(),
      ),
    );
    await tester.pump();
    expect(find.text('99+'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(db.close);
  });

  testWidgets('FAB on Home and Stores opens Quick add', (tester) async {
    final router = AppRouter.create();
    final harness = await pumpTestApp(tester, router: router);

    await tester.tap(find.byType(FloatingActionButton));
    await pumpApp(tester, harness);
    expect(find.byType(QuickAddSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(QuickAddSheet))).pop();
    await pumpApp(tester, harness);

    await tester.tap(find.text('Stores'));
    await pumpApp(tester, harness);
    await tester.tap(find.byType(FloatingActionButton));
    await pumpApp(tester, harness);
    expect(find.byType(QuickAddSheet), findsOneWidget);
    await harness.dispose(tester);
  });
}
