import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/root_scaffold_messenger.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';
import 'package:zero_cart/features/inbox/ui/sheets/inbox_edit_sheet.dart';
import 'package:zero_cart/features/inbox/ui/sheets/quick_add_sheet.dart';

import '../../support/test_app.dart';

const _genericError = 'Something went wrong. Try again.';

class _ThrowingInboxRepository extends InboxRepository {
  _ThrowingInboxRepository({
    required super.database,
    required super.now,
    required super.newId,
    this.throwOnAdd = false,
    this.throwOnUpdate = false,
    this.throwOnRemove = false,
    this.throwOnRestore = false,
  });

  final bool throwOnAdd;
  final bool throwOnUpdate;
  final bool throwOnRemove;
  final bool throwOnRestore;

  @override
  Future<InboxItem> add({required String title, String? description}) {
    if (throwOnAdd) {
      throw Exception('add failed');
    }
    return super.add(title: title, description: description);
  }

  @override
  Future<InboxItem> update({
    required String id,
    required String title,
    String? description,
  }) {
    if (throwOnUpdate) {
      throw Exception('update failed');
    }
    return super.update(id: id, title: title, description: description);
  }

  @override
  Future<InboxItem> remove(String id) {
    if (throwOnRemove) {
      throw Exception('remove failed');
    }
    return super.remove(id);
  }

  @override
  Future<void> restore(InboxItem snapshot) async {
    if (throwOnRestore) {
      throw Exception('restore failed');
    }
    await super.restore(snapshot);
  }
}

List<Override> _throwingInboxOverrides({
  bool throwOnAdd = false,
  bool throwOnUpdate = false,
  bool throwOnRemove = false,
  bool throwOnRestore = false,
}) {
  return [
    inboxRepositoryProvider.overrideWith((ref) {
      return _ThrowingInboxRepository(
        database: ref.watch(appDatabaseProvider),
        now: ref.watch(nowProvider),
        newId: ref.watch(idGeneratorProvider),
        throwOnAdd: throwOnAdd,
        throwOnUpdate: throwOnUpdate,
        throwOnRemove: throwOnRemove,
        throwOnRestore: throwOnRestore,
      );
    }),
  ];
}

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
  await tester.pump(const Duration(milliseconds: 300));
  await pumpApp(tester, harness);
}

Future<InboxItem> _seedInboxItem(TestAppHarness harness) {
  return InboxRepository(
    database: harness.db,
    now: () => DateTime.utc(2026, 1, 1, 12),
    newId: () => 'inbox-1',
  ).add(title: 'Milk', description: '2L');
}

void main() {
  testWidgets('quick add failure keeps sheet open with inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      overrides: _throwingInboxOverrides(throwOnAdd: true),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('quick_add_title')), 'Milk');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('quick_add_submit'), harness);

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('quick_add_title')))
          .controller!
          .text,
      'Milk',
    );

    final rows = await tester.runAsync(
      () => harness.db.select(harness.db.inboxItems).get(),
    );
    expect(rows, isEmpty);
    await harness.dispose(tester);
  });

  testWidgets('quick add another failure keeps input and shows inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      overrides: _throwingInboxOverrides(throwOnAdd: true),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('quick_add_title')), 'Bread');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('quick_add_another'), harness);

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('quick_add_title')))
          .controller!
          .text,
      'Bread',
    );
    await harness.dispose(tester);
  });

  testWidgets('inbox edit save failure keeps sheet open with inline error', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.inbox),
      overrides: _throwingInboxOverrides(throwOnUpdate: true),
    );
    await tester.runAsync(() => _seedInboxItem(harness));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('inbox_row_inbox-1')));
    await pumpApp(tester, harness);
    await tester.enterText(find.byKey(const Key('inbox_edit_title')), 'Eggs');
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('inbox_edit_save'), harness);

    expect(find.byType(InboxEditSheet), findsOneWidget);
    expect(find.text(_genericError), findsOneWidget);

    final row = await tester.runAsync(
      () => harness.db.select(harness.db.inboxItems).getSingle(),
    );
    expect(row!.title, 'Milk');
    await harness.dispose(tester);
  });

  testWidgets('inbox remove failure shows error snackbar', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.inbox),
      overrides: _throwingInboxOverrides(throwOnRemove: true),
    );
    await tester.runAsync(() => _seedInboxItem(harness));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('inbox_row_inbox-1')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('inbox_edit_remove'), harness);

    expect(find.text(_genericError), findsOneWidget);
    expect(find.textContaining('Removed'), findsNothing);

    final rows = await tester.runAsync(
      () => harness.db.select(harness.db.inboxItems).get(),
    );
    expect(rows, hasLength(1));
    await harness.dispose(tester);
  });

  testWidgets('inbox failed Undo shows messageFor immediately', (tester) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.inbox),
      overrides: _throwingInboxOverrides(throwOnRestore: true),
    );
    await tester.runAsync(() => _seedInboxItem(harness));
    await pumpApp(tester, harness);

    await tester.tap(find.byKey(const Key('inbox_row_inbox-1')));
    await pumpApp(tester, harness);
    await _tapButton(tester, const Key('inbox_edit_remove'), harness);
    expect(find.text('Removed Milk'), findsOneWidget);

    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    action.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('Removed Milk'), findsNothing);
    expect(find.text(_genericError), findsOneWidget);
    // throwOnRestore: remove succeeded; item stays gone.
    final rows = await tester.runAsync(
      () => harness.db.select(harness.db.inboxItems).get(),
    );
    expect(rows, isEmpty);
    // Clear messenger for dispose.
    rootScaffoldMessengerKey.currentState?.clearSnackBars();
    await harness.dispose(tester);
  });
}
