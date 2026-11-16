import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/wishlist/wishlist_repository.dart';

/// App-lifetime wishlist repository (not autoDispose; Undo may outlive the screen).
final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(
    database: ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

/// Wishlist rows for a store, oldest first (D-18).
final wishlistItemsProvider = StreamProvider.family<List<WishlistItem>, String>(
  (ref, storeId) {
    return ref.watch(wishlistRepositoryProvider).watch(storeId);
  },
);

/// Wishlist item count for the store-details card (WL-1).
final wishlistCountProvider = StreamProvider.family<int, String>((
  ref,
  storeId,
) {
  return ref.watch(wishlistRepositoryProvider).watchCount(storeId);
});
