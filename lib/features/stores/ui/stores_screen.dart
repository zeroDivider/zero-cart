import 'package:flutter/material.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Stores tab placeholder. Quick add FAB lives on the tab shell.
class StoresScreen extends StatelessWidget {
  const StoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navStores)),
      body: Center(
        child: Text(
          l10n.storesPlaceholder,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
