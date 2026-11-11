import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/stores/stores_repository.dart';

/// App-lifetime stores repository (not autoDispose).
final storesRepositoryProvider = Provider<StoresRepository>((ref) {
  return StoresRepository(
    database: ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
    newId: ref.watch(idGeneratorProvider),
  );
});

/// Active stores, alphabetical case-insensitive.
final activeStoresProvider = StreamProvider<List<Store>>((ref) {
  return ref.watch(storesRepositoryProvider).watchActive();
});

/// One store by id (null if missing).
final storeByIdProvider = StreamProvider.family<Store?, String>((ref, id) {
  return ref.watch(storesRepositoryProvider).watchById(id);
});

/// Active-list count for a store (used by Stores rows and archive dialog).
final activeListCountProvider = FutureProvider.family<int, String>((
  ref,
  storeId,
) {
  return ref.watch(storesRepositoryProvider).countActiveLists(storeId);
});
