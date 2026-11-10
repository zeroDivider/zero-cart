import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/font_licences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('licence page lists Roboto and DynaPuff', (tester) async {
    registerBundledFontLicences();

    await tester.pumpWidget(
      const MaterialApp(home: LicensePage(applicationName: 'ZeroCart')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Roboto'), findsOneWidget);
    expect(find.text('DynaPuff'), findsOneWidget);
  });
}
