import 'package:flutter/material.dart' show ThemeMode;
import 'package:zero_cart/data/database.dart';

/// Persists appearance settings in [AppSettings] (D-21, SE-1).
///
/// Absent `theme_mode` means [ThemeMode.system].
class SettingsRepository {
  SettingsRepository({required AppDatabase database}) : _db = database;

  static const String themeModeKey = 'theme_mode';

  static const String _valueSystem = 'system';
  static const String _valueLight = 'light';
  static const String _valueDark = 'dark';

  final AppDatabase _db;

  /// Emits the stored theme mode; missing or unknown values map to system.
  Stream<ThemeMode> watchThemeMode() {
    return (_db.select(_db.appSettings)
          ..where((t) => t.key.equals(themeModeKey)))
        .watchSingleOrNull()
        .map((row) => themeModeFromStorage(row?.value));
  }

  /// Upserts `theme_mode` so the choice survives restart and export.
  Future<void> setThemeMode(ThemeMode mode) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: themeModeKey,
            value: themeModeToStorage(mode),
          ),
        );
  }

  /// Maps a stored string to [ThemeMode]; null/unknown → system.
  static ThemeMode themeModeFromStorage(String? value) {
    switch (value) {
      case _valueLight:
        return ThemeMode.light;
      case _valueDark:
        return ThemeMode.dark;
      case _valueSystem:
      default:
        return ThemeMode.system;
    }
  }

  /// Maps [ThemeMode] to the data-model string (system / light / dark).
  static String themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return _valueLight;
      case ThemeMode.dark:
        return _valueDark;
      case ThemeMode.system:
        return _valueSystem;
    }
  }
}
