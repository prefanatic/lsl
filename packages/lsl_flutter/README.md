# lsl_flutter

Lab Streaming Layer for Flutter through Dart build hooks.
Import `package:lsl_flutter/lsl_flutter.dart` to use the `lsl` Dart API.
The transitive `lsl` build hook builds and bundles the native library.
The package needs no plugin registration, method channel, CocoaPods podspec, or native binary copy.

Use Flutter 3.47 or later and Dart 3.13 or later.
The package supports Android, iOS, Linux, macOS, and Windows. It does not support the web.

The application must configure network permissions.
Android Wi-Fi discovery can require a multicast lock.
iOS multicast requires Apple's multicast entitlement and a matching signing profile.
Sandboxed macOS applications need client and server network entitlements.
See [platform configuration](https://github.com/prefanatic/lsl/blob/main/docs/platforms.md) for complete instructions.

The [example](https://github.com/prefanatic/lsl/tree/main/packages/lsl_flutter/example) publishes string markers and includes the relevant application configuration.
Run `flutter run -d macos` from the example directory.
See the [lsl README](https://github.com/prefanatic/lsl/tree/main/packages/lsl) for numeric samples, discovery, asynchronous reception, and resource cleanup.
