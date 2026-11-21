import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/features/home/store_summary.dart';
import 'package:zero_cart/features/stores/stores_providers.dart';

/// Home board: active stores with item counts, ordered by last activity.
final homeStoreSummariesProvider = StreamProvider<List<StoreSummary>>((ref) {
  return ref.watch(storesRepositoryProvider).watchHomeStoreSummaries();
});
