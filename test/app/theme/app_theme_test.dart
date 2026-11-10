import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/theme/app_text.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';

void main() {
  group('ColorScheme matches design system 3.1', () {
    test('light ColorScheme uses exact hex values', () {
      const scheme = AppTheme.lightColorScheme;
      expect(scheme.brightness, Brightness.light);
      expect(scheme.surface, const Color(0xFFFFFDF5));
      expect(scheme.surfaceContainerLowest, const Color(0xFFFFFFFF));
      expect(scheme.surfaceContainerLow, const Color(0xFFF7F9FE));
      expect(scheme.surfaceContainer, const Color(0xFFF0F4FC));
      expect(scheme.surfaceContainerHigh, const Color(0xFFE6ECF8));
      expect(scheme.onSurface, const Color(0xFF1E2230));
      expect(scheme.onSurfaceVariant, const Color(0xFF4D5368));
      expect(scheme.outline, const Color(0xFF7B8094));
      expect(scheme.outlineVariant, const Color(0xFFD8DFEE));
      expect(scheme.primary, const Color(0xFF334E8C));
      expect(scheme.onPrimary, const Color(0xFFFFFFFF));
      expect(scheme.primaryContainer, const Color(0xFFDDE6FC));
      expect(scheme.onPrimaryContainer, const Color(0xFF14264F));
      expect(scheme.secondary, const Color(0xFFA5BDF4));
      expect(scheme.onSecondary, const Color(0xFF1B2C55));
      expect(scheme.secondaryContainer, const Color(0xFFC9D8F9));
      expect(scheme.onSecondaryContainer, const Color(0xFF1B2C55));
      expect(scheme.tertiary, const Color(0xFFF67583));
      expect(scheme.onTertiary, const Color(0xFF3A0910));
      expect(scheme.tertiaryContainer, const Color(0xFFFFD9DD));
      expect(scheme.onTertiaryContainer, const Color(0xFF5A1420));
      expect(scheme.error, const Color(0xFFB3261E));
      expect(scheme.onError, const Color(0xFFFFFFFF));
      expect(scheme.errorContainer, const Color(0xFFF9DEDC));
      expect(scheme.onErrorContainer, const Color(0xFF410E0B));
    });

    test('dark ColorScheme uses exact hex values', () {
      const scheme = AppTheme.darkColorScheme;
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.surface, const Color(0xFF14171F));
      expect(scheme.surfaceContainerLowest, const Color(0xFF0F1218));
      expect(scheme.surfaceContainerLow, const Color(0xFF191D26));
      expect(scheme.surfaceContainer, const Color(0xFF1D212C));
      expect(scheme.surfaceContainerHigh, const Color(0xFF262B38));
      expect(scheme.onSurface, const Color(0xFFE8E9F0));
      expect(scheme.onSurfaceVariant, const Color(0xFFB4B8C8));
      expect(scheme.outline, const Color(0xFF8A8FA3));
      expect(scheme.outlineVariant, const Color(0xFF3A3F4E));
      expect(scheme.primary, const Color(0xFFA5BDF4));
      expect(scheme.onPrimary, const Color(0xFF14264F));
      expect(scheme.primaryContainer, const Color(0xFF334E8C));
      expect(scheme.onPrimaryContainer, const Color(0xFFDDE6FC));
      expect(scheme.secondary, const Color(0xFFB9C6E8));
      expect(scheme.onSecondary, const Color(0xFF1B2C55));
      expect(scheme.secondaryContainer, const Color(0xFF3A4A78));
      expect(scheme.onSecondaryContainer, const Color(0xFFDCE5FB));
      expect(scheme.tertiary, const Color(0xFFFF9AA4));
      expect(scheme.onTertiary, const Color(0xFF3A0910));
      expect(scheme.tertiaryContainer, const Color(0xFF6B2230));
      expect(scheme.onTertiaryContainer, const Color(0xFFFFD9DD));
      expect(scheme.error, const Color(0xFFF2B8B5));
      expect(scheme.onError, const Color(0xFF601410));
      expect(scheme.errorContainer, const Color(0xFF8C1D18));
      expect(scheme.onErrorContainer, const Color(0xFFF9DEDC));
    });
  });

  group('AppTokens', () {
    test('store palette has all eight keys with design hexes', () {
      const expected = <String, Color>{
        'tomato': Color(0xFFE5604F),
        'tangerine': Color(0xFFF2994A),
        'lemon': Color(0xFFD9A400),
        'lime': Color(0xFF7DB84A),
        'teal': Color(0xFF2BA6A0),
        'sky': Color(0xFF4A9BE0),
        'grape': Color(0xFF8E6CCB),
        'bubblegum': Color(0xFFE96FA6),
      };

      expect(AppTokens.storePaletteKeys, expected.keys.toList());
      expect(AppTokens.light.storePalette, expected);
      expect(AppTokens.dark.storePalette, expected);
      expect(AppTokens.light.storePalette.length, 8);
    });

    test('light and dark success colours match design table', () {
      expect(AppTokens.light.success, const Color(0xFFA5D5B6));
      expect(AppTokens.light.onSuccess, const Color(0xFF123B24));
      expect(AppTokens.light.successContainer, const Color(0xFFD9EEE0));
      expect(AppTokens.light.onSuccessContainer, const Color(0xFF123B24));

      expect(AppTokens.dark.success, const Color(0xFFA5D5B6));
      expect(AppTokens.dark.onSuccess, const Color(0xFF123B24));
      expect(AppTokens.dark.successContainer, const Color(0xFF1F4A33));
      expect(AppTokens.dark.onSuccessContainer, const Color(0xFFD9EEE0));
    });

    test('ThemeData exposes AppTokens extension', () {
      expect(AppTheme.light.extension<AppTokens>(), AppTokens.light);
      expect(AppTheme.dark.extension<AppTokens>(), AppTokens.dark);
    });
  });

  group('AppText', () {
    test('wordmark and storeCount match design system 3.2', () {
      final wordmark = AppText.wordmark();
      expect(wordmark.fontFamily, AppText.dynaPuff);
      expect(wordmark.fontWeight, FontWeight.w700);
      expect(wordmark.fontSize, 28);
      expect(wordmark.height, 32 / 28);

      final storeCount = AppText.storeCount();
      expect(storeCount.fontFamily, AppText.roboto);
      expect(storeCount.fontWeight, FontWeight.w700);
      expect(storeCount.fontSize, 52);
      expect(storeCount.height, 1);
    });

    test('TextTheme slots match design system 3.2', () {
      final theme = AppText.textTheme();
      expect(theme.displaySmall?.fontSize, 24);
      expect(theme.displaySmall?.fontWeight, FontWeight.w700);
      expect(theme.headlineSmall?.fontSize, 24);
      expect(theme.headlineSmall?.fontWeight, FontWeight.w500);
      expect(theme.titleLarge?.fontSize, 20);
      expect(theme.titleMedium?.fontSize, 16);
      expect(theme.bodyLarge?.fontSize, 16);
      expect(theme.bodyMedium?.fontSize, 14);
      expect(theme.bodyMedium?.fontWeight, FontWeight.w400);
      expect(theme.labelLarge?.fontSize, 14);
      expect(theme.labelMedium?.fontSize, 12);
    });
  });

  group('component themes', () {
    test('FAB uses tertiary colours and medium radius', () {
      final fab = AppTheme.light.floatingActionButtonTheme;
      expect(fab.backgroundColor, AppTheme.lightColorScheme.tertiary);
      expect(fab.foregroundColor, AppTheme.lightColorScheme.onTertiary);
      final shape = fab.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
    });

    test('card is filled with no elevation', () {
      final card = AppTheme.light.cardTheme;
      expect(card.color, AppTheme.lightColorScheme.surfaceContainer);
      expect(card.elevation, 0);
    });

    test('bottom sheet has 24 radius and drag handle', () {
      final sheet = AppTheme.light.bottomSheetTheme;
      expect(sheet.showDragHandle, isTrue);
      expect(
        sheet.backgroundColor,
        AppTheme.lightColorScheme.surfaceContainerHigh,
      );
      final shape = sheet.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(24)),
      );
    });

    test('dialog has 28 radius', () {
      final dialog = AppTheme.light.dialogTheme;
      final shape = dialog.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(28));
    });

    test('checkbox has 6 radius', () {
      final checkbox = AppTheme.light.checkboxTheme;
      final shape = checkbox.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(6));
    });

    test('snack bar is floating', () {
      expect(AppTheme.light.snackBarTheme.behavior, SnackBarBehavior.floating);
    });

    test('divider uses outlineVariant', () {
      expect(
        AppTheme.light.dividerTheme.color,
        AppTheme.lightColorScheme.outlineVariant,
      );
    });
  });

  test('Color(0x is forbidden in lib/ outside lib/app/theme/', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.contains('lib/app/theme/')) {
        continue;
      }
      final contents = entity.readAsStringSync();
      if (contents.contains('Color(0x')) {
        offenders.add(normalized);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Hard-coded Color(0x...) found outside theme: $offenders',
    );
  });
}
