import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/main.dart';

void main() {
  testWidgets('empty app builds', (tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.byType(MainApp), findsOneWidget);
  });
}
