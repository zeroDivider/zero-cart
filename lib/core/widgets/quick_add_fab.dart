import 'package:flutter/material.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Coral Quick add FAB on the three tab screens. No-op until APP-008.
class QuickAddFab extends StatelessWidget {
  const QuickAddFab({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FloatingActionButton(
      onPressed: onPressed ?? () {},
      tooltip: l10n.quickAdd,
      child: const Icon(Icons.add),
    );
  }
}
