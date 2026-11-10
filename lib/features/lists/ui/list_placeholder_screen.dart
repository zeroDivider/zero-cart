import 'package:flutter/material.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// List details placeholder until APP-012.
class ListPlaceholderScreen extends StatelessWidget {
  const ListPlaceholderScreen({super.key, required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.listDetailsPlaceholder)),
      body: Center(
        child: Text(listId, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}
