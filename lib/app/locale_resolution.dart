import 'package:flutter/material.dart';

/// Supported app locales: English (default) and Serbian Latin (NF-2).
const Locale appEnglishLocale = Locale('en');
const Locale appSerbianLatinLocale = Locale.fromSubtags(
  languageCode: 'sr',
  scriptCode: 'Latn',
);

const List<Locale> appSupportedLocales = <Locale>[
  appEnglishLocale,
  appSerbianLatinLocale,
];

/// Maps any Serbian device locale to Latin script; everything else to English.
///
/// Used as [MaterialApp.localeResolutionCallback].
Locale resolveAppLocale(Locale? locale, Iterable<Locale> supportedLocales) {
  if (locale != null && locale.languageCode == 'sr') {
    return appSerbianLatinLocale;
  }
  return appEnglishLocale;
}
