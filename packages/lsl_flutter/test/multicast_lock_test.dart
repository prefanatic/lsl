// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsl_flutter/lsl_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.prefanatic.lsl_flutter/multicast');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'acquire' ? 42 : null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('a lock releases its own native handle once', () async {
    final lock = await LslMulticastLock.acquire();
    await lock.release();
    await lock.release();
    expect(calls.map((call) => call.method), ['acquire', 'release']);
    expect(calls.last.arguments, 42);
  });

  test('concurrent releases share one native operation', () async {
    final gate = Completer<void>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'acquire') return 7;
      await gate.future;
      return null;
    });
    final lock = await LslMulticastLock.acquire();
    final first = lock.release();
    final second = lock.release();
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait([first, second]);
    expect(calls.where((call) => call.method == 'release'), hasLength(1));
  });

  test(
    'native failures propagate and a failed release can be retried',
    () async {
      var fail = true;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'acquire') return 7;
        if (fail) throw PlatformException(code: 'synthetic_failure');
        return null;
      });
      final lock = await LslMulticastLock.acquire();
      await expectLater(lock.release(), throwsA(isA<PlatformException>()));
      fail = false;
      await lock.release();
      expect(calls.where((call) => call.method == 'release'), hasLength(2));
    },
  );

  test('acquisition failures propagate without a release', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'multicast_unavailable');
    });
    await expectLater(
      LslMulticastLock.acquire(),
      throwsA(isA<PlatformException>()),
    );
    expect(calls.single.method, 'acquire');
  });

  test('a missing native handle fails immediately', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await expectLater(LslMulticastLock.acquire(), throwsStateError);
  });

  for (final platform in TargetPlatform.values.where(
    (p) => p != TargetPlatform.android,
  )) {
    test('$platform needs no native multicast lock', () async {
      debugDefaultTargetPlatformOverride = platform;
      final lock = await LslMulticastLock.acquire();
      await lock.release();
      await lock.release();
      expect(calls, isEmpty);
    });
  }
}
