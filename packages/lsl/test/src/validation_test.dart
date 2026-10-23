// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:ffi';

import 'package:lsl/lsl.dart';
import 'package:test/test.dart';

void main() {
  test('resolver arguments fail before a native search starts', () async {
    final searches = [
      resolveStreams(capacity: 0),
      resolveStreams(capacity: 65537),
      resolveStreams(minimum: -1),
      resolveStreams(minimum: 2, capacity: 1),
      resolveStreams(minimum: 0),
      resolveStreams(value: 't'),
      resolveStreams(property: 'type', value: 't', predicate: 'true()'),
      resolveStreams(property: 'ty\u0000pe', value: 't'),
      resolveStreams(property: 'type', value: 'a\u0000b'),
      resolveStreams(predicate: 'a\u0000b'),
      resolveStreams(timeout: double.nan),
    ];
    await Future.wait([
      for (final search in searches) expectLater(search, throwsArgumentError),
    ]);
  });

  test('invalid native transport options do not allocate handles', () async {
    final info = StreamInfo(name: 'validation', type: 'test', channelCount: 1);
    addTearDown(info.destroy);
    for (final length in [-1, 0x80000000]) {
      expect(
        () => Outlet(streamInfo: info, chunkSize: length),
        throwsRangeError,
      );
      expect(
        () => Inlet(streamInfo: info, maxChunkSize: length),
        throwsRangeError,
      );
    }
    for (final length in [0, -1, 0x80000000]) {
      expect(
        () => Outlet(streamInfo: info, maxBuffered: length),
        throwsRangeError,
      );
      expect(
        () => Inlet(streamInfo: info, maxBuffered: length),
        throwsRangeError,
      );
    }
    expect(() => StreamInfo.fromPointer(nullptr), throwsA(isA<LslException>()));
    info.destroy();
    expect(() => Inlet(streamInfo: info), throwsStateError);
    expect(() => Outlet(streamInfo: info), throwsStateError);
  });

  test('string outlets reject invalid text and timestamps', () {
    final info = StreamInfo(
      name: 'validation',
      type: 'test',
      channelCount: 1,
      channelFormat: ChannelFormat.string,
    );
    final outlet = Outlet(streamInfo: info);
    info.destroy();
    addTearDown(outlet.destroy);
    expect(() => outlet.pushString('a\u0000b'), throwsArgumentError);
    expect(
      () => outlet.pushString('a', timestamp: double.nan),
      throwsArgumentError,
    );
    expect(() => outlet.waitForConsumers(timeout: -1), throwsArgumentError);
    outlet.destroy();
    expect(() => outlet.pushString('a'), throwsStateError);
    expect(() => outlet.streamInfo, throwsStateError);
  });
}
