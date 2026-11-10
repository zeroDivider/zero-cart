import 'package:flutter/material.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Archive placeholder until APP-010 / APP-017.
class ArchivePlaceholderScreen extends StatelessWidget {
  const ArchivePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archivePlaceholder)),
      body: Center(
        child: Text(
          l10n.archivePlaceholder,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
