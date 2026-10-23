# lsl

Lab Streaming Layer for Dart with automatic native builds.
This package provides discovery, metadata, numeric streams, UTF-8 markers, and clock correction.
It also exposes the complete LSL C API through `package:lsl/native.dart`.

Use Dart 3.13 or later. Flutter consumers need Flutter 3.47 or later.
The build hook fetches pinned source archives and verifies their SHA-256 hashes.
It uses `native_toolchain_c` to build liblsl 1.17.7 for the target platform.
The package supports Android, iOS, Linux, macOS, and Windows.
It does not support the web.

## Send samples

```dart
import 'package:lsl/lsl.dart';

Future<void> main() async {
  final info = StreamInfo(
    name: 'Dart signal', type: 'EEG', channelCount: 2,
    nominalSamplingRate: 100, sourceId: 'sensor-1',
  );
  info.setDescription('manufacturer', 'Example');
  final outlet = Outlet(streamInfo: info);
  info.destroy();
  try {
    if (!outlet.waitForConsumers(timeout: 5)) return;
    for (var sample = 0; sample < 100; sample++) {
      outlet.pushSample([sample, sample * 2], timestamp: localClock());
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  } finally {
    outlet.destroy();
  }
}
```

Each sample must contain exactly `channelCount` values.
The inlet derives `channelCount` from its stream description.
Sample methods accept a named `timestamp` parameter.
A numeric chunk contains a positive multiple of `channelCount` values in sample-major order.
For example, `outlet.pushChunk([1, 2, 3, 4])` queues two samples for a two-channel outlet.
An explicit chunk timestamp identifies its last sample.
Integer formats require integers within the native range. The API preserves int64 precision.
For a one-off sample, call `waitForConsumers` before the send and check its result.
A send without a connected consumer does not guarantee delivery.
Keep the outlet alive while it publishes. A push queues data and does not acknowledge delivery.
LSL uses a monotonic local clock. Its timestamps are not UTC or Unix timestamps.
Zero selects the local clock. `-1` selects LSL's deduced timestamp from the preceding sample and nominal rate.
Other finite timestamps pass through unchanged, including negative values.
For regular streams, a chunk assigns earlier timestamps from its nominal rate.
For irregular streams, every sample in a chunk receives the supplied timestamp.

## Receive samples

```dart
import 'package:lsl/lsl.dart';

Future<void> main() async {
  final info = await resolveByProperty('EEG', timeout: 2);
  if (info == null) return;
  final inlet = Inlet(streamInfo: info);
  info.destroy();
  try {
    await for (final sample in inlet.open().take(10)) {
      // Use sample.samples and sample.timestamp here.
    }
  } finally {
    await inlet.destroy();
  }
}
```

Discovery uses a worker isolate. Its results retain native connection details.
`resolveStreams` also supports a property/value filter or an XPath predicate.
An unfiltered search waits for `timeout` seconds. A filtered search can return after `minimum` matches arrive.
`capacity` limits the number of results. A timeout can return fewer matches, including an empty list.
The caller owns every returned `StreamInfo`.
Resolver results contain short metadata. Use `Inlet.fullInfo` for the full remote `desc` element.
Use a stable, unique `sourceId` for a source that must recover after a restart.
`recover: true` permits native reconnection. An empty source ID prevents that recovery.
`Inlet.open` creates a separate worker inlet and uses bounded native waits.
Its timeout limits the initial connection. The single-subscription stream can then wait indefinitely for samples.
The stream emits a native failure as an error, then closes.
Subscription cancellation waits for worker cleanup.
Pause stops pulls from the native queue. The configured native buffer limits retained samples.
After cancellation, a new subscription uses a new native connection.
A worker can queue samples while the main isolate processes them.
For strict application-level flow control, use bounded synchronous pulls in your own worker isolate.

`pullSample`, `openStream`, `fullInfo`, and `timeCorrection` are synchronous native calls.
A nonzero timeout can block the calling isolate.
A pull returns null when no sample arrives. Native failures throw `LslException` subtypes.
Call `setPostprocessing` with LSL processing flags before stream reception.
Use `timeCorrection` with raw timestamps when the application needs manual clock correction.
Add the correction to the source timestamp to map it into the receiver's local LSL clock domain.
Automatic clock synchronization already applies that correction. Do not apply it a second time.

```dart
import 'package:lsl/native.dart' show lsl_processing_options_t;

// Configure the inlet before reception.
inlet.setPostprocessing(
  lsl_processing_options_t.proc_clocksync |
      lsl_processing_options_t.proc_dejitter,
);
```

Processing replaces the original timestamps. `setPostprocessing(0)` disables processing.
`closeStream` drops queued samples and permits a later synchronous or worker connection.
The wrapper replaces the native handle to avoid liblsl 1.17.7's
[close/reopen defect](https://github.com/sccn/liblsl/issues/180).

## Buffer configuration

The `maxBuffered` constructor parameter uses seconds when the nominal rate is positive.
For irregular streams, each unit represents 100 samples. The default is 360 units.
The `chunkSize` and `maxChunkSize` constructor parameters use samples, not channel values.
Zero permits the native default. A nonzero outlet chunk size can delay a partial chunk until more samples arrive.
Use the raw C API for transport flags, per-sample chunk timestamps, and chunk reads.

## String streams

Use `ChannelFormat.string` for marker streams.
Send a list of UTF-8 strings with `Outlet.pushStrings`.
Use `Outlet.pushString` for a single-channel marker stream.
Both methods accept a named `timestamp` parameter.
Receive strings with `Inlet.pullStrings` or `Inlet.openStrings`.
The API rejects embedded NUL characters. Use the raw buffer API for arbitrary binary data.

## Native ownership

`StreamInfo.fromPointer` takes ownership of its argument.
`StreamInfo.copy` creates an independent owned description.
`StreamInfo.fromXml` requires XML from a published stream with a nonempty UID.
Use `copy` when a description must retain its native connection details.
liblsl 1.17.7 can omit resolved addresses from exported XML.
The raw C API requires explicit pointer, buffer, and string cleanup.

The package's [LICENSE](https://github.com/prefanatic/lsl/blob/main/packages/lsl/LICENSE) includes the native dependency notices.
Preserve those notices when you distribute an application with liblsl.
See the [repository README](https://github.com/prefanatic/lsl) for offline builds and development commands.
See [platform configuration](https://github.com/prefanatic/lsl/blob/main/docs/platforms.md) for network permissions and support limits.
