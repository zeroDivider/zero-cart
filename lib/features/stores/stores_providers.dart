import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/stores/active_store_summary.dart';
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

/// Stores tab: each active store with its live active-list count.
final activeStoreSummariesProvider = StreamProvider<List<ActiveStoreSummary>>((
  ref,
) {
  return ref.watch(storesRepositoryProvider).watchActiveWithListCounts();
});

/// Archived stores, alphabetical case-insensitive.
final archivedStoresProvider = StreamProvider<List<Store>>((ref) {
  return ref.watch(storesRepositoryProvider).watchArchived();
});

/// One store by id (null if missing).
final storeByIdProvider = StreamProvider.family<Store?, String>((ref, id) {
  return ref.watch(storesRepositoryProvider).watchById(id);
});
