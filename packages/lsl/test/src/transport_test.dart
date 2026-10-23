// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:async';

import 'package:lsl/lsl.dart';
import 'package:test/test.dart';

void main() {
  for (final format in ChannelFormat.values.where(
    (value) => value != ChannelFormat.string,
  )) {
    test(
      '${format.name} samples retain values, timestamps, and buffer ownership',
      () async {
        final (outlet, inlet) = await pair(format);
        addTearDown(() async {
          await inlet.destroy();
          outlet.destroy();
        });
        inlet.openStream(timeout: 2);
        expect(outlet.waitForConsumers(timeout: 2), isTrue);
        final List<num> values = switch (format) {
          ChannelFormat.float32 || ChannelFormat.double64 => [1.25, -2.5],
          ChannelFormat.int64 => [9007199254740993, -9007199254740993],
          _ => [12, -25],
        };
        outlet.pushSample(values, timestamp: 42.25);
        final first = inlet.pullSample(timeout: 2)!;
        expect(first.samples, values);
        expect(first.timestamp, 42.25);
        outlet.pushSample([0, 1], timestamp: 42.5);
        expect(inlet.pullSample(timeout: 2)!.samples, [0, 1]);
        expect(first.samples, values);
        expect(() => first.samples[0] = 9, throwsUnsupportedError);
        expect(inlet.pullSample(), isNull);
        expect(inlet.samplesAvailable, 0);
        expect(inlet.flush(), 0);
        final full = inlet.fullInfo(timeout: 2);
        expect(full.channelFormat, format);
        full.destroy();
        expect(inlet.timeCorrection(timeout: 3), closeTo(0, 0.1));
        inlet.closeStream();
      },
    );

    test('${format.name} chunks preserve the sample order', () async {
      final (outlet, inlet) = await pair(format, rate: 100);
      addTearDown(() async {
        await inlet.destroy();
        outlet.destroy();
      });
      inlet.openStream(timeout: 2);
      expect(outlet.waitForConsumers(timeout: 2), isTrue);
      outlet.pushChunk([1, 2, 3, 4], timestamp: 20);
      final first = inlet.pullSample(timeout: 2)!;
      final last = inlet.pullSample(timeout: 2)!;
      expect(first.samples, [1, 2]);
      expect(last.samples, [3, 4]);
      expect(first.timestamp, closeTo(19.99, 1e-8));
      expect(last.timestamp, 20);
    });
  }

  test('string samples support all channels and UTF-8', () async {
    final (outlet, inlet) = await pair(ChannelFormat.string);
    addTearDown(() async {
      await inlet.destroy();
      outlet.destroy();
    });
    inlet.openStream(timeout: 2);
    expect(outlet.waitForConsumers(timeout: 2), isTrue);
    outlet.pushStrings(['event α', '心拍'], timestamp: 14.5);
    final result = inlet.pullStrings(timeout: 2)!;
    expect(result.samples, ['event α', '心拍']);
    expect(result.timestamp, 14.5);
    expect(inlet.pullStrings(), isNull);
    expect(() => outlet.pushString('one'), throwsArgumentError);
    expect(() => outlet.pushSample([1, 2]), throwsStateError);
    expect(() => inlet.pullSample(), throwsStateError);
  });

  test('single-channel markers accept named timestamps', () async {
    final sourceId = 'marker-${DateTime.now().microsecondsSinceEpoch}';
    final info = StreamInfo(
      name: 'marker',
      type: 'test',
      channelCount: 1,
      channelFormat: ChannelFormat.string,
      sourceId: sourceId,
    );
    final outlet = Outlet(streamInfo: info);
    info.destroy();
    addTearDown(outlet.destroy);
    final resolved = (await resolveByProperty(
      sourceId,
      property: 'source_id',
      timeout: 3,
    ))!;
    final inlet = Inlet(streamInfo: resolved);
    resolved.destroy();
    addTearDown(inlet.destroy);
    expect(inlet.channelCount, 1);
    inlet.openStream(timeout: 2);
    expect(outlet.waitForConsumers(timeout: 2), isTrue);
    outlet.pushString('marker α', timestamp: 12.5);
    final explicit = inlet.pullStrings(timeout: 2)!;
    expect(explicit.timestamp, 12.5);
    expect(explicit.samples, ['marker α']);
    final before = localClock();
    outlet.pushString('marker β');
    final sample = inlet.pullStrings(timeout: 2)!;
    expect(sample.samples, ['marker β']);
    expect(sample.timestamp, greaterThanOrEqualTo(before));
  });

  test('invalid input cannot reach an undersized native buffer', () async {
    final (outlet, inlet) = await pair(ChannelFormat.int8);
    addTearDown(() async {
      await inlet.destroy();
      outlet.destroy();
    });
    expect(() => outlet.pushSample([1]), throwsArgumentError);
    expect(() => outlet.pushChunk([1, 2, 3]), throwsArgumentError);
    expect(() => outlet.pushChunk([]), throwsArgumentError);
    expect(() => outlet.pushSample([128, 0]), throwsRangeError);
    expect(() => outlet.pushSample([1.5, 0]), throwsArgumentError);
    expect(() => outlet.pushStrings(['a', 'b']), throwsStateError);
    expect(() => inlet.pullStrings(), throwsStateError);
    expect(
      () => inlet.openStream(timeout: double.infinity),
      throwsArgumentError,
    );
    expect(() => inlet.setPostprocessing(16), throwsRangeError);
    await inlet.destroy();
    await inlet.destroy();
    outlet.destroy();
    outlet.destroy();
    expect(() => inlet.pullSample(), throwsStateError);
    expect(() => outlet.pushSample([0, 1]), throwsStateError);
  });

  test('numeric worker receives copies and stops on cancellation', () async {
    final (outlet, inlet) = await pair(ChannelFormat.float32);
    addTearDown(() async {
      await inlet.destroy();
      outlet.destroy();
    });
    final received = <LslSample>[];
    final ready = Completer<void>();
    final subscription = inlet.open().listen((sample) {
      received.add(sample);
      if (received.length == 2 && !ready.isCompleted) ready.complete();
    });
    await waitUntil(() => outlet.haveConsumers);
    outlet.pushSample([1, 2], timestamp: 10);
    outlet.pushSample([3, 4], timestamp: 11);
    await ready.future.timeout(const Duration(seconds: 5));
    subscription.pause();
    await subscription.cancel().timeout(const Duration(seconds: 3));
    expect(received[0].samples, [1, 2]);
    expect(received[1].samples, [3, 4]);
    inlet.openStream(timeout: 2);
    expect(outlet.waitForConsumers(timeout: 2), isTrue);
    inlet.closeStream();
  });

  test('string worker receives UTF-8 samples', () async {
    final (outlet, inlet) = await pair(ChannelFormat.string);
    addTearDown(() async {
      await inlet.destroy();
      outlet.destroy();
    });
    final result = inlet.openStrings().first;
    await waitUntil(() => outlet.haveConsumers);
    outlet.pushStrings(['α', 'β']);
    expect((await result.timeout(const Duration(seconds: 5))).samples, [
      'α',
      'β',
    ]);
  });

  test('destroy cancels a worker during startup and rejects reuse', () async {
    final info = StreamInfo(
      name: 'absent',
      type: 'test',
      channelCount: 1,
      sourceId: 'absent',
    );
    final inlet = Inlet(streamInfo: info);
    info.destroy();
    final subscription = inlet.open(timeout: 2).listen((_) {});
    await inlet.destroy().timeout(const Duration(seconds: 3));
    await subscription.cancel();
    expect(() => inlet.open(), throwsStateError);
  });

  test('destroy closes an unlistened stream without a worker', () async {
    final (outlet, inlet) = await pair(ChannelFormat.float32);
    inlet.open();
    await inlet.destroy().timeout(const Duration(seconds: 1));
    outlet.destroy();
  });

  test('worker reports a bounded connection timeout', () async {
    final info = StreamInfo(
      name: 'absent',
      type: 'test',
      channelCount: 1,
      sourceId: 'absent',
    );
    final inlet = Inlet(streamInfo: info);
    info.destroy();
    addTearDown(inlet.destroy);
    await expectLater(
      inlet.open(timeout: 0.1),
      emitsInOrder([emitsError(isA<LslTimeoutException>()), emitsDone]),
    );
  });

  test('a lost outlet produces a native lost-stream error', () async {
    final (outlet, inlet) = await pair(ChannelFormat.float32);
    addTearDown(() async {
      await inlet.destroy();
      outlet.destroy();
    });
    inlet.openStream(timeout: 2);
    expect(outlet.waitForConsumers(timeout: 2), isTrue);
    outlet.destroy();
    await expectLater(
      Future<void>(() {
        inlet.pullSample(timeout: 2);
      }),
      throwsA(isA<LslLostException>()),
    );
  });

  test('a canceled inlet can start a new sample worker', () async {
    final (outlet, inlet) = await pair(ChannelFormat.float32);
    addTearDown(() async {
      await inlet.destroy();
      outlet.destroy();
    });
    final first = inlet.open().listen((_) {});
    first.pause();
    first.resume();
    await first.cancel();
    final next = inlet.open().first;
    // A publisher sends continuously while the replacement consumer connects.
    final publisher = Timer.periodic(const Duration(milliseconds: 20), (_) {
      outlet.pushSample([5, 6], timestamp: 15);
    });
    try {
      expect((await next.timeout(const Duration(seconds: 5))).samples, [5, 6]);
    } finally {
      publisher.cancel();
    }
  });

  test(
    'discovery returns owned descriptions and a bounded cache miss',
    () async {
      final id = 'lsl-dart-${DateTime.now().microsecondsSinceEpoch}';
      final info = StreamInfo(
        name: id,
        type: 'test',
        channelCount: 1,
        sourceId: id,
      );
      final outlet = Outlet(streamInfo: info);
      info.destroy();
      addTearDown(outlet.destroy);
      final found = await resolveByProperty(
        id,
        property: 'source_id',
        timeout: 3,
      );
      expect(found, isNotNull);
      expect(found!.name, id);
      found.destroy();
      final predicate = await resolveStreams(
        predicate: "source_id='$id'",
        timeout: 2,
      );
      expect(predicate, hasLength(1));
      for (final info in predicate) {
        info.destroy();
      }
      expect(await resolveByProperty('missing-$id', timeout: 0.05), isNull);
      await expectLater(resolveStreams(property: 'type'), throwsArgumentError);
      await expectLater(resolveStreams(timeout: -1), throwsArgumentError);
    },
  );
}

Future<(Outlet, Inlet)> pair(ChannelFormat format, {double rate = 0}) async {
  final info = StreamInfo(
    name: 'test-${format.name}',
    type: 'test',
    channelCount: 2,
    nominalSamplingRate: rate,
    channelFormat: format,
    sourceId: 'test-${DateTime.now().microsecondsSinceEpoch}',
  );
  final outlet = Outlet(streamInfo: info);
  final infoId = info.sourceId;
  info.destroy();
  final connection = (await resolveByProperty(
    infoId,
    property: 'source_id',
    timeout: 3,
  ))!;
  final inlet = Inlet(streamInfo: connection, recover: false);
  connection.destroy();
  return (outlet, inlet);
}

Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('No LSL consumer connected.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
