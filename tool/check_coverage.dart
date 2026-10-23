// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:io';

/// Checks the LCOV report from the documented repository-root command.
void main() {
  final report = File('packages/lsl/coverage/lcov.info').readAsStringSync();
  final expectedFiles = Directory('packages/lsl/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => _libraryPath(file.path))
      // Export-only libraries contain no executable lines.
      .where((path) => path.startsWith('src/') && path.endsWith('.dart'))
      .where((path) => !path.startsWith('src/third_party/'))
      .toSet();
  var total = 0;
  var covered = 0;
  final reportedFiles = <String>{};
  for (final record in report.split('end_of_record')) {
    final lines = record.trim().split('\n');
    final source = lines.where((line) => line.startsWith('SF:')).firstOrNull;
    if (source == null) continue;
    final path = _libraryPath(source.substring(3));
    if (!expectedFiles.contains(path)) continue;
    reportedFiles.add(path);
    for (final line in lines.where((line) => line.startsWith('DA:'))) {
      total++;
      if (int.parse(line.split(',')[1]) > 0) covered++;
    }
  }
  final missing = expectedFiles.difference(reportedFiles);
  if (missing.isNotEmpty) {
    stderr.writeln('Coverage has no data for: ${missing.join(', ')}');
    exitCode = 1;
  }
  final percent = total == 0 ? 0.0 : 100 * covered / total;
  stdout.writeln(
    'Handwritten library coverage: $covered/$total (${percent.toStringAsFixed(1)}%).',
  );
  if (percent < 90) {
    stderr.writeln('Library line coverage must reach 90%.');
    exitCode = 1;
  }
}

String _libraryPath(String path) =>
    path.replaceAll('\\', '/').split(RegExp(r'(^|/)lib/')).last;
