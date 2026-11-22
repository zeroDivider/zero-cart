import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/settings/repository_url.dart';
import 'package:zero_cart/features/settings/settings_providers.dart';
import 'package:zero_cart/features/settings/settings_repository.dart';
import 'package:zero_cart/features/settings/ui/about_screen.dart';
import 'package:zero_cart/features/settings/ui/settings_screen.dart';

import '../../support/test_app.dart';

const _genericError = 'Something went wrong. Try again.';

class _ThrowingSettingsRepository extends SettingsRepository {
  _ThrowingSettingsRepository({required super.database});

  @override
  Future<void> setThemeMode(ThemeMode mode) {
    throw Exception('theme write failed');
  }
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'ZeroCart',
      packageName: 'com.example.zero_cart',
      version: '0.1.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  ThemeMode materialThemeMode(WidgetTester tester) {
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    return app.themeMode ?? ThemeMode.system;
  }

  Future<void> openSettings(WidgetTester tester, TestAppHarness harness) async {
    await tester.tap(find.byKey(const Key('home_settings_button')));
    await pumpApp(tester, harness);
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  testWidgets('first launch selects System theme mode', (tester) async {
    final harness = await pumpTestApp(tester);
    await openSettings(tester, harness);

    final button = tester.widget<SegmentedButton<ThemeMode>>(
      find.byType(SegmentedButton<ThemeMode>),
    );
    expect(button.selected, {ThemeMode.system});
    expect(materialThemeMode(tester), ThemeMode.system);
    await harness.dispose(tester);
  });

  testWidgets('selecting Light Dark and System updates MaterialApp', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    await openSettings(tester, harness);

    await tester.tap(find.text('Light'));
    await pumpApp(tester, harness);
    expect(
      tester
          .widget<SegmentedButton<ThemeMode>>(
            find.byType(SegmentedButton<ThemeMode>),
          )
          .selected,
      {ThemeMode.light},
    );
    expect(materialThemeMode(tester), ThemeMode.light);

    await tester.tap(find.text('Dark'));
    await pumpApp(tester, harness);
    expect(materialThemeMode(tester), ThemeMode.dark);

    await tester.tap(find.text('System'));
    await pumpApp(tester, harness);
    expect(materialThemeMode(tester), ThemeMode.system);
    await harness.dispose(tester);
  });

  testWidgets('selecting Dark writes theme_mode to the database', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    await openSettings(tester, harness);

    await tester.tap(find.text('Dark'));
    await pumpApp(tester, harness);

    final row = await tester.runAsync(
      () =>
          (harness.db.select(harness.db.appSettings)
                ..where((t) => t.key.equals(SettingsRepository.themeModeKey)))
              .getSingle(),
    );
    expect(row!.value, 'dark');
    await harness.dispose(tester);
  });

  testWidgets('stored theme_mode is applied when the app loads', (
    tester,
  ) async {
    final harness = await pumpTestApp(tester);
    await tester.runAsync(() async {
      await SettingsRepository(database: harness.db)
          .setThemeMode(ThemeMode.light);
      await harness.refreshThemeMode();
    });
    await pumpApp(tester, harness);

    expect(materialThemeMode(tester), ThemeMode.light);
    await openSettings(tester, harness);
    expect(
      tester
          .widget<SegmentedButton<ThemeMode>>(
            find.byType(SegmentedButton<ThemeMode>),
          )
          .selected,
      {ThemeMode.light},
    );
    await harness.dispose(tester);
  });

  testWidgets('About shows version MIT notice licences and repository link', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.about),
    );
    await pumpApp(tester, harness);

    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('Version 0.1.0'), findsOneWidget);
    expect(
      find.text(
        'Copyright (c) 2026 Željka Živanović.\nReleased under the MIT licence.',
      ),
      findsOneWidget,
    );
    expect(find.text('Open-source licences'), findsOneWidget);
    expect(find.text(kRepositoryUrl), findsOneWidget);

    await tester.tap(find.text('Open-source licences'));
    await pumpApp(tester, harness);
    expect(find.byType(LicensePage), findsOneWidget);
    await harness.dispose(tester);
  });

  testWidgets('Backup section placeholder is visible on Settings', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.settings),
    );
    await pumpApp(tester, harness);

    expect(find.text('Backup and restore'), findsOneWidget);
    expect(
      find.text('Export and import will be available here.'),
      findsOneWidget,
    );
    await harness.dispose(tester);
  });

  testWidgets('theme write failure shows localised error snackbar', (
    tester,
  ) async {
    final harness = await pumpTestApp(
      tester,
      router: AppRouter.create(initialLocation: AppRoutes.settings),
      overrides: [
        settingsRepositoryProvider.overrideWith((ref) {
          return _ThrowingSettingsRepository(
            database: ref.watch(appDatabaseProvider),
          );
        }),
      ],
    );
    await pumpApp(tester, harness);

    await tester.tap(find.text('Dark'));
    await pumpApp(tester, harness);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_genericError), findsOneWidget);
    expect(materialThemeMode(tester), ThemeMode.system);
    await harness.dispose(tester);
  });
}
