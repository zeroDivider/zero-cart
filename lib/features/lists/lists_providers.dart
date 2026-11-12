import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/lists/active_list_progress.dart';
import 'package:zero_cart/features/lists/lists_repository.dart';

/// App-lifetime lists repository (not autoDispose).
final listsRepositoryProvider = Provider<ListsRepository>((ref) {
  return ListsRepository(
    database: ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

/// Active lists for a store with left/total progress.
final activeListsForStoreProvider =
    StreamProvider.family<List<ActiveListProgress>, String>((ref, storeId) {
      return ref.watch(listsRepositoryProvider).watchActiveForStore(storeId);
    });

/// One shopping list by id (null if missing).
final listByIdProvider = StreamProvider.family<ShoppingList?, String>((
  ref,
  id,
) {
  return ref.watch(listsRepositoryProvider).watchById(id);
});

/// Items for a list ordered by `(position, created_at, id)`.
final listItemsProvider = StreamProvider.family<List<ListItem>, String>((
  ref,
  listId,
) {
  return ref.watch(listsRepositoryProvider).watchItems(listId);
});

/// Whether the Purchased section is expanded (default true per IT-3).
class PurchasedExpandedNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final purchasedExpandedProvider = NotifierProvider.autoDispose
    .family<PurchasedExpandedNotifier, bool, String>(
      (listId) => PurchasedExpandedNotifier(),
    );
