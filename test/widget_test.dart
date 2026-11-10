import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/app.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/features/home/ui/home_screen.dart';

void main() {
  testWidgets('app shell builds on Home', (tester) async {
    await tester.pumpWidget(ZeroCartApp(router: AppRouter.create()));
    await tester.pumpAndSettle();
    expect(find.byType(ZeroCartApp), findsOneWidget);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
