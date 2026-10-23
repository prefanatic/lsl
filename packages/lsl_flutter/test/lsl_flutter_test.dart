// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'package:flutter_test/flutter_test.dart';
import 'package:lsl_flutter/lsl_flutter.dart';

void main() {
  test('Flutter loads liblsl through the transitive build hook', () {
    expect(libraryVersion, '1.17');
    final info = StreamInfo(name: 'Flutter', type: 'test', channelCount: 1);
    expect(info.name, 'Flutter');
    info.destroy();
  });
}
