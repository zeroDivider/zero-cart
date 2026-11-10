import 'package:flutter/material.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Settings placeholder until APP-020.
class SettingsPlaceholderScreen extends StatelessWidget {
  const SettingsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Center(
        child: Text(
          l10n.settings,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
