import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';

/// Swipe end-to-start to remove, with a semantic Remove action (D-22).
class SwipeToRemoveRow extends StatelessWidget {
  const SwipeToRemoveRow({
    required this.itemKey,
    required this.onRemove,
    required this.semanticRemoveLabel,
    required this.child,
    super.key,
  });

  /// Stable key for [Dismissible] (usually the row id).
  final Key itemKey;

  /// Called when the user swipes or invokes the semantic Remove action.
  final Future<void> Function() onRemove;

  final String semanticRemoveLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>()!;

    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        CustomSemanticsAction(label: semanticRemoveLabel): () {
          onRemove();
        },
      },
      child: Dismissible(
        key: itemKey,
        direction: DismissDirection.endToStart,
        background: ColoredBox(
          color: colorScheme.errorContainer,
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing16),
              child: Icon(
                Icons.delete_outline,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
        confirmDismiss: (_) async {
          await onRemove();
          return true;
        },
        child: child,
      ),
    );
  }
}
