# lsl_flutter

Lab Streaming Layer for Flutter: discovery, numeric samples, UTF-8 markers, metadata, and clock correction.
This package exports the `lsl` Dart API, bundles liblsl, and provides scoped Android multicast locks.

## Setup

Use Flutter 3.47 or later.
Follow the [dependency instructions](https://github.com/prefanatic/lsl#add-a-dependency), then import:

```dart
import 'package:lsl_flutter/lsl_flutter.dart';
```

Configure the application's [network permissions](https://github.com/prefanatic/lsl/blob/main/docs/platforms.md) before LSL use.
Android, iOS, Linux, macOS, and Windows are supported. Web is not supported.

See the [Dart guide](https://github.com/prefanatic/lsl/tree/main/packages/lsl) for send and receive examples.
Use worker streams for reception on the UI isolate; synchronous native waits can block the UI.
Destroy each owned `StreamInfo` and `Outlet`, and await `Inlet.destroy()` after use.

## Multicast access

Request the required runtime network permission before LSL use.
Use `permission_handler` in the application for Android SDK 37 targets.
The package does not display permission prompts.

```dart
final multicast = await LslMulticastLock.acquire();
try {
  // Create and use LSL resources here, then destroy them.
} finally {
  await multicast.release();
}
```

Each caller owns its lock. Other callers retain access until they release their locks.
The Android plugin also releases all locks when its Flutter engine closes.
On other platforms, the lock needs no native resource.
Flutter UI platform overrides do not change native access.
Apple usage descriptions, signed entitlements, and permission prompts remain application configuration.
See [platform setup](https://github.com/prefanatic/lsl/blob/main/docs/platforms.md).

## Example

The [example application](https://github.com/prefanatic/lsl/tree/main/packages/lsl_flutter/example) publishes string markers and includes platform configuration.
Run `flutter run -d macos` from its directory, or select another supported device.
