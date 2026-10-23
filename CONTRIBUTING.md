# Contributing

Use Flutter 3.47.5 and its Dart 3.13 SDK for the checks that CI runs.
Install the target C++ toolchain from [platform configuration](docs/platforms.md).
Resolve dependencies at the repository root:

```sh
flutter pub get --enforce-lockfile
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed packages tool test
dart test test/tool
```

Run the native tests from `packages/lsl`:

```sh
dart test --coverage=coverage
```

Return to the repository root for the coverage check:

```sh
dart run coverage:format_coverage --lcov --in packages/lsl/coverage --out packages/lsl/coverage/lcov.info --packages .dart_tool/package_config.json --report-on packages/lsl/lib
dart run tool/check_coverage.dart
```

The gate requires 90% line coverage for handwritten library code.
It rejects missing source files. It excludes generated bindings and export-only libraries.
Add regression tests for resource ownership, errors, cancellation, and protocol behavior when your change affects them.
The native tests use local sockets. Allow loopback and local multicast traffic on the test host.

Run `flutter test` from `packages/lsl_flutter` and `packages/lsl_flutter/example`.
Run `dart doc --validate-links --output build/api` from `packages/lsl` to validate API links.
CI builds the desktop examples and executes bundled AOT examples.
CI also builds Android and unsigned iOS examples.
CI runs the transport integration tests on an iOS simulator.
Run `flutter test integration_test/transport_test.dart -d <device-id>` from the example directory for a local mobile check.
Record physical-device tests separately. A successful build does not verify mobile network permissions.

Regenerate bindings from the root with `dart run packages/lsl/tool/ffigen.dart`.
Install libclang first. Keep generated output separate from handwritten edits.
See [native dependencies](docs/native-dependencies.md) before a native version change.

Keep the repository private until the owner authorizes public access.
Keep `publish_to: none` until the owner authorizes package publication.
Before publication, check package-name availability and run `dart pub publish --dry-run` from each package directory.
Review the package contents, license notices, dependency sources, and README links before you publish.
