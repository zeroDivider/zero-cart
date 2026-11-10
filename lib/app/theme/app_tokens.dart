import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Non-ColorScheme design tokens: spacing, radii, store palette, success.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.spacing4,
    required this.spacing8,
    required this.spacing12,
    required this.spacing16,
    required this.spacing24,
    required this.spacing32,
    required this.spacing48,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusCheckbox,
    required this.radiusPill,
    required this.storePalette,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
  });

  /// Spacing scale from design system 3.3 (base unit 4).
  final double spacing4;
  final double spacing8;
  final double spacing12;
  final double spacing16;
  final double spacing24;
  final double spacing32;
  final double spacing48;

  /// Corner radii from design system 3.4.
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusCheckbox;
  final double radiusPill;

  /// Decorative store colours; same hexes in light and dark.
  final Map<String, Color> storePalette;

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  static const List<String> storePaletteKeys = <String>[
    'tomato',
    'tangerine',
    'lemon',
    'lime',
    'teal',
    'sky',
    'grape',
    'bubblegum',
  ];

  /// Shared store palette (identical in both themes).
  static const Map<String, Color> storePaletteColors = <String, Color>{
    'tomato': Color(0xFFE5604F),
    'tangerine': Color(0xFFF2994A),
    'lemon': Color(0xFFD9A400),
    'lime': Color(0xFF7DB84A),
    'teal': Color(0xFF2BA6A0),
    'sky': Color(0xFF4A9BE0),
    'grape': Color(0xFF8E6CCB),
    'bubblegum': Color(0xFFE96FA6),
  };

  static const AppTokens light = AppTokens(
    spacing4: 4,
    spacing8: 8,
    spacing12: 12,
    spacing16: 16,
    spacing24: 24,
    spacing32: 32,
    spacing48: 48,
    radiusSm: 8,
    radiusMd: 16,
    radiusLg: 24,
    radiusXl: 28,
    radiusCheckbox: 6,
    radiusPill: 999,
    storePalette: storePaletteColors,
    success: Color(0xFFA5D5B6),
    onSuccess: Color(0xFF123B24),
    successContainer: Color(0xFFD9EEE0),
    onSuccessContainer: Color(0xFF123B24),
  );

  static const AppTokens dark = AppTokens(
    spacing4: 4,
    spacing8: 8,
    spacing12: 12,
    spacing16: 16,
    spacing24: 24,
    spacing32: 32,
    spacing48: 48,
    radiusSm: 8,
    radiusMd: 16,
    radiusLg: 24,
    radiusXl: 28,
    radiusCheckbox: 6,
    radiusPill: 999,
    storePalette: storePaletteColors,
    success: Color(0xFFA5D5B6),
    onSuccess: Color(0xFF123B24),
    successContainer: Color(0xFF1F4A33),
    onSuccessContainer: Color(0xFFD9EEE0),
  );

  Color storeColor(String key) {
    final color = storePalette[key];
    assert(color != null, 'Unknown store palette key: $key');
    return color!;
  }

  @override
  AppTokens copyWith({
    double? spacing4,
    double? spacing8,
    double? spacing12,
    double? spacing16,
    double? spacing24,
    double? spacing32,
    double? spacing48,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusCheckbox,
    double? radiusPill,
    Map<String, Color>? storePalette,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
  }) {
    return AppTokens(
      spacing4: spacing4 ?? this.spacing4,
      spacing8: spacing8 ?? this.spacing8,
      spacing12: spacing12 ?? this.spacing12,
      spacing16: spacing16 ?? this.spacing16,
      spacing24: spacing24 ?? this.spacing24,
      spacing32: spacing32 ?? this.spacing32,
      spacing48: spacing48 ?? this.spacing48,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusCheckbox: radiusCheckbox ?? this.radiusCheckbox,
      radiusPill: radiusPill ?? this.radiusPill,
      storePalette: storePalette ?? this.storePalette,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) {
      return this;
    }
    return AppTokens(
      spacing4: lerpDouble(spacing4, other.spacing4, t)!,
      spacing8: lerpDouble(spacing8, other.spacing8, t)!,
      spacing12: lerpDouble(spacing12, other.spacing12, t)!,
      spacing16: lerpDouble(spacing16, other.spacing16, t)!,
      spacing24: lerpDouble(spacing24, other.spacing24, t)!,
      spacing32: lerpDouble(spacing32, other.spacing32, t)!,
      spacing48: lerpDouble(spacing48, other.spacing48, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t)!,
      radiusCheckbox: lerpDouble(radiusCheckbox, other.radiusCheckbox, t)!,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t)!,
      storePalette: <String, Color>{
        for (final key in storePaletteKeys)
          key: Color.lerp(storePalette[key], other.storePalette[key], t)!,
      },
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
    );
  }
}
