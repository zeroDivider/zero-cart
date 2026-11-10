import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/ordering.dart';

void main() {
  group('computeDenseReorder', () {
    test(
      'purchased_in_middle_keeps_purchased_slot_and_returns_only_changes',
      () {
        final all = [
          const OrderableItem(id: 'A', position: 1, isPurchased: false),
          const OrderableItem(id: 'B', position: 2, isPurchased: true),
          const OrderableItem(id: 'C', position: 3, isPurchased: false),
        ];

        final changes = computeDenseReorder(all, ['C', 'A']);

        expect(changes, {'C': 1, 'A': 3});
        expect(changes.containsKey('B'), isFalse);
      },
    );

    test('ties_use_input_order_as_slots_and_renumber_densely', () {
      // Same position on every row; caller already ordered by created_at, id.
      final all = [
        const OrderableItem(id: 'A', position: 5, isPurchased: false),
        const OrderableItem(id: 'B', position: 5, isPurchased: false),
        const OrderableItem(id: 'C', position: 5, isPurchased: true),
      ];

      final changes = computeDenseReorder(all, ['B', 'A']);

      // Active slots filled as B then A; purchased C keeps index 2.
      expect(changes, {'B': 1, 'A': 2, 'C': 3});
    });

    test('single_active_item_with_correct_position_returns_empty', () {
      final all = [
        const OrderableItem(id: 'A', position: 1, isPurchased: false),
      ];

      expect(computeDenseReorder(all, ['A']), isEmpty);
    });

    test('no_change_when_active_order_already_matches', () {
      final all = [
        const OrderableItem(id: 'A', position: 1, isPurchased: false),
        const OrderableItem(id: 'B', position: 2, isPurchased: true),
        const OrderableItem(id: 'C', position: 3, isPurchased: false),
      ];

      expect(computeDenseReorder(all, ['A', 'C']), isEmpty);
    });

    test('stale_missing_id_throws', () {
      final all = [
        const OrderableItem(id: 'A', position: 1, isPurchased: false),
        const OrderableItem(id: 'B', position: 2, isPurchased: false),
      ];

      expect(
        () => computeDenseReorder(all, ['A']),
        throwsA(isA<StaleOrderException>()),
      );
    });

    test('stale_extra_id_throws', () {
      final all = [
        const OrderableItem(id: 'A', position: 1, isPurchased: false),
      ];

      expect(
        () => computeDenseReorder(all, ['A', 'X']),
        throwsA(isA<StaleOrderException>()),
      );
    });

    test('stale_duplicate_ids_throws', () {
      final all = [
        const OrderableItem(id: 'A', position: 1, isPurchased: false),
        const OrderableItem(id: 'B', position: 2, isPurchased: false),
      ];

      expect(
        () => computeDenseReorder(all, ['A', 'A']),
        throwsA(isA<StaleOrderException>()),
      );
    });

    test('multiple_purchased_keep_relative_order_after_active_shuffle', () {
      final all = [
        const OrderableItem(id: 'A', position: 1, isPurchased: false),
        const OrderableItem(id: 'P1', position: 2, isPurchased: true),
        const OrderableItem(id: 'B', position: 3, isPurchased: false),
        const OrderableItem(id: 'P2', position: 4, isPurchased: true),
        const OrderableItem(id: 'C', position: 5, isPurchased: false),
      ];

      final changes = computeDenseReorder(all, ['C', 'A', 'B']);

      // New sequence: C, P1, A, P2, B → positions 1..5
      expect(changes, {'C': 1, 'A': 3, 'B': 5});
      expect(changes.containsKey('P1'), isFalse);
      expect(changes.containsKey('P2'), isFalse);
    });
  });
}
