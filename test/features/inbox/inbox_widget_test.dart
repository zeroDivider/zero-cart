import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';
import 'package:zero_cart/features/inbox/ui/quick_add_sheet.dart';

import '../../support/test_app.dart';

void main() {
  testWidgets('quick add inserts item, closes sheet, and updates badge', (
    tester,
  ) async {
    await pumpTestApp(tester);

    expect(find.text('Inbox is empty'), findsNothing);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsOneWidget);

    await tester.enterText(find.byKey(const Key('quick_add_title')), 'Milk');
    await tester.tap(find.byKey(const Key('quick_add_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsNothing);
    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('add another clears fields and keeps sheet open', (tester) async {
    await pumpTestApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('quick_add_title')), 'Bread');
    await tester.enterText(
      find.byKey(const Key('quick_add_description')),
      'sourdough',
    );
    await tester.tap(find.byKey(const Key('quick_add_another')));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.byKey(const Key('quick_add_title')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('quick_add_title')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('quick_add_description')))
          .controller!
          .text,
      isEmpty,
    );

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('sourdough'), findsOneWidget);
  });

  testWidgets('empty title shows inline error and keeps sheet open', (
    tester,
  ) async {
    await pumpTestApp(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_add_submit')));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.text('Enter a title'), findsOneWidget);
  });

  testWidgets('edit save updates row; dismiss without save keeps original', (
    tester,
  ) async {
    final db = await pumpTestApp(tester);
    final repo = InboxRepository(
      db: db,
      clock: () => DateTime.utc(2026, 1, 1, 12),
      idGenerator: () => 'edit-1',
    );
    await repo.add(title: 'Eggs', description: 'large');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inbox_row_edit-1')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('inbox_edit_title')),
      'Eggs free-range',
    );
    await tester.tap(find.byKey(const Key('inbox_edit_save')));
    await tester.pumpAndSettle();
    expect(find.text('Eggs free-range'), findsOneWidget);

    await tester.tap(find.byKey(const Key('inbox_row_edit-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('inbox_edit_title')), 'Nope');
    await tester.tap(find.byIcon(Icons.close).first);
    // Drag handle sheet: dismiss by tapping barrier.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Nope'), findsNothing);
    expect(find.text('Eggs free-range'), findsOneWidget);
  });

  testWidgets('swipe remove shows snackbar; Undo restores the row', (
    tester,
  ) async {
    final db = await pumpTestApp(tester);
    final repo = InboxRepository(
      db: db,
      clock: () => DateTime.utc(2026, 1, 1, 12),
      idGenerator: () => 'rm-1',
    );
    await repo.add(title: 'Butter');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    expect(find.text('Butter'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('inbox_row_rm-1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Butter'), findsNothing);
    expect(find.text('Removed Butter'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Butter'), findsOneWidget);
  });

  testWidgets('removed row stays gone after snackbar ends', (tester) async {
    final db = await pumpTestApp(tester);
    final repo = InboxRepository(
      db: db,
      clock: () => DateTime.utc(2026, 1, 1, 12),
      idGenerator: () => 'gone-1',
    );
    await repo.add(title: 'Jam');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inbox'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('inbox_row_gone-1')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jam'), findsNothing);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Jam'), findsNothing);
    expect(find.text('Removed Jam'), findsNothing);
  });

  testWidgets('badge hides at zero and caps at 99+', (tester) async {
    final db = await pumpTestApp(tester);
    var n = 0;
    final repo = InboxRepository(
      db: db,
      clock: () => DateTime.utc(2026, 1, 1, 12),
      idGenerator: () {
        n += 1;
        return 'badge-$n';
      },
    );

    expect(find.text('99+'), findsNothing);

    for (var i = 0; i < 100; i++) {
      await repo.add(title: 'Item $i');
    }
    await tester.pumpAndSettle();
    expect(find.text('99+'), findsWidgets);
  });

  testWidgets('FAB on Home and Stores opens Quick add', (tester) async {
    final router = AppRouter.create();
    await pumpTestApp(tester, router: router);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stores'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsOneWidget);
  });
}
