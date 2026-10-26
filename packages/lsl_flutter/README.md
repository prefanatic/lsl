# lsl_flutter

Lab Streaming Layer for Flutter: discovery, numeric samples, UTF-8 markers, metadata, and clock correction.
This package exports the `lsl` Dart API and bundles liblsl through its build hook.

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

## Example

The [example application](https://github.com/prefanatic/lsl/tree/main/packages/lsl_flutter/example) publishes string markers and includes platform configuration.
Run `flutter run -d macos` from its directory, or select another supported device.
