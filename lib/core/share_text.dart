/// Minimal shareable item shape for [formatShareText].
class ShareableItem {
  const ShareableItem({
    required this.title,
    this.description,
    required this.isPurchased,
  });

  final String title;
  final String? description;
  final bool isPurchased;
}

/// Builds plain-text share content for a list (D-20).
///
/// First line is [listName], then one line per unpurchased item in the order
/// given. No trailing newline. When every item is purchased (or [items] is
/// empty), the result is only [listName].
String formatShareText(String listName, List<ShareableItem> items) {
  final lines = <String>[listName];
  for (final item in items) {
    if (item.isPurchased) {
      continue;
    }
    final description = item.description;
    if (description == null || description.isEmpty) {
      lines.add(item.title);
    } else {
      lines.add('${item.title} - $description');
    }
  }
  return lines.join('\n');
}
