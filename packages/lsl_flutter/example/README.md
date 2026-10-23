# LSL example

Run `flutter run -d macos` from this directory.
The example publishes UTF-8 markers through an LSL outlet.
See the package README for network permissions on each platform.

Run `flutter test integration_test/transport_test.dart -d <device-id>` for the transport smoke tests.
These tests verify local discovery, int64 precision, UTF-8 samples, and worker cleanup on the selected target.
Use an iOS simulator or Android emulator for a local run.
Physical-device tests must also verify network permission prompts and Wi-Fi behavior.
