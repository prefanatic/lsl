// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// Holds Android Wi-Fi multicast access until [release].
///
/// Other platforms return a lock that needs no native resources.
/// Request required network permissions before [acquire].
final class LslMulticastLock {
  LslMulticastLock._(this._id);

  static const _channel = MethodChannel('dev.prefanatic.lsl_flutter/multicast');
  final int? _id;
  Future<void>? _release;

  /// Acquires multicast access without a permission prompt.
  ///
  /// Each caller owns its lock. The Android plugin holds multicast access
  /// until all callers release their locks, or the Flutter engine closes.
  /// Call this method from a Flutter isolate with a platform messenger.
  static Future<LslMulticastLock> acquire() =>
      acquireMulticastLock(isAndroid: Platform.isAndroid);

  /// Releases this caller's lock. Repeated calls share the same result.
  ///
  /// A failed release can be retried.
  Future<void> release() async {
    if (_id == null) return;
    final pending = _release ??= _channel.invokeMethod<void>('release', _id);
    try {
      await pending;
    } catch (_) {
      if (identical(_release, pending)) _release = null;
      rethrow;
    }
  }
}

// This boundary lets host tests exercise Android method calls without
// treating Flutter's UI platform override as the native operating system.
@visibleForTesting
Future<LslMulticastLock> acquireMulticastLock({required bool isAndroid}) async {
  if (!isAndroid) return LslMulticastLock._(null);
  final id = await LslMulticastLock._channel.invokeMethod<int>('acquire');
  if (id == null) {
    throw StateError('The multicast plugin returned no lock identifier.');
  }
  return LslMulticastLock._(id);
}
