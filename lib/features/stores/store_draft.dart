/// Form values for creating or editing a store.
///
/// Returned by the store form after Save. In draft mode the sheet writes
/// nothing (APP-015 assignment); otherwise the sheet persists via repository.
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
