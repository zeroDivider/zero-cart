import 'package:zero_cart/core/limits.dart';

/// Trims, collapses newlines to spaces, and clamps to [maxLength].
String normalizeText(String value, int maxLength) {
  final singleLine = value.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();
  if (singleLine.length <= maxLength) {
    return singleLine;
  }
  return singleLine.substring(0, maxLength);
}

/// Normalizes an item title (D-08).
String normalizeTitle(String value) => normalizeText(value, maxItemTitleLength);

/// Normalizes a list name (D-08).
String normalizeListName(String value) =>
    normalizeText(value, maxListNameLength);

/// Normalizes a store name (D-08).
String normalizeStoreName(String value) =>
    normalizeText(value, maxStoreNameLength);

/// Normalizes an optional description; empty after normalize becomes null.
String? normalizeDescription(String? value) {
  if (value == null) {
    return null;
  }
  final normalized = normalizeText(value, maxItemDescriptionLength);
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}
