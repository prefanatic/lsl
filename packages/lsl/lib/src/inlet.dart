// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:lsl/src/errors.dart';
import 'package:lsl/src/library.dart';
import 'package:lsl/src/numeric_buffer.dart';
import 'package:lsl/src/stream_info.dart';
import 'package:lsl/src/third_party/liblsl.g.dart' as native;

/// A native inlet. Await [destroy] after use.
class Inlet implements Finalizable {
  /// Copies [streamInfo], which the caller can then destroy.
  /// [maxBuffered] uses seconds for regular streams, or 100-sample units otherwise.
  /// [maxChunkSize] uses samples; zero accepts the outlet's chunk size.
  /// [recover] permits reconnection when the source has a stable source ID.
  factory Inlet({
    required StreamInfo streamInfo,
    int maxBuffered = 360,
    int maxChunkSize = 0,
    bool recover = true,
  }) {
    final count = streamInfo.channelCount;
    final format = streamInfo.channelFormat;
    if (maxBuffered < 1 || maxBuffered > 0x7fffffff) {
      throw RangeError.range(maxBuffered, 1, 0x7fffffff, 'maxBuffered');
    }
    if (maxChunkSize < 0 || maxChunkSize > 0x7fffffff) {
      throw RangeError.range(maxChunkSize, 0, 0x7fffffff, 'maxChunkSize');
    }
    return Inlet._(
      count,
      format,
      streamInfo.copy(),
      maxBuffered,
      maxChunkSize,
      recover,
    );
  }

  Inlet._(
    this.channelCount,
    this.channelFormat,
    this._description,
    this._maxBuffered,
    this._maxChunkSize,
    this._recover,
  );

  static final _finalizer = NativeFinalizer(
    Native.addressOf<
          NativeFunction<Void Function(Pointer<native.lsl_inlet_struct_>)>
        >(native.lsl_destroy_inlet)
        .cast(),
  );
  Pointer<native.lsl_inlet_struct_> _pointer = nullptr;

  /// The number of values in each sample.
  final int channelCount;

  /// The native format of each channel.
  final ChannelFormat channelFormat;
  final StreamInfo _description;
  final int _maxBuffered;
  final int _maxChunkSize;
  final bool _recover;
  bool _destroyed = false;
  bool _opened = false;
  int _processing = 0;
  _SamplerSession? _session;
  Future<void>? _closing;

  Pointer<native.lsl_inlet_struct_> get _handle {
    _checkAlive();
    if (_pointer == nullptr) {
      final pointer = requirePointer(
        native.lsl_create_inlet(
          _description.pointer,
          _maxBuffered,
          _maxChunkSize,
          _recover ? 1 : 0,
        ),
        'create inlet',
      );
      try {
        if (_processing != 0) {
          checkError(
            native.lsl_set_postprocessing(pointer, _processing),
            'set postprocessing',
          );
        }
        _finalizer.attach(this, pointer.cast(), detach: this);
        _pointer = pointer;
      } catch (_) {
        native.lsl_destroy_inlet(pointer);
        rethrow;
      }
    }
    return _pointer;
  }

  void _checkAlive() {
    if (_destroyed) throw StateError('Inlet has been destroyed.');
  }

  void _checkSynchronous() {
    _checkAlive();
    if (_session != null) {
      throw StateError('The inlet has an active sample stream.');
    }
  }

  /// This synchronous call can block for [timeout] seconds.
  void openStream({double timeout = 1}) {
    _checkSynchronous();
    checkTimeout(timeout);
    using((arena) {
      final error = arena<Int32>();
      native.lsl_open_stream(_handle, timeout, error);
      checkError(error.value, 'open stream');
    });
    _opened = true;
  }

  /// Disconnects and drops queued samples. A later call can open a new connection.
  /// This synchronous call releases the handle to avoid liblsl 1.17.7's reopen defect.
  void closeStream() {
    _checkSynchronous();
    _releaseHandle();
    _opened = false;
  }

  /// The number of samples currently in the native queue.
  int get samplesAvailable {
    _checkSynchronous();
    return _pointer == nullptr ? 0 : native.lsl_samples_available(_pointer);
  }

  /// Drops queued samples and returns their count.
  int flush() {
    _checkSynchronous();
    return _pointer == nullptr ? 0 : native.lsl_inlet_flush(_pointer);
  }

  /// Configures clock synchronization, jitter removal, and monotonic timestamps.
  /// Combine the `lsl_processing_options_t` flags from `package:lsl/native.dart`.
  /// Zero disables all processing. Processing replaces the original timestamps.
  void setPostprocessing(int flags) {
    _checkSynchronous();
    if (flags < 0 || flags > 15) throw RangeError.range(flags, 0, 15, 'flags');
    if (_pointer != nullptr) {
      checkError(
        native.lsl_set_postprocessing(_pointer, flags),
        'set postprocessing',
      );
    }
    _processing = flags;
  }

