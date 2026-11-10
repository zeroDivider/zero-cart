import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/font_licences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LicenseRegistry includes Roboto and DynaPuff', () async {
    registerBundledFontLicences();

    final packages = <String>{};
    await for (final entry in LicenseRegistry.licenses) {
      packages.addAll(entry.packages);
    }

    expect(packages, containsAll(<String>['Roboto', 'DynaPuff']));
  });
}
