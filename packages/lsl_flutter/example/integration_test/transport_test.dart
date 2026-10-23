// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lsl_flutter/lsl_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final format in [ChannelFormat.int64, ChannelFormat.string]) {
    testWidgets('${format.name} discovery and worker transport', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final id =
            'mobile-${format.name}-${DateTime.now().microsecondsSinceEpoch}';
        final info = StreamInfo(
          name: 'Mobile transport',
          type: 'test',
          channelCount: 2,
          channelFormat: format,
          sourceId: id,
        );
        final outlet = Outlet(streamInfo: info);
        info.destroy();
        Inlet? inlet;
        Timer? publisher;
        try {
          final resolved = await resolveByProperty(
            id,
            property: 'source_id',
            timeout: 5,
          );
          expect(resolved, isNotNull);
          try {
            inlet = Inlet(streamInfo: resolved!, recover: false);
          } finally {
            resolved?.destroy();
          }
          final strings = format == ChannelFormat.string;
          final sample = strings
              ? inlet.openStrings().first
              : inlet.open().first;
          publisher = Timer.periodic(const Duration(milliseconds: 20), (_) {
            if (strings) {
              outlet.pushStrings(['event α', '心拍'], timestamp: 42.25);
            } else {
              outlet.pushSample([
                9007199254740993,
                -9007199254740993,
              ], timestamp: 42.25);
            }
          });
          final received = await sample.timeout(const Duration(seconds: 10));
          if (strings) {
            final value = received as LslStringSample;
            expect(value.samples, ['event α', '心拍']);
            expect(value.timestamp, 42.25);
          } else {
            final value = received as LslSample;
            expect(value.samples, [9007199254740993, -9007199254740993]);
            expect(value.timestamp, 42.25);
          }
        } finally {
          publisher?.cancel();
          await inlet?.destroy();
          outlet.destroy();
        }
      });
    });
  }
}
