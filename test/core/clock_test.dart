import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/core/clock.dart';

void main() {
  test('systemClock returns a UTC DateTime', () {
    final now = systemClock();
    expect(now.isUtc, isTrue);
  });

  test('Clock typedef accepts a fixed instant for tests', () {
    final fixed = DateTime.utc(2026, 11, 10, 12);
    Clock clock = () => fixed;
    expect(clock(), fixed);
  });
}