  /// This synchronous call can block for [timeout] seconds.
  double timeCorrection({double timeout = 1}) {
    _checkSynchronous();
    checkTimeout(timeout);
    return using((arena) {
      final error = arena<Int32>();
      final result = native.lsl_time_correction(_handle, timeout, error);
      checkError(error.value, 'time correction');
      return result;
    });
  }

  /// Returns the full owned description, including the remote metadata.
  StreamInfo fullInfo({double timeout = 1}) {
    _checkSynchronous();
    checkTimeout(timeout);
    return using((arena) {
      final error = arena<Int32>();
      final pointer = native.lsl_get_fullinfo(_handle, timeout, error);
      checkError(error.value, 'read full stream info');
      return StreamInfo.fromPointer(pointer);
    });
  }

  /// Returns null when no sample arrives. This call can block for [timeout].
  LslSample? pullSample({double timeout = 0}) {
    _checkSynchronous();
    checkTimeout(timeout);
    if (channelFormat == ChannelFormat.string) {
      throw StateError('Use pullStrings for a string inlet.');
    }
    _opened = true;
    return using(
      (arena) => _pullNumeric(
        _handle,
        NumericBuffer(arena, channelFormat, channelCount),
        arena<Int32>(),
        timeout,
      ),
    );
  }

  /// Returns null when no string sample arrives within [timeout] seconds.
  /// This synchronous call can block the calling isolate.
  LslStringSample? pullStrings({double timeout = 0}) {
    _checkSynchronous();
    checkTimeout(timeout);
    if (channelFormat != ChannelFormat.string) {
      throw StateError('The inlet does not use string channels.');
    }
    _opened = true;
    return using(
      (arena) => _pullStrings(
        _handle,
        arena<Pointer<Char>>(channelCount),
        channelCount,
        arena<Int32>(),
        timeout,
      ),
    );
  }

  /// Receives numeric samples in an isolate with bounded native waits.
  /// [timeout] uses seconds and limits the initial connection, not sample intervals.
  /// The single-subscription stream emits failures as errors, then closes.
  /// Cancel the subscription before use of the synchronous inlet methods.
  Stream<LslSample> open({double timeout = 5}) {
    if (channelFormat == ChannelFormat.string) {
      throw StateError('Use openStrings for a string inlet.');
    }
    return _startSession(timeout).cast<LslSample>();
  }

  /// Receives UTF-8 samples in a worker. [timeout] limits the initial connection.
  /// The stream emits native failures as errors, then closes.
  Stream<LslStringSample> openStrings({double timeout = 5}) {
    if (channelFormat != ChannelFormat.string) {
      throw StateError('The inlet does not use string channels.');
    }
    return _startSession(timeout).cast<LslStringSample>();
  }

  Stream<Object> _startSession(double timeout) {
    _checkSynchronous();
    checkTimeout(timeout);
    if (_opened) {
      throw StateError(
        'Close the synchronous inlet before opening a sample stream.',
      );
    }
    final session = _SamplerSession(this, timeout);
    _session = session;
    session.done.whenComplete(() {
      if (identical(_session, session)) _session = null;
    });
    return session.stream;
  }

  /// Stops the worker before it releases native resources. Repeated calls are safe.
  Future<void> destroy() => _closing ??= _destroy();

  Future<void> _destroy() async {
    _destroyed = true;
    await _session?.cancel();
    _releaseHandle();
    _description.destroy();
  }

  void _releaseHandle() {
    if (_pointer == nullptr) return;
    final pointer = _pointer;
    _pointer = nullptr;
    _finalizer.detach(this);
    native.lsl_destroy_inlet(pointer);
  }
}

typedef _SamplerRequest = ({
  int infoAddress,
  int maxBuffered,
  int maxChunkSize,
  bool recover,
  double timeout,
  int processing,
  SendPort destination,
});

class _SamplerSession {
  _SamplerSession(this.inlet, this.timeout) {
    _controller = StreamController<Object>(
      onListen: _start,
      onPause: () {
        _paused = true;
        _commands?.send('pause');
      },
      onResume: () {
        _paused = false;
        _commands?.send('resume');
      },
      onCancel: cancel,
    );
  }

  final Inlet inlet;
  final double timeout;
  late final StreamController<Object> _controller;
  final _done = Completer<void>();
  ReceivePort? _messages;
  SendPort? _commands;
  bool _started = false;
  bool _stopping = false;
  bool _paused = false;

  Stream<Object> get stream => _controller.stream;
  Future<void> get done => _done.future;

