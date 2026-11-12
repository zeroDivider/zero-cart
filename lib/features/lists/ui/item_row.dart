import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zero_cart/app/theme/app_tokens.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/l10n/generated/app_localizations.dart';

/// One list item: checkbox, content, optional handle placeholder (IT-2, IT-3).
class ItemRow extends StatelessWidget {
  const ItemRow({
    required this.item,
    required this.readOnly,
    required this.onPurchasedChanged,
    required this.onOpenEdit,
    super.key,
  });

  final ListItem item;
  final bool readOnly;
  final ValueChanged<bool>? onPurchasedChanged;
  final VoidCallback? onOpenEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tokens = Theme.of(context).extension<AppTokens>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final purchased = item.isPurchased;
    final hasDescription =
        item.description != null && item.description!.isNotEmpty;
    final stateLabel = purchased
        ? l10n.itemPurchasedState
        : l10n.itemNotPurchasedState;
    final rowLabel = hasDescription
        ? l10n.itemSemanticsWithDescription(
            item.title,
            item.description!,
            stateLabel,
          )
        : l10n.itemSemanticsTitleOnly(item.title, stateLabel);

    final titleStyle = purchased
        ? textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            decoration: TextDecoration.lineThrough,
            fontWeight: FontWeight.w400,
          )
        : textTheme.bodyLarge;
    final descriptionStyle = textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      decoration: purchased ? TextDecoration.lineThrough : null,
    );

    return Semantics(
      container: true,
      label: rowLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tokens.spacing48 + 8),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing16,
            vertical: tokens.spacing12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!readOnly)
                SizedBox(
                  width: tokens.spacing48,
                  height: tokens.spacing48,
                  child: Center(
                    child: Checkbox(
                      key: Key('item_checkbox_${item.id}'),
                      value: purchased,
                      semanticLabel: l10n.itemCheckboxSemantics(item.title),
                      onChanged: onPurchasedChanged == null
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              HapticFeedback.lightImpact();
                              onPurchasedChanged!(value);
                            },
                    ),
                  ),
                )
              else
                SizedBox(width: tokens.spacing48),
              SizedBox(width: tokens.spacing12),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: Key('item_content_${item.id}'),
                    onTap: readOnly ? null : onOpenEdit,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: tokens.spacing48),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: tokens.spacing4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.title, style: titleStyle),
                            if (hasDescription) ...[
                              SizedBox(height: tokens.spacing4),
                              Text(
                                item.description!,
                                style: descriptionStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!purchased && !readOnly)
                SizedBox(
                  width: tokens.spacing48,
                  height: tokens.spacing48,
                  child: Semantics(
                    label: l10n.reorderHandlePlaceholder,
                    child: Icon(
                      Icons.drag_handle,
                      key: Key('item_handle_${item.id}'),
                      color: colorScheme.outline,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
