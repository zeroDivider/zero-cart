/// Form values for creating or editing a store without writing to the database.
///
/// The sheet returns this; callers (Stores tab, assignment flow) perform the write.
class StoreDraft {
  const StoreDraft({
    required this.name,
    required this.colorKey,
    this.address,
    this.note,
  });

  final String name;
  final String colorKey;
  final String? address;
  final String? note;
}
