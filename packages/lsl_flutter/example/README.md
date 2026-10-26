# LSL example

The example publishes UTF-8 markers through an LSL outlet.
Run `flutter run -d macos` from this directory, or select another supported device.
Connect an LSL inlet, then press **Send marker**.
The counter records sends; a send does not confirm that a receiver received the marker.
See [platform setup](../../../docs/platforms.md) for network permissions, multicast access, and iOS signing.

Run the transport tests on an iOS simulator or Android emulator:

```sh
flutter test integration_test/transport_test.dart -d <device-id>
```

These tests check discovery, int64 precision, UTF-8 samples, and worker cleanup within one device.
Test permissions and Wi-Fi discovery between physical devices before a mobile release.
