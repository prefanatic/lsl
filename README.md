# Lab Streaming Layer for Dart and Flutter

Discover LSL streams, send numeric samples and UTF-8 markers, and receive samples through worker isolates.
The packages also provide metadata, clock correction, and the complete LSL C API.

| Package | Use |
| --- | --- |
| [`lsl`](packages/lsl) | Dart API, FFI bindings, and the native build hook |
| [`lsl_flutter`](packages/lsl_flutter) | Flutter API and scoped Android multicast locks |

Use Dart 3.13 or later. Flutter applications need Flutter 3.47 or later.
The packages support Android, iOS, Linux, macOS, and Windows. Web is not supported.
See [platform setup](docs/platforms.md) for architectures, compilers, and network permissions.

## Add a dependency

The repository is public. The packages are not published on pub.dev.
Use a Git dependency or a path dependency for a local checkout.

For a Dart application:

```yaml
dependencies:
  lsl:
    git:
      url: https://github.com/prefanatic/lsl.git
      path: packages/lsl
```

For a Flutter application, override the transitive `lsl` dependency with the same Git source:

```yaml
dependencies:
  lsl_flutter:
    git:
      url: https://github.com/prefanatic/lsl.git
      path: packages/lsl_flutter
dependency_overrides:
  lsl:
    git:
      url: https://github.com/prefanatic/lsl.git
      path: packages/lsl
```

Pin both Git sources to the same commit with `ref` for a reproducible dependency.
See the [Dart guide](packages/lsl/README.md) for samples, discovery, and resource cleanup.
See the [Flutter guide](packages/lsl_flutter/README.md) for application setup and the example.

## Native builds

The Dart build hook fetches liblsl 1.17.7 and pugixml 1.15, verifies their SHA-256 hashes, and compiles them for the target.
Dart and Flutter bundle and load the native library automatically.
Install the target C++17 toolchain before the first build.
That build needs HTTPS access to `codeload.github.com`; later builds reuse verified source archives.
See [native dependencies](docs/native-dependencies.md) for offline builds and license notices.

## Contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) for tests, coverage, API documentation, and binding generation.
See [verification](docs/verification.md) for platform results and remaining limits.

The Dart code uses the [MIT license](LICENSE).
The [lsl package license](packages/lsl/LICENSE) includes the native dependency notices.
