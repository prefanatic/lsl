// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:io';

/// Checks the LCOV report from the documented repository-root command.
void main() {
  final report = File('packages/lsl/coverage/lcov.info').readAsStringSync();
  var total = 0;
  var covered = 0;
  final reportedFiles = <String>{};
  for (final record in report.split('end_of_record')) {
    final lines = record.trim().split('\n');
    final source = lines.where((line) => line.startsWith('SF:')).firstOrNull;
    if (source == null) continue;
    final path = source.substring(3).replaceAll('\\', '/');
    if (path.contains('/third_party/')) continue;
    reportedFiles.add(path.split('/lib/').last);
    for (final line in lines.where((line) => line.startsWith('DA:'))) {
      total++;
      if (int.parse(line.split(',')[1]) > 0) covered++;
    }
  }
  final missing = Directory('packages/lsl/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .map((file) => file.path.replaceAll('\\', '/'))
      .where(
        (path) => path.endsWith('.dart') && !path.contains('/third_party/'),
      )
      // Export-only library files contain no executable lines.
      .where((path) => path.contains('/lib/src/'))
      .where((path) => !reportedFiles.contains(path.split('/lib/').last));
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
