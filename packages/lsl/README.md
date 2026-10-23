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

void main() {
  final info = StreamInfo(
    name: 'Dart signal', type: 'EEG', channelCount: 2,
    nominalSamplingRate: 100, sourceId: 'sensor-1',
  );
  info.setDescription('manufacturer', 'Example');
  final outlet = Outlet(streamInfo: info);
  info.destroy();
  try {
    outlet.pushSample([1.25, 2.5], timestamp: localClock());
    outlet.pushChunk([1, 2, 3, 4]);
  } finally {
    outlet.destroy();
  }
}
```

Each sample must contain exactly `channelCount` values.
The inlet derives `channelCount` from its stream description.
Sample methods accept a named `timestamp` parameter.
A numeric chunk contains a positive multiple of `channelCount` values in sample-major order.
An explicit chunk timestamp identifies its last sample.
Integer formats require integers within the native range. The API preserves int64 precision.
LSL uses a monotonic local clock. Its timestamps are not UTC or Unix timestamps.

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
The caller owns every returned `StreamInfo`.
`Inlet.open` creates a separate worker inlet and uses bounded native waits.
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

See the repository README for offline builds, toolchains, and platform requirements.
