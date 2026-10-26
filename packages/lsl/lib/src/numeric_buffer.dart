// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:ffi';

import 'package:lsl/src/stream_info.dart';

/// A numeric buffer within the caller's allocation scope.
class NumericBuffer {
  NumericBuffer(Allocator allocator, this.format, this.length)
    : pointer = allocator<Uint8>(length * format.byteWidth) {
    if (format == ChannelFormat.string) {
      throw ArgumentError('Use a string sample API.');
    }
  }

  final ChannelFormat format;
  final int length;
  final Pointer<Uint8> pointer;
  int get byteLength => length * format.byteWidth;

  List<num> get values => switch (format) {
    ChannelFormat.float32 => pointer.cast<Float>().asTypedList(length),
    ChannelFormat.double64 => pointer.cast<Double>().asTypedList(length),
    ChannelFormat.int64 => pointer.cast<Int64>().asTypedList(length),
    ChannelFormat.int32 => pointer.cast<Int32>().asTypedList(length),
    ChannelFormat.int16 => pointer.cast<Int16>().asTypedList(length),
    ChannelFormat.int8 => pointer.cast<Int8>().asTypedList(length),
    ChannelFormat.string => throw StateError(
      'String buffer has no numeric values.',
    ),
  };

  void write(List<num> samples) {
    final target = values;
    if (format == ChannelFormat.float32 || format == ChannelFormat.double64) {
      for (var i = 0; i < samples.length; i++) {
        target[i] = samples[i].toDouble();
      }
      return;
    }
    final (min, max) = switch (format) {
      ChannelFormat.int8 => (-128, 127),
      ChannelFormat.int16 => (-32768, 32767),
      ChannelFormat.int32 => (-2147483648, 2147483647),
      _ => (-9223372036854775808, 9223372036854775807),
    };
    for (var i = 0; i < samples.length; i++) {
      final value = samples[i];
      if (value is! int) {
        throw ArgumentError.value(value, 'sample', 'Requires an integer.');
      }
      if (value < min || value > max) {
        throw RangeError.range(value, min, max, 'sample');
      }
      target[i] = value;
    }
  }
}
