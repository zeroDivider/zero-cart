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
  test(
    'ADR-0007 strict guard: no ScaffoldMessenger.of or raw Text(\$error)',
    () {
      final repoRoot = Directory.current.path;
      final allowlistFile = File(
        '$repoRoot${Platform.pathSeparator}test'
        '${Platform.pathSeparator}guards'
        '${Platform.pathSeparator}known_violations.txt',
      );
      expect(
        allowlistFile.existsSync(),
        isFalse,
        reason: 'known_violations.txt must be deleted after APP-014c',
      );

      final libDir = Directory('$repoRoot${Platform.pathSeparator}lib');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

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
        unexpected.addAll(hits);
      }

      expect(
        unexpected,
        isEmpty,
        reason:
            'ADR-0007 violations:\n'
            '${unexpected.map((v) => '  $v').join('\n')}',
      );
    },
  );
}
