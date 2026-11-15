/// Patterns and scan helpers for ADR-0007 guard tests.
library;

/// A single source hit for a forbidden UI pattern.
class GuardViolation {
  const GuardViolation({
    required this.path,
    required this.line,
    required this.pattern,
  });

  final String path;
  final int line;
  final String pattern;

  @override
  String toString() => '$path:$line ($pattern)';
}

final RegExp scaffoldMessengerOfPattern = RegExp(r'ScaffoldMessenger\.of\(');

/// Raw exception interpolation in UI, e.g. `Text('$error')`.
final RegExp rawErrorInterpolationPattern = RegExp(
  r"""Text\(\s*['"]\$error['"]\s*\)""",
);

/// Scans [source] for ADR-0007 violations. [path] is only used in results.
List<GuardViolation> scanSource(String path, String source) {
  final violations = <GuardViolation>[];
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (scaffoldMessengerOfPattern.hasMatch(line)) {
      violations.add(
        GuardViolation(
          path: path,
          line: i + 1,
          pattern: 'ScaffoldMessenger.of(',
        ),
      );
    }
    if (rawErrorInterpolationPattern.hasMatch(line)) {
      violations.add(
        GuardViolation(path: path, line: i + 1, pattern: r"Text('$error')"),
      );
    }
  }
  return violations;
}

/// Relative paths under [libRoot] that may still violate until APP-014c.
Set<String> parseAllowlist(String contents) {
  final paths = <String>{};
  for (final raw in contents.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    paths.add(line.replaceAll(r'\', '/'));
  }
  return paths;
}
