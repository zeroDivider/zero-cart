import 'package:flutter_test/flutter_test.dart';

import 'adr0007_scanner.dart';

void main() {
  test('detects ScaffoldMessenger.of and Text(\$error)', () {
    const dirty = r'''
void show() {
  ScaffoldMessenger.of(context).showSnackBar(snack);
  return Text('$error');
}
''';
    final hits = scanSource('fake.dart', dirty);
    expect(hits, hasLength(2));
    expect(
      hits.map((h) => h.pattern),
      containsAll(<String>['ScaffoldMessenger.of(', r"Text('$error')"]),
    );
  });

  test('a clean file yields no violations', () {
    const clean = '''
void show() {
  AppMessenger.error(messageFor(l10n, error));
  return Text(l10n.asyncLoadFailed);
}
''';
    expect(scanSource('clean.dart', clean), isEmpty);
  });

  test('parseAllowlist ignores comments and blanks', () {
    const file = '''
# comment
lib/features/a.dart

lib/features/b.dart
''';
    expect(parseAllowlist(file), {
      'lib/features/a.dart',
      'lib/features/b.dart',
    });
  });
}
