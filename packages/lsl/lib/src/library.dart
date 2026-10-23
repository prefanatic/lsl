// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:lsl/src/errors.dart';
import 'package:lsl/src/stream_info.dart';
import 'package:lsl/src/third_party/liblsl.g.dart' as native;

/// A numeric sample. Integer formats retain their integer precision.
typedef LslSample = ({double timestamp, List<num> samples});

/// A UTF-8 sample with a timestamp in the source's LSL clock domain.
typedef LslStringSample = ({double timestamp, List<String> samples});

String _version(int value) => '${value ~/ 100}.${value % 100}';

/// The supported LSL wire protocol, as a major.minor version.
String get protocolVersion => _version(native.lsl_protocol_version());

/// The native API version, as a major.minor version. See [libraryInfo] for the patch.
String get libraryVersion => _version(native.lsl_library_version());

/// The pinned native source versions and build identification.
String get libraryInfo => native.lsl_library_info().cast<Utf8>().toDartString();

/// The monotonic LSL clock in seconds. This clock has no UTC epoch.
double localClock() => native.lsl_local_clock();

/// Resolves streams in a worker isolate. The caller owns each result.
/// [timeout] uses seconds. An unfiltered search waits for that duration.
/// A filtered search returns when [minimum] matches arrive, or the timeout expires.
/// [capacity] limits the result count. Filtered searches can return fewer than [minimum].
Future<List<StreamInfo>> resolveStreams({
  String? property,
  String? value,
  String? predicate,
  double timeout = 1,
  int minimum = 1,
  int capacity = 64,
}) async {
  checkTimeout(timeout);
  if (capacity < 1 || capacity > 65536) {
    throw RangeError.range(capacity, 1, 65536, 'capacity');
  }
  if (minimum < 0 || minimum > capacity) {
    throw RangeError.range(minimum, 0, capacity, 'minimum');
  }
  if ((property == null) != (value == null) ||
      (property != null && predicate != null)) {
    throw ArgumentError('Supply a property and value, or a predicate.');
  }
  if (property == null && predicate == null && minimum != 1) {
    throw ArgumentError.value(minimum, 'minimum', 'Requires a search filter.');
  }
  if (property != null) checkText(property, 'property');
  if (value != null) checkText(value, 'value');
  if (predicate != null) checkText(predicate, 'predicate');
  final addresses = await Isolate.run(
    () => _resolve(property, value, predicate, timeout, minimum, capacity),
  );
  final results = <StreamInfo>[];
  try {
    for (final address in addresses) {
      results.add(StreamInfo.fromPointer(Pointer.fromAddress(address)));
    }
    return results;
  } catch (_) {
    for (final address in addresses.skip(results.length)) {
      native.lsl_destroy_streaminfo(Pointer.fromAddress(address));
    }
    for (final info in results) {
      info.destroy();
    }
    rethrow;
  }
}

/// Resolves the first matching stream. The default property is `type`.
Future<StreamInfo?> resolveByProperty(
  String value, {
  String property = 'type',
  double timeout = 1,
}) async {
  final results = await resolveStreams(
    property: property,
    value: value,
    timeout: timeout,
    capacity: 1,
  );
  return results.isEmpty ? null : results.first;
}

List<int> _resolve(
  String? property,
  String? value,
  String? predicate,
  double timeout,
  int minimum,
  int capacity,
) {
  return using((arena) {
    final buffer = arena<Pointer<native.lsl_streaminfo_struct_>>(capacity);
    final count = property != null
        ? native.lsl_resolve_byprop(
            buffer,
            capacity,
            property.toNativeUtf8(allocator: arena).cast(),
            value!.toNativeUtf8(allocator: arena).cast(),
            minimum,
            timeout,
          )
        : predicate != null
        ? native.lsl_resolve_bypred(
            buffer,
            capacity,
            predicate.toNativeUtf8(allocator: arena).cast(),
            minimum,
            timeout,
          )
        : native.lsl_resolve_all(buffer, capacity, timeout);
    checkError(count, 'resolve streams');
    // The receiving isolate takes ownership. XML can omit resolved addresses.
    return [for (var index = 0; index < count; index++) buffer[index].address];
  });
}
