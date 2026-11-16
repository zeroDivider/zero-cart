import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wishlist multi-select ids (ADR-0007: shared UI state as a Notifier).
class WishlistSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Enters selection mode with [id] selected (long-press).
  void start(String id) {
    state = {id};
  }

  /// Toggles [id] while selecting; clearing the last id exits selection.
  void toggle(String id) {
    final next = Set<String>.from(state);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = next;
  }

  void clear() {
    state = const {};
  }
}

/// Selection set for the wishlist screen (cleared on cancel / successful copy).
final wishlistSelectionProvider =
    NotifierProvider.autoDispose<WishlistSelectionNotifier, Set<String>>(
      WishlistSelectionNotifier.new,
    );
