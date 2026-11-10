import 'package:drift/drift.dart';
import 'package:zero_cart/core/clock.dart';
import 'package:zero_cart/core/ids.dart';
import 'package:zero_cart/core/text_normalize.dart';
import 'package:zero_cart/data/database.dart';

/// Business rules and Drift access for inbox capture items.
class InboxRepository {
  InboxRepository({
    required AppDatabase db,
    required Clock clock,
    required IdGenerator idGenerator,
  }) : _db = db,
       _clock = clock,
       _idGenerator = idGenerator;

  final AppDatabase _db;
  final Clock _clock;
  final IdGenerator _idGenerator;

  /// Newest first (D-16); ties broken by id descending.
  Stream<List<InboxItem>> watchAll() {
    return (_db.select(_db.inboxItems)..orderBy([
          (t) => OrderingTerm.desc(t.createdAt),
          (t) => OrderingTerm.desc(t.id),
        ]))
        .watch();
  }

  /// Inserts a normalized inbox row. Rejects an empty title (D-08).
  Future<InboxItem> add({required String title, String? description}) async {
    final normalizedTitle = normalizeTitle(title);
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    final normalizedDescription = normalizeDescription(description);
    final now = _clock();
    final id = _idGenerator();
    final companion = InboxItemsCompanion.insert(
      id: id,
      title: normalizedTitle,
      description: Value(normalizedDescription),
      createdAt: now,
      updatedAt: now,
    );
    await _db.into(_db.inboxItems).insert(companion);
    return InboxItem(
      id: id,
      title: normalizedTitle,
      description: normalizedDescription,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Updates title/description; keeps [createdAt] so newest-first order is stable.
  Future<InboxItem> update({
    required String id,
    required String title,
    String? description,
  }) async {
    final normalizedTitle = normalizeTitle(title);
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'must not be empty');
    }
    final normalizedDescription = normalizeDescription(description);
    final existing = await (_db.select(
      _db.inboxItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Inbox item $id not found');
    }
    final now = _clock();
    final updated = existing.copyWith(
      title: normalizedTitle,
      description: Value(normalizedDescription),
      updatedAt: now,
    );
    await _db.update(_db.inboxItems).replace(updated);
    return updated;
  }

  /// Hard-deletes the row and returns a snapshot for Undo (D-07).
  Future<InboxItem> remove(String id) async {
    final existing = await (_db.select(
      _db.inboxItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('Inbox item $id not found');
    }
    await (_db.delete(_db.inboxItems)..where((t) => t.id.equals(id))).go();
    return existing;
  }

  /// Re-inserts [snapshot] unchanged (same id and timestamps).
  Future<void> restore(InboxItem snapshot) async {
    await _db.into(_db.inboxItems).insert(snapshot);
  }
}
