import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/settings/settings_repository.dart';

/// App-lifetime settings repository (not autoDispose).
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(database: ref.watch(appDatabaseProvider));
});

/// Live theme mode from [app_settings]; absent row means system.
final themeModeProvider = StreamProvider<ThemeMode>((ref) {
  return ref.watch(settingsRepositoryProvider).watchThemeMode();
});
