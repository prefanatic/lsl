// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:async';
import 'dart:io';

import 'package:lsl/lsl.dart';

Future<void> main() async {
  final sourceId = 'lsl-dart-example-${DateTime.now().microsecondsSinceEpoch}';
  final info = StreamInfo(
    name: 'Dart markers',
    type: 'Markers',
    channelCount: 1,
    channelFormat: ChannelFormat.string,
    sourceId: sourceId,
  );
  final outlet = Outlet(streamInfo: info);
  info.destroy();
  try {
    final resolved = await resolveByProperty(
      sourceId,
      property: 'source_id',
      timeout: 3,
    );
    if (resolved == null) throw StateError('The example outlet was not found.');
    final inlet = Inlet(streamInfo: resolved);
    resolved.destroy();
    final sample = inlet.openStrings().first;
    final publisher = Timer.periodic(const Duration(milliseconds: 20), (_) {
      outlet.pushString('example');
    });
    try {
      final received = await sample.timeout(const Duration(seconds: 5));
      if (received.samples.single != 'example') {
        throw StateError('The marker did not match.');
      }
      stdout.writeln(
        'liblsl $libraryVersion: the loopback inlet received a marker.',
      );
    } finally {
      publisher.cancel();
      await inlet.destroy();
    }
  } finally {
    outlet.destroy();
  }
}
