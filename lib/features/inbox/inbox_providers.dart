import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_cart/data/database.dart';
import 'package:zero_cart/data/providers.dart';
import 'package:zero_cart/features/inbox/inbox_repository.dart';

/// App-lifetime inbox repository (not autoDispose; Undo may outlive the screen).
final inboxRepositoryProvider = Provider<InboxRepository>((ref) {
  return InboxRepository(
    db: ref.watch(appDatabaseProvider),
    clock: ref.watch(nowProvider),
    idGenerator: ref.watch(idGeneratorProvider),
  );
});

/// Inbox rows, newest first.
final inboxItemsProvider = StreamProvider<List<InboxItem>>((ref) {
  return ref.watch(inboxRepositoryProvider).watchAll();
});
