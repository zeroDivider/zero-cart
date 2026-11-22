import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zero_cart/app/router.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/ui/write_runner.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/features/settings/settings_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Appearance, backup placeholder, and About entry (SE-1, SE-2, SE-4).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final asyncTheme = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.all(tokens.spacing16),
        children: [
          Text(l10n.appearance, style: Theme.of(context).textTheme.titleMedium),
          SizedBox(height: tokens.spacing8),
          AsyncBody(
            value: asyncTheme,
            onRetry: () => ref.invalidate(themeModeProvider),
            builder: (context, mode) {
              return SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(l10n.themeModeSystem),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(l10n.themeModeLight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(l10n.themeModeDark),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (next) {
                  final chosen = next.single;
                  runWrite(
                    () => ref
                        .read(settingsRepositoryProvider)
                        .setThemeMode(chosen),
                    l10n: l10n,
                  );
                },
              );
            },
          ),
          SizedBox(height: tokens.spacing24),
          Text(
            l10n.backupAndRestore,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spacing8),
          Text(
            l10n.backupPlaceholderBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: tokens.spacing24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.about),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.about),
          ),
        ],
      ),
    );
  }
}
