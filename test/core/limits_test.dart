import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/limits.dart';

void main() {
  test('exposes D-08 character limits', () {
    expect(maxStoreNameLength, 40);
    expect(maxListNameLength, 60);
    expect(maxItemTitleLength, 50);
    expect(maxItemDescriptionLength, 70);
  });
}
