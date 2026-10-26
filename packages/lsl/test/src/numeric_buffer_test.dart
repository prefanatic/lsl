// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'package:ffi/ffi.dart';
import 'package:lsl/lsl.dart';
import 'package:lsl/src/numeric_buffer.dart';
import 'package:test/test.dart';

void main() {
  for (final (format, min, max) in [
    (ChannelFormat.int8, -128, 127),
    (ChannelFormat.int16, -32768, 32767),
    (ChannelFormat.int32, -2147483648, 2147483647),
    (ChannelFormat.int64, -9223372036854775808, 9223372036854775807),
  ]) {
    test('${format.name} retains signed limits and rejects invalid values', () {
      using((arena) {
        final buffer = NumericBuffer(arena, format, 2);
        buffer.write([min, max]);
        expect(buffer.values, [min, max]);
        expect(() => buffer.write([1.5, 0]), throwsArgumentError);
        if (format != ChannelFormat.int64) {
          expect(() => buffer.write([min - 1, 0]), throwsRangeError);
          expect(() => buffer.write([0, max + 1]), throwsRangeError);
        }
      });
    });
  }
}
