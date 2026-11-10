import 'package:flutter/material.dart';

/// Typography from design system 3.2.
///
/// Material [TextTheme] slots plus [wordmark] and [storeCount], which are not
/// Material roles and are applied by callers (Home app bar / store cards).
abstract final class AppText {
  static const String roboto = 'Roboto';
  static const String dynaPuff = 'DynaPuff';

  /// DynaPuff Bold 28/32 — Home wordmark.
  static TextStyle wordmark({Color? color}) {
    return TextStyle(
      fontFamily: dynaPuff,
      fontWeight: FontWeight.w700,
      fontSize: 28,
      height: 32 / 28,
      color: color,
    );
  }

  /// Roboto Bold 52/52 — items-left number on Home store cards.
  static TextStyle storeCount({Color? color}) {
    return TextStyle(
      fontFamily: roboto,
      fontWeight: FontWeight.w700,
      fontSize: 52,
      height: 1,
      color: color,
    );
  }

  /// Material [TextTheme] for the app (Roboto).
  static TextTheme textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(
        fontFamily: roboto,
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 30 / 24,
      ),
      headlineSmall: TextStyle(
        fontFamily: roboto,
        fontWeight: FontWeight.w500,
        fontSize: 24,
        height: 32 / 24,
      ),
      titleLarge: TextStyle(
        fontFamily: roboto,
        fontWeight: FontWeight.w500,
        fontSize: 20,
        height: 28 / 20,
      ),
      titleMedium: TextStyle(
        fontFamily: roboto,
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 24 / 16,
      ),
      bodyLarge: TextStyle(
        fontFamily: roboto,
        fontWeight: FontWeight.w500,
        fontSize: 16,
        height: 24 / 16,
      ),
      bodyMedium: TextStyle(
        fontFamily: roboto,
        fontWeight: FontWeight.w400,
        fontSize: 14,
        height: 20 / 14,
      ),
      labelLarge: TextStyle(
        fontFamily: roboto,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        height: 20 / 14,
      ),
      labelMedium: TextStyle(
        fontFamily: roboto,
        fontWeight: FontWeight.w500,
        fontSize: 12,
        height: 16 / 12,
      ),
    );
  }
}
