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
/// First line is [listName], then `---`, then one line per unpurchased item in
/// the order given. No trailing newline. When every item is purchased (or
/// [items] is empty), the result is only [listName] (callers must not open the
/// share sheet in that case).
String formatShareText(String listName, List<ShareableItem> items) {
  final itemLines = <String>[];
  for (final item in items) {
    if (item.isPurchased) {
      continue;
    }
    final description = item.description;
    if (description == null || description.isEmpty) {
      itemLines.add(item.title);
    } else {
      itemLines.add('${item.title} - $description');
    }
  }
  if (itemLines.isEmpty) {
    return listName;
  }
  return [listName, '---', ...itemLines].join('\n');
}
