import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/share_text.dart';

void main() {
  group('formatShareText', () {
    test('exact_format_list_name_newline_title_dash_description', () {
      final text = formatShareText('Weekend groceries', const [
        ShareableItem(
          title: 'Milk',
          description: '2L, lactose-free',
          isPurchased: false,
        ),
        ShareableItem(
          title: 'Pasta',
          description: 'Whole wheat, 500g',
          isPurchased: true,
        ),
        ShareableItem(title: 'Bread', isPurchased: false),
      ]);

      expect(text, 'Weekend groceries\nMilk - 2L, lactose-free\nBread');
      expect(text.endsWith('\n'), isFalse);
    });

    test('empty_description_uses_title_only', () {
      expect(
        formatShareText('List', const [
          ShareableItem(title: 'Bread', description: null, isPurchased: false),
          ShareableItem(title: 'Eggs', description: '', isPurchased: false),
        ]),
        'List\nBread\nEggs',
      );
    });

    test('no_unpurchased_items_returns_list_name_only', () {
      expect(
        formatShareText('Weekend groceries', const [
          ShareableItem(title: 'Pasta', isPurchased: true),
        ]),
        'Weekend groceries',
      );
      expect(formatShareText('Empty list', const []), 'Empty list');
    });

    test('special_characters_and_emoji_copied_verbatim', () {
      expect(
        formatShareText('Café 🛒', const [
          ShareableItem(
            title: 'Milch "Bio"',
            description: '2L — lactose-free 😊',
            isPurchased: false,
          ),
        ]),
        'Café 🛒\nMilch "Bio" - 2L — lactose-free 😊',
      );
    });
  });
}
