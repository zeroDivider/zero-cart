import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/ids.dart';

void main() {
  test('generateUuidV4 returns distinct UUID v4 strings', () {
    final a = generateUuidV4();
    final b = generateUuidV4();
    final pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    expect(a, matches(pattern));
    expect(b, matches(pattern));
    expect(a, isNot(b));
  });
}
