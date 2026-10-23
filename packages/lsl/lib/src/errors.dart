// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:lsl/src/third_party/liblsl.g.dart' as native;

class LslException implements Exception {
  const LslException(this.code, this.operation, this.message);
  final int code;
  final String operation;
  final String message;

  @override
  String toString() => 'LslException($code): $operation: $message';
}

class LslTimeoutException extends LslException {
  const LslTimeoutException(String operation, String message)
    : super(-1, operation, message);
}

class LslLostException extends LslException {
  const LslLostException(String operation, String message)
    : super(-2, operation, message);
}

void checkError(int code, String operation) {
  if (code >= 0) return;
  final pointer = native.lsl_last_error();
  final message = pointer == nullptr
      ? 'No native error details.'
      : pointer.cast<Utf8>().toDartString();
  throw switch (code) {
    -1 => LslTimeoutException(operation, message),
    -2 => LslLostException(operation, message),
    _ => LslException(code, operation, message),
  };
}

Pointer<T> requirePointer<T extends NativeType>(
  Pointer<T> pointer,
  String operation,
) {
  if (pointer == nullptr) {
    throw LslException(
      -4,
      operation,
      'The native library returned a null handle.',
    );
  }
  return pointer;
}

void checkTimeout(double timeout) {
  if (!timeout.isFinite || timeout < 0) {
    throw ArgumentError.value(
      timeout,
      'timeout',
      'Must be finite and nonnegative.',
    );
  }
}

void checkText(String value, String name) {
  if (value.contains('\u0000')) {
    throw ArgumentError.value(value, name, 'Must not contain NUL.');
  }
}
