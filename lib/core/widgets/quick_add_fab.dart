import 'package:flutter/material.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// Coral Quick add FAB (D-02). [onPressed] is supplied by the shell or screen.
class QuickAddFab extends StatelessWidget {
  const QuickAddFab({
    super.key,
    required this.heroTag,
    required this.onPressed,
  });

  /// Distinct hero tag when more than one FAB may be mounted.
  final Object heroTag;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: l10n.quickAdd,
      child: const Icon(Icons.add),
    );
  }
}
