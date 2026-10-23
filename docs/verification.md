# Verification

Verification date: 2026-10-23.
Host: macOS arm64, Flutter 3.47.5, Dart 3.13.4, Xcode 27.1.

## Passed checks

- Strict Dart analysis: `dart analyze --fatal-infos`.
- Format validation for all Dart source files.
- The Flutter runner verified all 31 native transport and archive tests with `--no-pub`.
- The discovery test passed in an isolated rerun after a network interface error in the full suite.
- Handwritten library line coverage reached 93.4% (495 of 530 lines) through the Flutter runner.
- Flutter package and example widget tests on macOS.
- Generation of C bindings produced identical output on a second run.
- The Dart CLI bundle built and received a UTF-8 marker through a worker inlet in AOT mode.
- The macOS release example built a universal arm64/x64 liblsl framework.
- The macOS debug example launched and completed a hot reload.
- The Android debug and release APKs built with armv7, arm64, and x64 liblsl libraries.
- The iOS simulator example built with its bundled liblsl framework.
- The unsigned iOS release example built an arm64 liblsl framework.
- The repository diff passed the Git whitespace check.

The tests cover all seven channel formats, numeric chunks, timestamps, metadata, discovery, and clock correction.
They also cover native timeout and stream-loss errors, cancellation, pause, restart, and repeated destruction.
Archive tests cover SHA-256 checks, offline sources, cache reuse, HTTP errors, and unsafe extraction paths.
The CI coverage check requires 90% line coverage for handwritten library code.
It excludes generated C bindings and export-only files.

## Remaining checks

- Linux and Windows tests and builds require the CI hosts.
- The GitHub CI workflow has not run because the repository has no pushed commit.
- Physical Android and iOS tests must verify network permissions, Wi-Fi discovery, and sample transfer.
- Physical iOS tests require Apple's multicast entitlement and a matching signing profile.
- Linux arm64, Windows arm64, and iOS x64 simulator builds have no local verification.
- No live health backend or wearable hardware participated in these checks.

The upstream native code emits compiler warnings on Android and teardown messages during some transport tests.
These messages did not cause the listed checks to fail.
Flutter could not bring the macOS example to the foreground automatically.
The example process loaded liblsl and completed the hot reload.

## Tool limits

The offline source-preparation tests passed without network access.
An end-to-end offline test attempt stopped when the SDK requested Pub advisory data through a blocked proxy.
An offline Pub resolution did not prevent that later request.
The native source override does not control the SDK's Pub requests.

The direct `dart test --compiler exe` check failed because the runner supplied no native asset map.
The supported `dart build cli` bundle passed the AOT discovery and worker-inlet check.
CI runs the normal VM tests and the bundled AOT example.

Pub network requests stalled during this API check.
Dependency resolution passed with `flutter pub get --offline --enforce-lockfile`.
The normal `dart test` run did not complete.
`flutter test --no-pub` ran the same `package:test` suites with the cached dependencies.
