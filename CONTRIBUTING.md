# Contributing

Use Flutter 3.47.5 and its bundled Dart SDK to match CI.
Install the [target C++ toolchain](docs/platforms.md).
Keep dependency resolution at the workspace root and preserve `pubspec.lock`.

## Check a change

Run from the repository root:

```sh
flutter pub get --enforce-lockfile
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed packages tool test
dart test test/tool
```

Run from `packages/lsl`:

```sh
dart test --coverage=coverage
```

Return to the repository root to check coverage:

```sh
dart run coverage:format_coverage --lcov --in packages/lsl/coverage --out packages/lsl/coverage/lcov.info --packages .dart_tool/package_config.json --report-on packages/lsl/lib
dart run tool/check_coverage.dart
```

The gate requires 90% line coverage for handwritten library code.
It excludes generated bindings and export-only libraries, and rejects missing source files.
The native tests need local sockets and multicast access.
Cover resource ownership, failure, cancellation, and protocol behavior when a change affects them.

Run this command from both `packages/lsl_flutter` and `packages/lsl_flutter/example`:

```sh
flutter test
```

Run this command from both `packages/lsl` and `packages/lsl_flutter`:

```sh
dart doc --validate-links --output build/api
```

For a mobile transport check, run from the example directory:

```sh
flutter test integration_test/transport_test.dart -d <device-id>
```

Use an iOS simulator or Android emulator for local checks.
Record physical-device results separately; simulator tests do not verify Wi-Fi discovery between devices or permission prompts.

## CI

The [workflow](.github/workflows/ci.yaml) runs desktop tests, coverage, release builds, a bundled CLI, iOS transport, and binding checks.
Every job and step must declare a timeout. A timeout must fail the check.
New commits cancel older runs on the same ref.

| Job | Maximum runtime |
| --- | --- |
| Each desktop target, including Android on Linux | 20 minutes |
| iOS build and simulator transport | 15 minutes |
| Bindings and API documentation | 8 minutes |

The iOS job creates and deletes its own simulator.
Its boot, transport, and cleanup steps have separate deadlines.
Use the manual `ios_only` input to run only the iOS job.
Run `actionlint .github/workflows/ci.yaml` after workflow edits.

## Native changes

Install libclang. Regenerate bindings from the repository root:

```sh
dart run packages/lsl/tool/ffigen.dart
```

Keep generated code separate from handwritten edits.
Update native versions, hashes, source lists, headers, and bindings together.
Check [native dependency licenses](docs/native-dependencies.md) when a source version changes.

## Publication

Keep the repository private and retain `publish_to: none` until the owner authorizes publication.
Check package-name availability and run `dart pub publish --dry-run` from each package directory before publication.
Review package contents, dependencies, licenses, and README links.
