import 'package:zero_cart/features/stores/store_draft.dart';

/// Where to place Inbox rows when assigning (data model ops 5–6).
final class AssignInboxTarget {
  const AssignInboxTarget({required this.store, required this.list});

  final AssignStoreTarget store;
  final AssignListTarget list;
}

/// Existing active store or a draft to create inside the assign transaction.
sealed class AssignStoreTarget {
  const AssignStoreTarget();
}

/// Use an existing store by id (must be non-archived).
final class ExistingStore extends AssignStoreTarget {
  const ExistingStore(this.id);

  final String id;
}

/// Create a store from [draft] in the same transaction as the assignment.
final class NewStore extends AssignStoreTarget {
  const NewStore(this.draft);

  final StoreDraft draft;
}

/// Existing active list or a name for a new list in the resolved store.
sealed class AssignListTarget {
  const AssignListTarget();
}

/// Use an existing list (must be active and belong to the resolved store).
final class ExistingList extends AssignListTarget {
  const ExistingList(this.listId);

  final String listId;
}

/// Create a list with [name] in the resolved store.
final class NewList extends AssignListTarget {
  const NewList(this.name);

  final String name;
}

/// Result of a successful [ListsRepository.assignInbox] for UI feedback.
final class AssignInboxResult {
  const AssignInboxResult({required this.listId, required this.listName});

  final String listId;
  final String listName;
}
