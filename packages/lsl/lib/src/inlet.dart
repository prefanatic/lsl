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
  factory Inlet({
    required StreamInfo streamInfo,
    int maxBuffered = 360,
    int maxChunkSize = 0,
    bool recover = true,
  }) {
    final count = streamInfo.channelCount;
    if (maxBuffered < 1 || maxBuffered > 0x7fffffff) {
      throw RangeError.range(maxBuffered, 1, 0x7fffffff, 'maxBuffered');
    }
    if (maxChunkSize < 0 || maxChunkSize > 0x7fffffff) {
      throw RangeError.range(maxChunkSize, 0, 0x7fffffff, 'maxChunkSize');
    }
    final pointer = native.lsl_create_inlet(
      streamInfo.pointer,
      maxBuffered,
      maxChunkSize,
      recover ? 1 : 0,
    );
    return Inlet._(
      requirePointer(pointer, 'create inlet'),
      count,
      streamInfo.channelFormat,
      streamInfo.copy(),
      maxBuffered,
      maxChunkSize,
      recover,
    );
  }

  Inlet._(
    this._pointer,
    this.channelCount,
    this.channelFormat,
    this._description,
    this._maxBuffered,
    this._maxChunkSize,
    this._recover,
  ) {
    _finalizer.attach(this, _pointer.cast(), detach: this);
  }

  static final _finalizer = NativeFinalizer(
    Native.addressOf<
          NativeFunction<Void Function(Pointer<native.lsl_inlet_struct_>)>
        >(native.lsl_destroy_inlet)
        .cast(),
  );
  final Pointer<native.lsl_inlet_struct_> _pointer;
  final int channelCount;
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
    if (_destroyed) throw StateError('Inlet has been destroyed.');
    return _pointer;
  }

  void _checkSynchronous() {
    _handle;
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

  void closeStream() {
    _checkSynchronous();
    native.lsl_close_stream(_handle);
    _opened = false;
  }

  int get samplesAvailable {
    _checkSynchronous();
    return native.lsl_samples_available(_handle);
  }

  int flush() {
    _checkSynchronous();
    return native.lsl_inlet_flush(_handle);
  }

  /// Configures clock synchronization, jitter removal, and monotonic timestamps.
  void setPostprocessing(int flags) {
    _checkSynchronous();
    if (flags < 0 || flags > 15) throw RangeError.range(flags, 0, 15, 'flags');
    checkError(
      native.lsl_set_postprocessing(_handle, flags),
      'set postprocessing',
    );
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
    return using((arena) {
      final buffer = NumericBuffer(arena, channelFormat, channelCount);
      final error = arena<Int32>();
      final timestamp = native.lsl_pull_sample_v(
        _handle,
        buffer.pointer.cast(),
        buffer.byteLength,
        timeout,
        error,
      );
      checkError(error.value, 'pull sample');
      if (timestamp == 0) return null;
      return (
        timestamp: timestamp,
        samples: List<num>.unmodifiable(buffer.values),
      );
    });
  }

  LslStringSample? pullStrings({double timeout = 0}) {
    _checkSynchronous();
    checkTimeout(timeout);
    if (channelFormat != ChannelFormat.string) {
      throw StateError('The inlet does not use string channels.');
    }
    _opened = true;
    return using((arena) {
      final buffer = arena<Pointer<Char>>(channelCount);
      final error = arena<Int32>();
      try {
        final timestamp = native.lsl_pull_sample_str(
          _handle,
          buffer,
          channelCount,
          timeout,
          error,
        );
        checkError(error.value, 'pull string sample');
        if (timestamp == 0) return null;
        return (
          timestamp: timestamp,
          samples: List<String>.unmodifiable([
            for (var i = 0; i < channelCount; i++)
              buffer[i].cast<Utf8>().toDartString(),
          ]),
        );
      } finally {
        for (var i = 0; i < channelCount; i++) {
          if (buffer[i] != nullptr) native.lsl_destroy_string(buffer[i]);
        }
      }
    });
  }

  /// Receives numeric samples in an isolate with bounded native waits.
  /// Cancel the subscription before use of the synchronous inlet methods.
  Stream<LslSample> open({double timeout = 5}) {
    if (channelFormat == ChannelFormat.string) {
      throw StateError('Use openStrings for a string inlet.');
    }
    return _startSession(timeout, false).map((value) => value as LslSample);
  }

  Stream<LslStringSample> openStrings({double timeout = 5}) {
    if (channelFormat != ChannelFormat.string) {
      throw StateError('The inlet does not use string channels.');
    }
    return _startSession(
      timeout,
      true,
    ).map((value) => value as LslStringSample);
  }

  Stream<Object> _startSession(double timeout, bool strings) {
    _checkSynchronous();
    checkTimeout(timeout);
    if (_opened) {
      throw StateError(
        'Close the synchronous inlet before opening a sample stream.',
      );
    }
    final session = _SamplerSession(
      _SamplerArgs(
        0,
        _maxBuffered,
        _maxChunkSize,
        _recover,
        timeout,
        strings,
        _processing,
      ),
      _description,
    );
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
    _finalizer.detach(this);
    native.lsl_destroy_inlet(_pointer);
    _description.destroy();
  }
}

