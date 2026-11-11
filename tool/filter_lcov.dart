// Filters flutter test --coverage output for tracking uploads.
// Excludes generated Drift (*.g.dart) and gen-l10n under l10n/generated/.
// Usage: dart run tool/filter_lcov.dart <in.lcov> <out.lcov>

import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/filter_lcov.dart <in.lcov> <out.lcov>',
    );
    exitCode = 64;
    return;
  }

  final src = File(args[0]);
  final dest = File(args[1]);
  if (!src.existsSync()) {
    stderr.writeln('error: missing ${src.path}');
    exitCode = 1;
    return;
  }

  final keep = <String>[];
  final block = <String>[];
  var dropping = false;

  for (final line in src.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      dropping = _skip(line.substring(3));
      block
        ..clear()
        ..add(line);
    } else if (line.startsWith('end_of_record')) {
      block.add(line);
      if (!dropping) {
        keep.addAll(block);
      }
      block.clear();
      dropping = false;
    } else {
      block.add(line);
    }
  }

  dest.writeAsStringSync('${keep.join('\n')}\n');

  var lf = 0;
  var lh = 0;
  for (final line in keep) {
    if (line.startsWith('LF:')) {
      lf += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      lh += int.parse(line.substring(3));
    }
  }

  if (lf == 0) {
    stdout.writeln('No line records in filtered report');
  } else {
    final pct = (100.0 * lh / lf).toStringAsFixed(1);
    stdout.writeln('Lines: $lh/$lf ($pct%)');
  }
  stdout.writeln('Raw:      ${src.path}');
  stdout.writeln('Filtered: ${dest.path}');
  stdout.writeln('HTML (optional): genhtml ${dest.path} -o coverage/html');
}

bool _skip(String path) {
  final posix = path.replaceAll(r'\', '/');
  return posix.endsWith('.g.dart') || posix.contains('/l10n/generated/');
}
