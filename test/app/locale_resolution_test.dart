import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/locale_resolution.dart';

void main() {
  group('resolveAppLocale', () {
    test('maps sr to Serbian Latin', () {
      expect(
        resolveAppLocale(const Locale('sr'), appSupportedLocales),
        appSerbianLatinLocale,
      );
    });

    test('maps sr-RS to Serbian Latin', () {
      expect(
        resolveAppLocale(const Locale('sr', 'RS'), appSupportedLocales),
        appSerbianLatinLocale,
      );
    });

    test('maps sr-Latn-RS to Serbian Latin', () {
      expect(
        resolveAppLocale(
          const Locale.fromSubtags(
            languageCode: 'sr',
            scriptCode: 'Latn',
            countryCode: 'RS',
          ),
          appSupportedLocales,
        ),
        appSerbianLatinLocale,
      );
    });

    test('maps sr-Cyrl to Serbian Latin', () {
      expect(
        resolveAppLocale(
          const Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Cyrl'),
          appSupportedLocales,
        ),
        appSerbianLatinLocale,
      );
    });

    test('maps de to English', () {
      expect(
        resolveAppLocale(const Locale('de'), appSupportedLocales),
        appEnglishLocale,
      );
    });

    test('maps null to English', () {
      expect(resolveAppLocale(null, appSupportedLocales), appEnglishLocale);
    });
  });
}
