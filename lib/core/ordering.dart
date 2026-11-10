/// Minimal item shape needed by [computeDenseReorder].
class OrderableItem {
  const OrderableItem({
    required this.id,
    required this.position,
    required this.isPurchased,
  });

  final String id;
  final int position;
  final bool isPurchased;
}

/// Thrown when [orderedActiveIds] does not match the current active set.
class StaleOrderException implements Exception {
  const StaleOrderException();

  @override
  String toString() => 'StaleOrderException';
}

/// Dense-renumber reorder for one list (D-06, data model §3.5 op 4).
///
/// [allItemsInOrder] must already be ordered by `(position, created_at, id)`.
/// Returns only id → new position pairs for rows whose position changed.
Map<String, int> computeDenseReorder(
  List<OrderableItem> allItemsInOrder,
  List<String> orderedActiveIds,
) {
  final activeNow = <String>{
    for (final item in allItemsInOrder)
      if (!item.isPurchased) item.id,
  };
  final requested = orderedActiveIds.toSet();
  if (activeNow.length != orderedActiveIds.length ||
      activeNow.length != requested.length ||
      !activeNow.containsAll(requested)) {
    throw const StaleOrderException();
  }

  var activeIndex = 0;
  final newSequenceIds = <String>[
    for (final item in allItemsInOrder)
      if (item.isPurchased) item.id else orderedActiveIds[activeIndex++],
  ];

  final byId = {for (final item in allItemsInOrder) item.id: item};
  final changes = <String, int>{};
  for (var i = 0; i < newSequenceIds.length; i++) {
    final id = newSequenceIds[i];
    final newPosition = i + 1;
    final previous = byId[id]!;
    if (previous.position != newPosition) {
      changes[id] = newPosition;
    }
  }
  return changes;
}
