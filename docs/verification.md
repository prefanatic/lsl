# Verification

Verification date: 2026-10-23.
Local host: macOS arm64, Flutter 3.47.5, Dart 3.13.4, Xcode 27.1.

## Automated checks

The [CI workflow](https://github.com/prefanatic/lsl/actions/workflows/ci.yaml) records results for each commit.
The [hosted baseline run](https://github.com/prefanatic/lsl/actions/runs/40012923831) passed all five jobs.
It verified native tests, coverage, Flutter tests, desktop builds, bundled CLI execution, mobile builds, and binding generation.
Check the latest commit's result before a release.
API documentation checks now reject broken links and unresolved references.

| Target | Runtime tests | Build verification |
| --- | --- | --- |
| Linux x64 | Native tests, Flutter tests, bundled AOT CLI | Release Flutter example |
| macOS arm64 | Native tests, Flutter tests, bundled AOT CLI | Universal arm64/x64 release example |
| Windows x64 | Native tests, Flutter tests, bundled AOT CLI | Release Flutter example |
| Android arm, arm64, x64 | Physical-device network tests remain pending | Release APK |
| iOS arm64 simulator | Network behavior remains unverified | Simulator example |
| iOS arm64 device | Physical-device network tests remain pending | Unsigned release example |

## Final local review

- Strict Dart analysis and format validation passed.
- The native and tool suites contain 44 tests. The native suites passed through the Flutter runner with `--no-pub`.
- Handwritten library coverage reached 95.6% (521 of 545 lines) through the Flutter runner.
- The Flutter package test and example widget test passed.
- Both API documentation builds passed with zero warnings and zero errors.
- External Dart and Flutter consumers resolved path dependencies outside the workspace and loaded liblsl.
- The external Dart consumer received a marker through a worker inlet.
- Both external consumers used cached Pub dependencies and the offline source-archive override.
- The macOS example launched and completed a hot reload. Automatic foreground activation failed.
- The Git whitespace check passed.

Tests cover all seven formats, numeric chunks, timestamp rules, metadata ownership, discovery, and clock correction.
They cover native timeout and stream-loss errors, error order, pause/resume, cancellation, and repeated destruction.
They also cover synchronous close/reopen, source recovery, and cancellation during recovery.
Validation tests reject invalid dimensions, native options, text, XML rates, and search filters.
Archive tests cover hashes, offline sources, cache reuse, HTTP failures, and unsafe paths.
Coverage-tool tests cover relative paths, Windows paths, missing files, unrelated files, and threshold failures.

The coverage gate requires 90% line coverage for handwritten library code.
It excludes generated C bindings and export-only libraries. It rejects missing source files.

## Remaining scope

Physical Android and iOS tests must verify permissions, Wi-Fi discovery, and sample transfer on the intended networks.
Physical iOS tests require Apple's multicast entitlement and a matching signing profile.
Android SDK 37 permission behavior requires a matching device or emulator and a consuming application that targets SDK 37.
Linux arm64, Windows arm64, and iOS x64 simulator targets lack build or runtime verification.
CI executes macOS arm64. The universal macOS build also compiles the x64 library.
No live health backend or wearable hardware participates in these checks.

The native code can emit compiler warnings and teardown messages during transport tests.
Those messages do not imply a passing test; use the runner's exit status and assertions.
The supported AOT path is `dart build cli`, which bundles the native asset.
A direct `dart test --compiler exe` run on this SDK did not supply a native asset map.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for reproducible commands.
