import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'adr0007_scanner.dart';

String _toPosix(String path) => path.replaceAll(r'\', '/');

String _relativeToRepo(String filePath, String repoRoot) {
  final normalizedFile = _toPosix(filePath);
  final normalizedRoot = _toPosix(repoRoot);
  final prefix = normalizedRoot.endsWith('/')
      ? normalizedRoot
      : '$normalizedRoot/';
  if (normalizedFile.startsWith(prefix)) {
    return normalizedFile.substring(prefix.length);
  }
  return normalizedFile;
}

void main() {
  test('ADR-0007 allowlist: no new violations; no stale entries', () {
    final repoRoot = Directory.current.path;
    final allowlistFile = File(
      '$repoRoot${Platform.pathSeparator}test'
      '${Platform.pathSeparator}guards'
      '${Platform.pathSeparator}known_violations.txt',
    );
    expect(
      allowlistFile.existsSync(),
      isTrue,
      reason: 'known_violations.txt must exist until APP-014c deletes it',
    );

    final allowlist = parseAllowlist(allowlistFile.readAsStringSync());
    // Ceiling locked at APP-014a; later tasks may only remove entries.
    const allowlistCeiling = {
      'lib/features/archive/ui/archive_screen.dart',
      'lib/features/inbox/ui/inbox_screen.dart',
      'lib/features/lists/ui/list_screen.dart',
      'lib/features/stores/ui/store_active_lists_section.dart',
      'lib/features/stores/ui/store_details_screen.dart',
      'lib/features/stores/ui/stores_screen.dart',
    };
    expect(
      allowlist.difference(allowlistCeiling),
      isEmpty,
      reason: 'allowlist may only shrink from the APP-014a baseline',
    );

    final libDir = Directory('$repoRoot${Platform.pathSeparator}lib');
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final violatingPaths = <String>{};
    final unexpected = <GuardViolation>[];

    for (final file in dartFiles) {
      final relative = _relativeToRepo(file.path, repoRoot);
      final source = file.readAsStringSync();
      final hits = scanSource(relative, source).where((hit) {
        if (hit.pattern == 'ScaffoldMessenger.of(') {
          return !relative.startsWith('lib/core/ui/');
        }
        if (hit.pattern == r"Text('$error')") {
          return relative.startsWith('lib/features/');
        }
        return true;
      });

      if (hits.isEmpty) {
        continue;
      }
      violatingPaths.add(relative);
      if (!allowlist.contains(relative)) {
        unexpected.addAll(hits);
      }
    }

    expect(
      unexpected,
      isEmpty,
      reason:
          'New ADR-0007 violations outside the allowlist:\n'
          '${unexpected.map((v) => '  $v').join('\n')}',
    );

    final stale = allowlist.difference(violatingPaths).toList()..sort();
    expect(
      stale,
      isEmpty,
      reason:
          'Allowlist entries that no longer violate — remove them from '
          'the allowlist:\n${stale.map((path) => '  $path').join('\n')}',
    );
  });
}
