/// Form values for creating or renaming a list.
///
/// Passed to the sheet's [onSubmit] callback, which performs the write
/// (or returns a draft for flows that defer persistence).
class ListDraft {
  const ListDraft({required this.name});

  final String name;
}
