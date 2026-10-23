// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lsl_example/main.dart';

void main() {
  testWidgets('publishes a marker through the native outlet', (tester) async {
    await tester.pumpWidget(const LslExample());
    expect(find.text('liblsl 1.17'), findsOneWidget);
    await tester.tap(find.text('Send marker'));
    await tester.pump();
    expect(find.text('Markers sent: 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
