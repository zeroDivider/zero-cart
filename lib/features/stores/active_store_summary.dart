import 'package:zero_cart/data/database.dart';

/// One active store as the Stores tab draws it: the store plus its live list count.
class ActiveStoreSummary {
  const ActiveStoreSummary({
    required this.store,
    required this.activeListCount,
  });

  final Store store;

  /// Active (non-archived) shopping lists for [store].
  final int activeListCount;
}
