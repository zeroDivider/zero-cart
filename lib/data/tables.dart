import 'package:drift/drift.dart';

/// Active and archived stores (colour, optional address/note).
@DataClassName('Store')
@TableIndex(name: 'idx_stores_archived_at', columns: {#archivedAt})
class Stores extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get colorKey => text()();
  TextColumn get address => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(name)) BETWEEN 1 AND 40)',
  ];
}

/// Named shopping lists belonging to a store.
@DataClassName('ShoppingList')
@TableIndex(
  name: 'idx_shopping_lists_store_archived',
  columns: {#storeId, #archivedAt},
)
class ShoppingLists extends Table {
  TextColumn get id => text()();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  TextColumn get archiveReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(name)) BETWEEN 1 AND 60)',
    "CHECK (archive_reason IS NULL OR archive_reason IN ('manual', 'finished'))",
    'CHECK ((archived_at IS NULL) = (archive_reason IS NULL))',
  ];
}

/// Items on a shopping list, ordered by position (ties allowed).
@DataClassName('ListItem')
@TableIndex(name: 'idx_list_items_list_position', columns: {#listId, #position})
class ListItems extends Table {
  TextColumn get id => text()();
  TextColumn get listId =>
      text().references(ShoppingLists, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isPurchased => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (length(trim(title)) BETWEEN 1 AND 50)',
    'CHECK (description IS NULL OR length(description) BETWEEN 1 AND 70)',
  ];
}

/// Capture-first inbox items (no store/list parent yet).
@DataClassName('InboxItem')
@TableIndex(name: 'idx_inbox_items_created_at', columns: {#createdAt})
class InboxItems extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-store wishlist entries (one logical wishlist per store).
@DataClassName('WishlistItem')
@TableIndex(
  name: 'idx_wishlist_items_store_created',
  columns: {#storeId, #createdAt},
)
class WishlistItems extends Table {
  TextColumn get id => text()();
  TextColumn get storeId =>
      text().references(Stores, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Key/value app settings (v1: theme_mode).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
