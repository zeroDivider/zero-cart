/// Form values for creating or renaming a list without writing to the database.
///
/// The sheet returns this; callers (store details, APP-015) perform the write.
class ListDraft {
  const ListDraft({required this.name});

  final String name;
}
