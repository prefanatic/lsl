# lsl

Lab Streaming Layer for Dart with automatic native builds.
This package provides discovery, metadata, numeric streams, UTF-8 markers, and clock correction.
It also exposes the complete LSL C API through `package:lsl/native.dart`.

Use Dart 3.13 or later. Flutter applications need Flutter 3.47 or later.
Follow the [dependency instructions](https://github.com/prefanatic/lsl#add-a-dependency) and [platform setup](https://github.com/prefanatic/lsl/blob/main/docs/platforms.md) first.
The build hook compiles and bundles liblsl automatically for Android, iOS, Linux, macOS, and Windows.
Web is not supported.

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

Use `StreamInfo.setChannelMetadata` to set a label and unit for each channel before outlet creation.
Each sample must contain exactly `channelCount` values.
Integer formats require integers within the native range. The API preserves int64 precision.
A push queues data; it does not confirm receipt.
Keep the outlet alive while it publishes.
For a single send, wait for a consumer and check the result before the push.

## Receive samples

```dart
import 'dart:io';

import 'package:lsl/lsl.dart';

Future<void> main() async {
  final info = await resolveByProperty('EEG', timeout: 2);
  if (info == null) return;
  final inlet = Inlet(streamInfo: info);
  info.destroy();
  try {
    await for (final sample in inlet.open().take(10)) {
      stdout.writeln('${sample.timestamp}: ${sample.samples}');
    }
  } finally {
    await inlet.destroy();
  }
}
```

`resolveByProperty` searches by stream type unless you supply another property.
`resolveStreams` also accepts a property/value filter or an XPath predicate.
An unfiltered search waits for `timeout` seconds; a filtered search can return after `minimum` matches arrive.
`capacity` limits the result count. A search can return fewer matches, including none.
Use `fullInfo` for the remote XML metadata under `desc`.

`open` and `openStrings` receive samples in a worker isolate.
Their timeout limits the initial connection; the stream can then wait indefinitely for samples.
Each stream accepts one subscription. Samples contain immutable lists.
A native failure emits an `LslException` subtype, then closes the stream.
Use a stable, unique `sourceId` and `recover: true` to permit reconnection after a source restart.

Cancel the subscription before use of synchronous inlet methods.
Cancellation waits for worker cleanup. A later call to `open` or `openStrings` creates a new connection.
Pause stops pulls from the native queue, whose size depends on `maxBuffered`.
The Dart stream can queue samples while the receiving isolate processes them.
For strict flow control, use bounded synchronous pulls in your own worker isolate.

## Synchronous reception

`openStream`, `pullSample`, `pullStrings`, `fullInfo`, and `timeCorrection` can block the calling isolate.
Each timeout uses seconds. A pull returns null when no sample arrives; native failures throw `LslException` subtypes.
Call `closeStream` to disconnect and discard queued samples.
Close a synchronous connection before a call to `open` or `openStrings`.

## Timestamps

LSL timestamps use a monotonic clock with no UTC epoch.
Sample methods accept a named `timestamp` parameter:

- `0` selects the local LSL clock, also available through `localClock()`.
- `-1` deduces the timestamp from the preceding sample and nominal rate.
- Other finite values pass through unchanged, including negative values.

Add `inlet.timeCorrection()` to a raw source timestamp to map it into the receiver's local LSL clock domain.
Alternatively, configure automatic processing before reception:

```dart
import 'package:lsl/native.dart' show lsl_processing_options_t;

inlet.setPostprocessing(
  lsl_processing_options_t.proc_clocksync |
      lsl_processing_options_t.proc_dejitter,
);
```

Processing replaces the original timestamps. `setPostprocessing(0)` disables processing.
Do not apply manual clock correction to timestamps that already have automatic clock synchronization.

## Numeric chunks and buffers

`pushChunk` accepts a positive multiple of `channelCount` values in sample-major order.
For example, `outlet.pushChunk([1, 2, 3, 4])` sends two samples through a two-channel outlet.
The chunk timestamp identifies the last sample.
For regular streams, LSL derives earlier timestamps from the nominal rate.
For irregular streams, all samples receive the supplied timestamp.

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

## Resource cleanup

Destroy every owned `StreamInfo`, including resolver results and `Outlet.streamInfo` results.
Destroy each `Outlet` and await `Inlet.destroy()` after use, as the examples show.
Native finalizers provide fallback cleanup; explicit destruction gives predictable resource lifetime.

`StreamInfo.fromPointer` takes ownership of its argument.
`StreamInfo.copy` creates an independent owned description.
`StreamInfo.fromXml` requires XML from a published stream with a nonempty UID.
Use `copy` when a description must retain its native connection details.
Exported XML can omit resolved addresses.
The raw C API requires explicit pointer, buffer, and string cleanup.

The package's [LICENSE](https://github.com/prefanatic/lsl/blob/main/packages/lsl/LICENSE) includes the native dependency notices.
Preserve those notices when you distribute an application with liblsl.
See [native dependencies](https://github.com/prefanatic/lsl/blob/main/docs/native-dependencies.md) for offline builds and licenses.
See [CONTRIBUTING.md](https://github.com/prefanatic/lsl/blob/main/CONTRIBUTING.md) for development checks.
