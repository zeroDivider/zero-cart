import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/features/settings/settings_repository.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = SettingsRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  test('absent theme_mode means system', () async {
    expect(await repo.watchThemeMode().first, ThemeMode.system);
  });

  test('setThemeMode light dark and system round-trip', () async {
    await repo.setThemeMode(ThemeMode.light);
    expect(await repo.watchThemeMode().first, ThemeMode.light);

    await repo.setThemeMode(ThemeMode.dark);
    expect(await repo.watchThemeMode().first, ThemeMode.dark);

    await repo.setThemeMode(ThemeMode.system);
    expect(await repo.watchThemeMode().first, ThemeMode.system);
  });

  test('setThemeMode persists across new repository instance', () async {
    await repo.setThemeMode(ThemeMode.dark);

    final again = SettingsRepository(database: db);
    expect(await again.watchThemeMode().first, ThemeMode.dark);
  });

  test('unknown stored value maps to system', () async {
    await db
        .into(db.appSettings)
        .insert(AppSettingsCompanion.insert(key: 'theme_mode', value: 'neon'));

    expect(await repo.watchThemeMode().first, ThemeMode.system);
  });

  test('themeModeFromStorage and themeModeToStorage cover all modes', () {
    expect(SettingsRepository.themeModeFromStorage(null), ThemeMode.system);
    expect(SettingsRepository.themeModeFromStorage('system'), ThemeMode.system);
    expect(SettingsRepository.themeModeFromStorage('light'), ThemeMode.light);
    expect(SettingsRepository.themeModeFromStorage('dark'), ThemeMode.dark);

    expect(SettingsRepository.themeModeToStorage(ThemeMode.system), 'system');
    expect(SettingsRepository.themeModeToStorage(ThemeMode.light), 'light');
    expect(SettingsRepository.themeModeToStorage(ThemeMode.dark), 'dark');
  });
}
