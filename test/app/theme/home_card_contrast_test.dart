import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';

/// WCAG relative luminance for an opaque sRGB [Color].
double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// Contrast ratio of [foreground] on [background] (WCAG 2.x).
double contrastRatio(Color foreground, Color background) {
  final l1 = _relativeLuminance(foreground);
  final l2 = _relativeLuminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final entry in [
    ('light', AppTheme.lightColorScheme, AppTokens.light),
    ('dark', AppTheme.darkColorScheme, AppTokens.dark),
  ]) {
    final themeName = entry.$1;
    final scheme = entry.$2;
    final tokens = entry.$3;

    test(
      'Home card fills keep onSurface readable in $themeName ($themeName)',
      () {
        final failures = <String>[];
        for (final key in AppTokens.storePaletteKeys) {
          final fill = tokens.homeCardFill(key, scheme.surface);
          final body = contrastRatio(scheme.onSurface, fill);
          final secondary = contrastRatio(scheme.onSurfaceVariant, fill);
          // Body / label text on the card (not large title numerals).
          if (body < 4.5) {
            failures.add('$key onSurface ratio ${body.toStringAsFixed(2)}');
          }
          if (secondary < 4.5) {
            failures.add(
              '$key onSurfaceVariant ratio ${secondary.toStringAsFixed(2)}',
            );
          }
        }
        expect(failures, isEmpty, reason: failures.join('; '));
      },
    );
  }
}
