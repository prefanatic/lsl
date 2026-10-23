# Lab Streaming Layer for Dart and Flutter

This workspace contains two MIT-licensed packages:

| Package | Purpose |
| --- | --- |
| [`lsl`](packages/lsl) | The LSL C API and Dart APIs for stream discovery, metadata, outlets, and inlets. |
| [`lsl_flutter`](packages/lsl_flutter) | A Flutter entry point that exports `lsl`. |

The repository remains private. Each package uses `publish_to: none`.

For local use, set path dependencies to these package directories.
For private Git use, add both packages and override the transitive `lsl` source:

```yaml
dependencies:
  lsl_flutter:
    git:
      url: git@github.com:prefanatic/lsl.git
      path: packages/lsl_flutter
dependency_overrides:
  lsl:
    git:
      url: git@github.com:prefanatic/lsl.git
      path: packages/lsl
```

Pure Dart applications can use the `lsl` Git dependency directly.
Replace these Git sources with hosted versions after publication.

## Native builds

The `lsl` build hook fetches liblsl 1.17.7 and pugixml 1.15.
It verifies each archive with a pinned SHA-256 hash before extraction.
`native_toolchain_c` selects the target compiler and builds a bundled code asset.
Dart and Flutter load the generated FFI bindings through that asset.
The repository contains no native binaries or vendored C++ implementation.
It retains the LSL C headers for binding generation and the required license notices.

Use Dart 3.13 or later and Flutter 3.47 or later.
The build needs a C++17 compiler for the target platform.
The first build needs HTTPS access to `codeload.github.com`.
Later builds reuse the verified archives in the hook cache.

| Target | Architectures | Required toolchain |
| --- | --- | --- |
| macOS | arm64, x64 | Xcode command line tools |
| Linux | arm64, x64 | GCC or Clang, C++ standard library, pthreads |
| Windows | arm64, x64 | Visual Studio with Desktop development with C++ |
| Android | arm, arm64, x64 | Android SDK and NDK |
| iOS | arm64 device; arm64 or x64 simulator | Xcode and the target SDK |

The hook rejects other targets. The web cannot use `dart:ffi` or the LSL socket protocol.
See [platform configuration](docs/platforms.md) for network permissions and device limits.
CI runs native tests and bundled CLI checks on Linux, macOS, and Windows.
It also builds the Flutter example for all five operating systems.
See [verification](docs/verification.md) for recorded results and unverified targets.

## Development

Run these commands from the repository root:

```sh
flutter pub get --enforce-lockfile
dart analyze --fatal-infos
dart format --output=none --set-exit-if-changed packages tool test
```

Run package tests from their package directories:

```sh
cd packages/lsl
dart test --coverage=coverage
```

```sh
cd packages/lsl_flutter
flutter test
```

```sh
cd packages/lsl_flutter/example
flutter test
flutter run -d macos
```

Regenerate the complete C API with `dart run packages/lsl/tool/ffigen.dart` from the repository root.
FFIgen requires libclang. The generator uses the pinned headers in `packages/lsl/third_party/liblsl`.
Keep those headers, the archive hashes, the source list, and the native version in agreement.
See [CONTRIBUTING.md](CONTRIBUTING.md) for coverage, API docs, and review checks.

## Offline builds

Place these exact archives in a local directory:

- `liblsl-1.17.7.tar.gz`
- `pugixml-1.15.tar.gz`

Set this hook configuration in the consuming application's `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    lsl:
      source_archives: /path/to/verified-archives/
```

The hook verifies the same hashes in offline mode.
It fails if an archive is absent or corrupt. It does not fetch a replacement in offline mode.
The compiler and Dart dependencies must also be available locally.
The source override controls native downloads. The SDK can still request Pub advisory data.
See [verification](docs/verification.md) for the offline runner limit observed on this SDK.

## Resource ownership

Destroy each owned `StreamInfo`, including resolver results and `Outlet.streamInfo` results.
Await `Inlet.destroy()` after use.
Cancel a sample subscription before use of synchronous inlet methods.
Native finalizers provide fallback cleanup. Explicit destruction gives predictable resource lifetime.

## Licenses

The Dart code uses the MIT license in [LICENSE](LICENSE).
The [lsl package license](packages/lsl/LICENSE) also contains the native dependency notices.
See [native dependencies](docs/native-dependencies.md) for their source versions and licenses.
