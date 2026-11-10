import 'package:flutter/material.dart';
import 'package:zero_cart/app/theme/app_text.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';

/// Explicit light and dark [ThemeData] from design system 3.1–3.7.
abstract final class AppTheme {
  /// Light [ColorScheme] with exact hex values (not seed-generated).
  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF334E8C),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDDE6FC),
    onPrimaryContainer: Color(0xFF14264F),
    secondary: Color(0xFFA5BDF4),
    onSecondary: Color(0xFF1B2C55),
    secondaryContainer: Color(0xFFC9D8F9),
    onSecondaryContainer: Color(0xFF1B2C55),
    tertiary: Color(0xFFF67583),
    onTertiary: Color(0xFF3A0910),
    tertiaryContainer: Color(0xFFFFD9DD),
    onTertiaryContainer: Color(0xFF5A1420),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFFFFDF5),
    onSurface: Color(0xFF1E2230),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF7F9FE),
    surfaceContainer: Color(0xFFF0F4FC),
    surfaceContainerHigh: Color(0xFFE6ECF8),
    onSurfaceVariant: Color(0xFF4D5368),
    outline: Color(0xFF7B8094),
    outlineVariant: Color(0xFFD8DFEE),
  );

  /// Dark [ColorScheme] with exact hex values (not seed-generated).
  static const ColorScheme darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA5BDF4),
    onPrimary: Color(0xFF14264F),
    primaryContainer: Color(0xFF334E8C),
    onPrimaryContainer: Color(0xFFDDE6FC),
    secondary: Color(0xFFB9C6E8),
    onSecondary: Color(0xFF1B2C55),
    secondaryContainer: Color(0xFF3A4A78),
    onSecondaryContainer: Color(0xFFDCE5FB),
    tertiary: Color(0xFFFF9AA4),
    onTertiary: Color(0xFF3A0910),
    tertiaryContainer: Color(0xFF6B2230),
    onTertiaryContainer: Color(0xFFFFD9DD),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Color(0xFF14171F),
    onSurface: Color(0xFFE8E9F0),
    surfaceContainerLowest: Color(0xFF0F1218),
    surfaceContainerLow: Color(0xFF191D26),
    surfaceContainer: Color(0xFF1D212C),
    surfaceContainerHigh: Color(0xFF262B38),
    onSurfaceVariant: Color(0xFFB4B8C8),
    outline: Color(0xFF8A8FA3),
    outlineVariant: Color(0xFF3A3F4E),
  );

  static ThemeData get light => _build(lightColorScheme, AppTokens.light);

  static ThemeData get dark => _build(darkColorScheme, AppTokens.dark);

  static ThemeData _build(ColorScheme colorScheme, AppTokens tokens) {
    final textTheme = AppText.textTheme().apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );
    final radiusSm = BorderRadius.circular(tokens.radiusSm);
    final shapeSm = RoundedRectangleBorder(borderRadius: radiusSm);
    final shapeMd = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusMd),
    );
    final shapeXl = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusXl),
    );
    final sheetShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(tokens.radiusLg),
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamily: AppText.roboto,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[tokens],
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          textTheme.labelMedium,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.tertiary,
        foregroundColor: colorScheme.onTertiary,
        elevation: 6,
        shape: shapeMd,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: shapeMd,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: radiusSm),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusSm,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusSm,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusSm,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radiusSm,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.surface,
        ),
        actionTextColor: colorScheme.tertiary,
        shape: shapeSm,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: sheetShape,
        showDragHandle: true,
        dragHandleColor: colorScheme.outlineVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: shapeXl,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusCheckbox),
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(Color(0xFFFFFFFF)),
        side: BorderSide(color: colorScheme.onSurfaceVariant, width: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: colorScheme.outline),
          ),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.secondaryContainer;
            }
            return colorScheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return colorScheme.onSecondaryContainer;
            }
            return colorScheme.onSurface;
          }),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outlineVariant),
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: textTheme.labelMedium,
        backgroundColor: colorScheme.surface,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing12,
          vertical: tokens.spacing8,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: textTheme.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
    );
  }
}