  Future<void> _start() async {
    if (_stopping) return;
    _started = true;
    final messages = _messages = ReceivePort();
    messages.listen((Object? message) {
      // Samples, failures, and exit share one port to preserve send order.
      if (message == null) {
        _finish();
      } else if (message is SendPort) {
        _commands = message;
        if (_stopping) {
          message.send('stop');
        } else if (_paused) {
          message.send('pause');
        }
      } else if (!_stopping && message is (LslException, String)) {
        _controller.addError(message.$1, StackTrace.fromString(message.$2));
      } else if (!_stopping && message is List) {
        _controller.addError(StateError('Sample worker failed: $message'));
      } else if (!_stopping) {
        _controller.add(message);
      }
    });
    Pointer<native.lsl_streaminfo_struct_>? copy;
    try {
      copy = requirePointer(
        native.lsl_copy_streaminfo(inlet._description.pointer),
        'copy worker description',
      );
      await Isolate.spawn(
        _sampleWorker,
        (
          infoAddress: copy.address,
          maxBuffered: inlet._maxBuffered,
          maxChunkSize: inlet._maxChunkSize,
          recover: inlet._recover,
          timeout: timeout,
          processing: inlet._processing,
          destination: messages.sendPort,
        ),
        onExit: messages.sendPort,
        onError: messages.sendPort,
        errorsAreFatal: true,
        debugName: 'LSL inlet',
      );
    } catch (error, stack) {
      if (copy != null) native.lsl_destroy_streaminfo(copy);
      if (!_stopping) _controller.addError(error, stack);
      _finish();
    }
  }

  Future<void> cancel() {
    if (!_stopping) {
      _stopping = true;
      if (_started) {
        _commands?.send('stop');
      } else {
        _finish();
      }
    }
    return done;
  }

  void _finish() {
    if (_done.isCompleted) return;
    _messages?.close();
    // Do not await close: a paused subscription can defer its done event.
    unawaited(_controller.close());
    _done.complete();
  }
}

Future<void> _sampleWorker(_SamplerRequest args) async {
  final destination = args.destination;
  final commands = ReceivePort();
  var stopped = false;
  var paused = false;
  commands.listen((Object? message) {
    if (message == 'stop') stopped = true;
    if (message == 'pause') paused = true;
    if (message == 'resume') paused = false;
  });
  destination.send(commands.sendPort);
  StreamInfo? info;
  Inlet? inlet;
  try {
    info = StreamInfo.fromPointer(Pointer.fromAddress(args.infoAddress));
    inlet = Inlet(
      streamInfo: info,
      maxBuffered: args.maxBuffered,
      maxChunkSize: args.maxChunkSize,
      recover: args.recover,
    );
    inlet.setPostprocessing(args.processing);
    final deadline = Stopwatch()..start();
    while (!stopped) {
      try {
        inlet.openStream(timeout: 0.05);
        break;
      } on LslTimeoutException {
        if (deadline.elapsedMicroseconds / 1e6 >= args.timeout) rethrow;
      }
      await Future<void>.delayed(Duration.zero);
    }
    await using((arena) async {
      final handle = inlet!._handle;
      final count = inlet.channelCount;
      final error = arena<Int32>();
      final Object? Function() pull;
      if (inlet.channelFormat == ChannelFormat.string) {
        final buffer = arena<Pointer<Char>>(count);
        pull = () => _pullStrings(handle, buffer, count, error, 0.05);
      } else {
        final buffer = NumericBuffer(arena, inlet.channelFormat, count);
        pull = () => _pullNumeric(handle, buffer, error, 0.05);
      }
      while (!stopped) {
        if (paused) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          continue;
        }
        final sample = pull();
        if (sample != null) destination.send(sample);
        await Future<void>.delayed(Duration.zero);
      }
    });
  } catch (error, stack) {
    destination.send((
      error is LslException
          ? error
          : LslException(-4, 'sample worker', error.toString()),
      stack.toString(),
    ));
  } finally {
    await inlet?.destroy();
    info?.destroy();
    commands.close();
  }
}

LslSample? _pullNumeric(
  Pointer<native.lsl_inlet_struct_> inlet,
  NumericBuffer buffer,
  Pointer<Int32> error,
  double timeout,
) {
  final timestamp = native.lsl_pull_sample_v(
    inlet,
    buffer.pointer.cast(),
    buffer.byteLength,
    timeout,
    error,
  );
  checkError(error.value, 'pull sample');
  return timestamp == 0
      ? null
      : (timestamp: timestamp, samples: List<num>.unmodifiable(buffer.values));
}

LslStringSample? _pullStrings(
  Pointer<native.lsl_inlet_struct_> inlet,
  Pointer<Pointer<Char>> buffer,
  int count,
  Pointer<Int32> error,
  double timeout,
) {
  try {
    final timestamp = native.lsl_pull_sample_str(
      inlet,
      buffer,
      count,
      timeout,
      error,
    );
    checkError(error.value, 'pull string sample');
    return timestamp == 0
        ? null
        : (
            timestamp: timestamp,
            samples: List<String>.unmodifiable([
              for (var i = 0; i < count; i++)
                buffer[i].cast<Utf8>().toDartString(),
            ]),
          );
  } finally {
    for (var i = 0; i < count; i++) {
      if (buffer[i] != nullptr) {
        native.lsl_destroy_string(buffer[i]);
        buffer[i] = nullptr;
      }
    }
  }
}
