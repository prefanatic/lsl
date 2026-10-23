// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  final script = File('tool/check_coverage.dart').absolute.path;
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('lsl-coverage-');
    for (final path in [
      'src/example.dart',
      'src/third_party/bindings.g.dart',
      'lsl.dart',
    ]) {
      final file = File.fromUri(
        workspace.uri.resolve('packages/lsl/lib/$path'),
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('// Coverage fixture.\n');
    }
  });
  tearDown(() => workspace.delete(recursive: true));

  Future<ProcessResult> check(
    String source, {
    int hits = 9,
    bool missing = false,
  }) async {
    if (missing) {
      await File.fromUri(
        workspace.uri.resolve('packages/lsl/lib/src/missing.dart'),
      ).writeAsString('// Uncovered source.\n');
    }
    final report = File.fromUri(
      workspace.uri.resolve('packages/lsl/coverage/lcov.info'),
    );
    await report.parent.create(recursive: true);
    await report.writeAsString(
      [
        'SF:$source',
        for (var line = 1; line <= 10; line++)
          'DA:$line,${line <= hits ? 1 : 0}',
        'end_of_record',
        'SF:lib/src/third_party/bindings.g.dart',
        'DA:1,0',
        'end_of_record',
        'SF:/other/lib/src/unrelated.dart',
        'DA:1,100',
        'end_of_record',
      ].join('\n'),
    );
    return Process.run(
      'dart',
      [script],
      workingDirectory: workspace.path,
      runInShell: Platform.isWindows,
    );
  }

  for (final source in [
    'lib/src/example.dart',
    '/repo/packages/lsl/lib/src/example.dart',
    r'C:\repo\packages\lsl\lib\src\example.dart',
  ]) {
    test(
      'coverage accepts $source and excludes generated or unrelated files',
      () async {
        final result = await check(source);
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout, contains('9/10 (90.0%)'));
      },
    );
  }

  test('coverage rejects an unreported handwritten source', () async {
    final result = await check('lib/src/example.dart', missing: true);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('src/missing.dart'));
  });

  test('coverage rejects a report below the threshold', () async {
    final result = await check('lib/src/example.dart', hits: 8);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('must reach 90%'));
  });
}
