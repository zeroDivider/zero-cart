import 'package:flutter/material.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// About placeholder until APP-020.
class AboutPlaceholderScreen extends StatelessWidget {
  const AboutPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutPlaceholder)),
      body: Center(
        child: Text(
          l10n.aboutPlaceholder,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
