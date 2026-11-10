import 'package:flutter/material.dart';
import 'package:zero_cart/core/widgets/quick_add_fab.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Inbox tab placeholder with Quick add FAB.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navInbox)),
      body: Center(
        child: Text(
          l10n.inboxPlaceholder,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      floatingActionButton: const QuickAddFab(),
    );
  }
}
