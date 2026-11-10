import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/app.dart';
import 'package:zero_cart/features/home/ui/home_screen.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('app shell builds on Home', (tester) async {
    await pumpTestApp(tester);
    expect(find.byType(ZeroCartApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
