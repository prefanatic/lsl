// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsl_example/main.dart';
import 'package:lsl_flutter/lsl_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.prefanatic.lsl_flutter/multicast');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'acquire' ? 1 : null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('publishes a marker and releases multicast access', (
    tester,
  ) async {
    await tester.pumpWidget(const LslExample());
    await tester.pumpAndSettle();
    expect(find.text('liblsl 1.17'), findsOneWidget);
    await tester.tap(find.text('Send marker'));
    await tester.pump();
    expect(find.text('Markers sent: 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(
      calls.map((call) => call.method),
      Platform.isAndroid ? ['acquire', 'release'] : isEmpty,
    );
  });

  testWidgets('shows an acquisition failure without creating an outlet', (
    tester,
  ) async {
    await tester.pumpWidget(
      LslExample(
        acquireMulticastLock: () async {
          throw PlatformException(code: 'multicast_unavailable');
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not start LSL.'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a late acquisition releases its lock after disposal', (
    tester,
  ) async {
    final gate = Completer<LslMulticastLock>();
    await tester.pumpWidget(
      LslExample(acquireMulticastLock: () => gate.future),
    );
    await tester.pumpWidget(const SizedBox());
    gate.complete(await LslMulticastLock.acquire());
    await tester.pump();
    expect(
      calls.map((call) => call.method),
      Platform.isAndroid ? ['acquire', 'release'] : isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