class _SamplerArgs {
  const _SamplerArgs(
    this.infoAddress,
    this.maxBuffered,
    this.maxChunkSize,
    this.recover,
    this.timeout,
    this.strings,
    this.processing,
  );
  final int infoAddress;
  final int maxBuffered;
  final int maxChunkSize;
  final bool recover;
  final double timeout;
  final bool strings;
  final int processing;
}

class _SamplerSession {
  _SamplerSession(this.args, this.description) {
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

  final _SamplerArgs args;
  final StreamInfo description;
  late final StreamController<Object> _controller;
  final _done = Completer<void>();
  ReceivePort? _messages;
  ReceivePort? _exit;
  ReceivePort? _errors;
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
    final exit = _exit = ReceivePort();
    final errors = _errors = ReceivePort();
    messages.listen((Object? message) {
      if (message is SendPort) {
        _commands = message;
        if (_stopping) {
          message.send('stop');
        } else if (_paused) {
          message.send('pause');
        }
      } else if (!_stopping && message is (LslException, String)) {
        _controller.addError(message.$1, StackTrace.fromString(message.$2));
      } else if (!_stopping && message != null) {
        _controller.add(message);
      }
    });
    errors.listen((Object? error) {
      if (!_stopping) {
        _controller.addError(StateError('Sample worker failed: $error'));
      }
    });
    exit.listen((Object? _) => _finish());
    final copy = native.lsl_copy_streaminfo(description.pointer);
    final workerArgs = _SamplerArgs(
      copy.address,
      args.maxBuffered,
      args.maxChunkSize,
      args.recover,
      args.timeout,
      args.strings,
      args.processing,
    );
    try {
      await Isolate.spawn(
        _sampleWorkerEntry,
        (workerArgs, messages.sendPort),
        onExit: exit.sendPort,
        onError: errors.sendPort,
        errorsAreFatal: true,
        debugName: 'LSL inlet',
      );
    } catch (error, stack) {
      native.lsl_destroy_streaminfo(copy);
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
    _exit?.close();
    _errors?.close();
    // Do not await close: a paused subscription can defer its done event.
    unawaited(_controller.close());
    _done.complete();
  }
}

Future<void> _sampleWorker(_SamplerArgs args, SendPort destination) async {
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
    while (!stopped) {
      if (paused) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        continue;
      }
      final Object? sample = args.strings
          ? inlet.pullStrings(timeout: 0.05)
          : inlet.pullSample(timeout: 0.05);
      if (sample != null) destination.send(sample);
      await Future<void>.delayed(Duration.zero);
    }
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

void _sampleWorkerEntry((_SamplerArgs, SendPort) payload) {
  unawaited(_sampleWorker(payload.$1, payload.$2));
}
