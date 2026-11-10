import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/limits.dart';
import 'package:zero_cart/core/text_normalize.dart';

void main() {
  group('normalizeText', () {
    test('trims leading and trailing whitespace', () {
      expect(normalizeText('  Milk  ', maxItemTitleLength), 'Milk');
    });

    test('turns newlines into spaces', () {
      expect(
        normalizeText('Milk\n2L\r\nlactose', maxItemTitleLength),
        'Milk 2L lactose',
      );
    });

    test('clamps to maxLength', () {
      final long = 'a' * (maxItemTitleLength + 5);
      expect(normalizeText(long, maxItemTitleLength), 'a' * maxItemTitleLength);
    });
  });

  group('normalizeDescription', () {
    test('returns null for null input', () {
      expect(normalizeDescription(null), isNull);
    });

    test('returns null for empty or whitespace-only', () {
      expect(normalizeDescription(''), isNull);
      expect(normalizeDescription('   '), isNull);
      expect(normalizeDescription('\n\t'), isNull);
    });

    test('normalizes and keeps non-empty description', () {
      expect(normalizeDescription('  2L,\nlactose-free  '), '2L, lactose-free');
    });

    test('clamps to description limit', () {
      final long = 'b' * (maxItemDescriptionLength + 3);
      expect(normalizeDescription(long), 'b' * maxItemDescriptionLength);
    });
  });

  test('normalizeTitle uses title limit', () {
    final long = 't' * (maxItemTitleLength + 1);
    expect(normalizeTitle(long).length, maxItemTitleLength);
  });

  test('normalizeListName uses list name limit', () {
    final long = 'l' * (maxListNameLength + 1);
    expect(normalizeListName(long).length, maxListNameLength);
  });

  test('normalizeStoreName uses store name limit', () {
    final long = 's' * (maxStoreNameLength + 1);
    expect(normalizeStoreName(long).length, maxStoreNameLength);
  });
}
