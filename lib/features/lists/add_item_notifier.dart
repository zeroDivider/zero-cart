import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the id of a newly added item so [ListScreen] can scroll to it.
///
/// Submit and inline-error state live in [AddItemRow] (ADR-0007 / APP-014c).
class AddItemNotifier extends Notifier<String?> {
  AddItemNotifier(this.listId);

  final String listId;

  @override
  String? build() => null;

  void setPendingScroll(String id) {
    state = id;
  }

  void clearPendingScroll() {
    if (state != null) {
      state = null;
    }
  }
}

final addItemNotifierProvider = NotifierProvider.autoDispose
    .family<AddItemNotifier, String?, String>(
      (listId) => AddItemNotifier(listId),
    );
