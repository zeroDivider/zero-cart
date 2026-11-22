import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/core/widgets/async_body.dart';
import 'package:zero_cart/features/settings/repository_url.dart';
import 'package:zero_cart/features/settings/settings_providers.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Package version, MIT notice, licences, and repository link (SE-4).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final asyncInfo = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: AsyncBody(
        value: asyncInfo,
        onRetry: () => ref.invalidate(packageInfoProvider),
        builder: (context, info) {
          return ListView(
            padding: EdgeInsets.all(tokens.spacing16),
            children: [
              Text(
                l10n.appTitle,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              SizedBox(height: tokens.spacing8),
              Text(
                l10n.aboutAppVersion(info.version),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              SizedBox(height: tokens.spacing16),
              Text(
                l10n.mitNotice,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: tokens.spacing24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.openSourceLicences),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: info.version,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.repositoryLinkLabel),
                subtitle: const Text(kRepositoryUrl),
              ),
            ],
          );
        },
      ),
    );
  }
}
