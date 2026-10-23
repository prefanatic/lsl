// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:lsl/src/errors.dart';
import 'package:lsl/src/numeric_buffer.dart';
import 'package:lsl/src/stream_info.dart';
import 'package:lsl/src/third_party/liblsl.g.dart' as native;

/// A native LSL outlet. Call [destroy] after use.
class Outlet implements Finalizable {
  /// Copies [streamInfo], which the caller can then destroy.
  /// [chunkSize] uses samples; zero permits immediate sends.
  /// [maxBuffered] uses seconds for regular streams, or 100-sample units otherwise.
  factory Outlet({
    required StreamInfo streamInfo,
    int chunkSize = 0,
    int maxBuffered = 360,
  }) {
    final count = streamInfo.channelCount;
    final format = streamInfo.channelFormat;
    if (chunkSize < 0 || chunkSize > 0x7fffffff) {
      throw RangeError.range(chunkSize, 0, 0x7fffffff, 'chunkSize');
    }
    if (maxBuffered < 1 || maxBuffered > 0x7fffffff) {
      throw RangeError.range(maxBuffered, 1, 0x7fffffff, 'maxBuffered');
    }
    final pointer = native.lsl_create_outlet(
      streamInfo.pointer,
      chunkSize,
      maxBuffered,
    );
    return Outlet._(requirePointer(pointer, 'create outlet'), count, format);
  }

  Outlet._(this._pointer, this.channelCount, this.channelFormat) {
    _finalizer.attach(this, _pointer.cast(), detach: this);
  }

  static final _finalizer = NativeFinalizer(
    Native.addressOf<
          NativeFunction<Void Function(Pointer<native.lsl_outlet_struct_>)>
        >(native.lsl_destroy_outlet)
        .cast(),
  );
  final Pointer<native.lsl_outlet_struct_> _pointer;

  /// The number of values in each sample.
  final int channelCount;

  /// The native format of each channel.
  final ChannelFormat channelFormat;
  bool _destroyed = false;

  Pointer<native.lsl_outlet_struct_> get _handle {
    if (_destroyed) throw StateError('Outlet has been destroyed.');
    return _pointer;
  }

  /// Returns a new owned description with this outlet's connection details.
  StreamInfo get streamInfo =>
      StreamInfo.fromPointer(native.lsl_get_info(_handle));

  /// Whether at least one inlet has completed its connection.
  bool get haveConsumers => native.lsl_have_consumers(_handle) != 0;

  /// This synchronous call can block for [timeout] seconds.
  bool waitForConsumers({double timeout = 1}) {
    checkTimeout(timeout);
    return native.lsl_wait_for_consumers(_handle, timeout) != 0;
  }

  void _checkNumeric(int length, {bool chunk = false}) {
    _handle;
    if (channelFormat == ChannelFormat.string) {
      throw StateError('Use the string sample API for a string outlet.');
    }
    if (chunk
        ? length == 0 || length % channelCount != 0
        : length != channelCount) {
      throw ArgumentError(
        'Sample data must contain ${chunk ? "a positive multiple of" : "exactly"} $channelCount elements.',
      );
    }
  }

  /// A zero timestamp uses the local LSL clock.
  void pushSample(List<num> sample, {double timestamp = 0}) {
    _checkNumeric(sample.length);
    _checkTimestamp(timestamp);
    using((arena) {
      final buffer = NumericBuffer(arena, channelFormat, sample.length)
        ..write(sample);
      checkError(
        native.lsl_push_sample_vt(_handle, buffer.pointer.cast(), timestamp),
        'push sample',
      );
    });
  }

  /// Sends sample-major data. [timestamp] is the last sample's timestamp.
  void pushChunk(List<num> chunk, {double timestamp = 0}) {
    _checkNumeric(chunk.length, chunk: true);
    _checkTimestamp(timestamp);
    using((arena) {
      final buffer = NumericBuffer(arena, channelFormat, chunk.length)
        ..write(chunk);
      final data = buffer.pointer;
      final code = switch (channelFormat) {
        ChannelFormat.float32 => native.lsl_push_chunk_ft(
          _handle,
          data.cast(),
          chunk.length,
          timestamp,
        ),
        ChannelFormat.double64 => native.lsl_push_chunk_dt(
          _handle,
          data.cast(),
          chunk.length,
          timestamp,
        ),
        ChannelFormat.int64 => native.lsl_push_chunk_lt(
          _handle,
          data.cast(),
          chunk.length,
          timestamp,
        ),
        ChannelFormat.int32 => native.lsl_push_chunk_it(
          _handle,
          data.cast(),
          chunk.length,
          timestamp,
        ),
        ChannelFormat.int16 => native.lsl_push_chunk_st(
          _handle,
          data.cast(),
          chunk.length,
          timestamp,
        ),
        ChannelFormat.int8 => native.lsl_push_chunk_ct(
          _handle,
          data.cast(),
          chunk.length,
          timestamp,
        ),
        ChannelFormat.string => throw StateError('Use the string sample API.'),
      };
      checkError(code, 'push chunk');
    });
  }

  /// Sends one UTF-8 string per channel. Zero uses the local LSL clock.
  void pushStrings(List<String> sample, {double timestamp = 0}) {
    _handle;
    if (channelFormat != ChannelFormat.string) {
      throw StateError('The outlet does not use string channels.');
    }
    if (sample.length != channelCount) {
      throw ArgumentError('Expected $channelCount strings.');
    }
    _checkTimestamp(timestamp);
    for (final value in sample) {
      checkText(value, 'sample');
    }
    using((arena) {
      final buffer = arena<Pointer<Char>>(sample.length);
      for (var i = 0; i < sample.length; i++) {
        buffer[i] = sample[i].toNativeUtf8(allocator: arena).cast();
      }
      checkError(
        native.lsl_push_sample_strt(_handle, buffer, timestamp),
        'push string sample',
      );
    });
  }

  /// Sends one marker through a single-channel string outlet.
  void pushString(String sample, {double timestamp = 0}) =>
      pushStrings([sample], timestamp: timestamp);

  /// Releases the native outlet. Repeated calls are safe.
  void destroy() {
    if (_destroyed) return;
    _finalizer.detach(this);
    native.lsl_destroy_outlet(_pointer);
    _destroyed = true;
  }
}

void _checkTimestamp(double timestamp) {
  if (!timestamp.isFinite) {
    throw ArgumentError.value(timestamp, 'timestamp');
  }
}
