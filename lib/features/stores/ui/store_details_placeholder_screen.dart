import 'package:flutter/material.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Store details placeholder until APP-010.
class StoreDetailsPlaceholderScreen extends StatelessWidget {
  const StoreDetailsPlaceholderScreen({super.key, required this.storeId});

  final String storeId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.storeDetailsPlaceholder)),
      body: Center(
        child: Text(storeId, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
