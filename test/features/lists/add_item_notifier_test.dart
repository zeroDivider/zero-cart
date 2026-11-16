import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/features/lists/add_item_notifier.dart';

void main() {
  group('AddItemNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initial state has no pending scroll id', () {
      expect(container.read(addItemNotifierProvider('list-1')), isNull);
    });

    test('setPendingScroll and clearPendingScroll', () {
      final notifier = container.read(
        addItemNotifierProvider('list-1').notifier,
      );
      notifier.setPendingScroll('item-1');
      expect(container.read(addItemNotifierProvider('list-1')), 'item-1');
      notifier.clearPendingScroll();
      expect(container.read(addItemNotifierProvider('list-1')), isNull);
    });
  });
}
