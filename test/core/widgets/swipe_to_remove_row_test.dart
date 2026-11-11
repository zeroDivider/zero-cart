import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_cart/app/theme/app_theme.dart';
import 'package:zero_cart/core/widgets/swipe_to_remove_row.dart';

void main() {
  testWidgets('swipe left invokes onRemove', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SwipeToRemoveRow(
            itemKey: const ValueKey('row'),
            semanticRemoveLabel: 'Remove',
            onRemove: () async {
              removed = true;
            },
            child: const ListTile(title: Text('Item')),
          ),
        ),
      ),
    );

    await tester.fling(find.text('Item'), const Offset(-500, 0), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(removed, isTrue);
  });

  testWidgets('semantic Remove action invokes onRemove', (tester) async {
    final handle = tester.ensureSemantics();
    var removed = false;
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SwipeToRemoveRow(
              itemKey: const ValueKey('row'),
              semanticRemoveLabel: 'Remove',
              onRemove: () async {
                removed = true;
              },
              child: const ListTile(title: Text('Item')),
            ),
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(SwipeToRemoveRow));
      final actionIds = semantics.getSemanticsData().customSemanticsActionIds;
      expect(actionIds, isNotNull);
      final labels = [
        for (final id in actionIds!) CustomSemanticsAction.getAction(id)?.label,
      ];
      expect(labels, contains('Remove'));

      final actionId = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Remove'),
      );
      semantics.owner!.performAction(
        semantics.id,
        SemanticsAction.customAction,
        actionId,
      );
      await tester.pump();
      expect(removed, isTrue);
    } finally {
      handle.dispose();
    }
  });
}
