import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/form_submit_state.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/inbox/inbox_edit_notifier.dart';
import 'package:zero_cart/features/inbox/inbox_providers.dart';
import 'package:zero_cart/features/inbox/quick_add_notifier.dart';
import 'package:zero_cart/features/lists/add_item_notifier.dart';
import 'package:zero_cart/features/lists/item_edit_notifier.dart';
import 'package:zero_cart/features/lists/lists_providers.dart';
import 'package:zero_cart/features/stores/store_draft.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';

ProviderContainer makeContainer(AppDatabase db) {
  var counter = 0;
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      nowProvider.overrideWithValue(() => DateTime.utc(2026, 1, 1, 12)),
      idGeneratorProvider.overrideWithValue(() => 'id-${++counter}'),
    ],
  );
}

void main() {
  group('QuickAddNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = AppDatabase.memory();
      container = makeContainer(db);
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('initial state is idle', () {
      expect(container.read(quickAddNotifierProvider).submitting, isFalse);
      expect(container.read(quickAddNotifierProvider).error, isNull);
    });

    test('submit transitions to submitting then idle on success', () async {
      final states = <FormSubmitState>[];
      container.listen(quickAddNotifierProvider, (_, s) => states.add(s));

      final ok = await container
          .read(quickAddNotifierProvider.notifier)
          .submit(title: 'Milk', description: '', errorMessage: 'Failed');

      expect(ok, isTrue);
      expect(states.first.submitting, isTrue);
      expect(states.last.submitting, isFalse);
      expect(states.last.error, isNull);
    });

    test('submit sets error when title is blank (DB constraint)', () async {
      final sub = container.listen(quickAddNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      final ok = await container
          .read(quickAddNotifierProvider.notifier)
          .submit(title: '   ', description: '', errorMessage: 'boom');

      expect(ok, isFalse);
      expect(container.read(quickAddNotifierProvider).error, 'boom');
    });

    test('double submit while submitting is ignored', () async {
      final sub = container.listen(quickAddNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      final notifier = container.read(quickAddNotifierProvider.notifier);
      final first = notifier.submit(
        title: 'Milk',
        description: '',
        errorMessage: '',
      );
      final ok = await notifier.submit(
        title: 'x',
        description: '',
        errorMessage: '',
      );
      expect(ok, isFalse);
      await first;
    });

    test('clearError resets the error', () async {
      final sub = container.listen(quickAddNotifierProvider, (_, _) {});
      addTearDown(sub.close);
      await container
          .read(quickAddNotifierProvider.notifier)
          .submit(title: '   ', description: '', errorMessage: 'boom');
      expect(container.read(quickAddNotifierProvider).error, isNotNull);

      container.read(quickAddNotifierProvider.notifier).clearError();
      expect(container.read(quickAddNotifierProvider).error, isNull);
    });
  });

  group('InboxEditNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;
    late InboxItem item;

    setUp(() async {
      db = AppDatabase.memory();
      container = makeContainer(db);
      item = await container.read(inboxRepositoryProvider).add(title: 'Old');
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('initial state is idle', () {
      final s = container.read(inboxEditNotifierProvider(item.id));
      expect(s.submitting, isFalse);
      expect(s.error, isNull);
    });

    test('save returns true and state is idle on success', () async {
      final ok = await container
          .read(inboxEditNotifierProvider(item.id).notifier)
          .save(title: 'New', description: '', errorMessage: 'err');
      expect(ok, isTrue);
      expect(container.read(inboxEditNotifierProvider(item.id)).error, isNull);
    });

    test('save sets error when DB is closed', () async {
      await db.close();
      final ok = await container
          .read(inboxEditNotifierProvider(item.id).notifier)
          .save(title: 'New', description: '', errorMessage: 'boom');
      expect(ok, isFalse);
      expect(container.read(inboxEditNotifierProvider(item.id)).error, 'boom');
    });
  });

  group('ItemEditNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;
    late ListItem item;

    setUp(() async {
      db = AppDatabase.memory();
      container = makeContainer(db);
      final store = await container
          .read(storesRepositoryProvider)
          .createFromDraft(
            const StoreDraft(name: 'S', colorKey: 'sky', address: '', note: ''),
          );
      final list = await container
          .read(listsRepositoryProvider)
          .create(storeId: store.id, name: 'L');
      item = await container
          .read(listsRepositoryProvider)
          .addItem(listId: list.id, title: 'Old item');
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('initial state is idle', () {
      expect(
        container.read(itemEditNotifierProvider(item.id)).submitting,
        isFalse,
      );
    });

    test('save returns true on success', () async {
      final ok = await container
          .read(itemEditNotifierProvider(item.id).notifier)
          .save(title: 'New title', description: '', errorMessage: 'err');
      expect(ok, isTrue);
    });

    test('save sets error when DB is closed', () async {
      await db.close();
      final ok = await container
          .read(itemEditNotifierProvider(item.id).notifier)
          .save(title: 'x', description: '', errorMessage: 'boom');
      expect(ok, isFalse);
      expect(container.read(itemEditNotifierProvider(item.id)).error, 'boom');
    });
  });

  group('AddItemNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;
    late String listId;

    setUp(() async {
      db = AppDatabase.memory();
      container = makeContainer(db);
      final store = await container
          .read(storesRepositoryProvider)
          .createFromDraft(
            const StoreDraft(name: 'S', colorKey: 'sky', address: '', note: ''),
          );
      final list = await container
          .read(listsRepositoryProvider)
          .create(storeId: store.id, name: 'L');
      listId = list.id;
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('initial state is idle with no pendingScrollId', () {
      final s = container.read(addItemNotifierProvider(listId));
      expect(s.submitting, isFalse);
      expect(s.pendingScrollId, isNull);
    });

    test('addItem sets pendingScrollId on success', () async {
      await container
          .read(addItemNotifierProvider(listId).notifier)
          .addItem(title: 'Milk', errorMessage: 'err');

      final s = container.read(addItemNotifierProvider(listId));
      expect(s.pendingScrollId, isNotNull);
      expect(s.error, isNull);
    });

    test('clearPendingScroll resets state', () async {
      await container
          .read(addItemNotifierProvider(listId).notifier)
          .addItem(title: 'Milk', errorMessage: 'err');
      container
          .read(addItemNotifierProvider(listId).notifier)
          .clearPendingScroll();
      expect(
        container.read(addItemNotifierProvider(listId)).pendingScrollId,
        isNull,
      );
    });

    test('addItem sets error when DB is closed', () async {
      await db.close();
      await container
          .read(addItemNotifierProvider(listId).notifier)
          .addItem(title: 'Milk', errorMessage: 'boom');
      expect(container.read(addItemNotifierProvider(listId)).error, 'boom');
    });
  });
}
