# Verification

Use the [CI workflow](https://github.com/prefanatic/lsl/actions/workflows/ci.yaml) to check the result for a specific commit.
The workflow covers native tests, coverage, Flutter tests, desktop and mobile builds, bundled CLI execution, bindings, and API links.
See [CONTRIBUTING.md](../CONTRIBUTING.md) for commands and execution limits.

## Recorded results

As of 2026-10-26, the latest local checks used macOS arm64, Flutter 3.47.5, Dart 3.13.4, and Xcode 27.1.

| Target | Runtime checks | Build checks |
| --- | --- | --- |
| Linux x64 | Native tests, Flutter tests, bundled CLI | Release example |
| macOS arm64 | Native tests, Flutter tests, bundled CLI | Universal arm64/x64 release example |
| Windows x64 | Native tests, Flutter tests, bundled CLI | Release example |
| Android arm64 emulator, SDK 36 | Local discovery, int64 and UTF-8 worker transport | Release APK for armv7, arm64, and x64 |
| iOS arm64 simulator | Local discovery, int64 and UTF-8 worker transport on iOS 26.5 and 27 | Simulator example |
| iOS arm64 device | Pending physical-device tests | Unsigned release example |

The table's hosted results come from the [2026-10-23 build run](https://github.com/prefanatic/lsl/actions/runs/40018108955).
The [2026-10-26 CI attempt](https://github.com/prefanatic/lsl/actions/runs/40343447988) could not start any jobs.
Hosted iOS transport remains unverified after a previous startup hang.
Fresh local simulators passed on 2026-10-26; the workflow now has explicit deadlines and fresh simulator setup.

The local review passed 44 native tests, eight tool tests, Flutter tests, strict analysis, and API documentation checks.
Handwritten library coverage reached 95.6% (542 of 567 lines), above the 90% gate.
Tests cover all seven channel formats, chunks, timestamps, ownership, discovery, clock correction, errors, recovery, cancellation, and teardown.
Source archive tests check integrity, offline use, cache reuse, HTTP failures, and unsafe paths.
External Dart and Flutter consumers also loaded the native asset outside the workspace on 2026-10-23.
A separate Dart consumer built and loaded liblsl with code_assets 1.2.1 and native_toolchain_c 0.19.3 on 2026-10-26.

The Android multicast plugin passed four JVM tests with Robolectric on SDK 35.
Eleven Flutter package tests cover scoped locks, retries, concurrent release, platform behavior, and native loading.
The example tests cover marker export, acquisition failure, and disposal during acquisition.

## Remaining limits

- Physical Android and iOS tests must verify permissions and discovery between separate devices on the intended networks.
- Physical iOS tests require Apple's multicast entitlement and a matching signing profile.
- Android SDK 37 permission behavior requires a matching device and an application that targets SDK 37.
- Linux arm64, Windows arm64, and iOS x64 simulator targets lack build or runtime verification.
- The universal macOS build compiles x64 native code; CI executes only arm64.

Use `dart build cli` for a bundled AOT executable.
A direct `dart test --compiler exe` run on the current SDK did not supply a native asset map.
