# Native dependencies

The build hook downloads pinned source archives, verifies their SHA-256 hashes, and compiles them for the target.
Dart and Flutter bundle the result. No system-wide liblsl installation is required.
The first build needs a target C++17 compiler and HTTPS access to `codeload.github.com`.
Later builds reuse verified archives in the hook cache.

| Component | Version or source | License |
| --- | --- | --- |
| liblsl | [1.17.7](https://github.com/sccn/liblsl/tree/v1.17.7) | MIT |
| pugixml | [1.15](https://github.com/zeux/pugixml/tree/v1.15) | MIT |
| Boost headers and portable archives | The pinned liblsl archive | Boost Software License 1.0 |
| Standalone Asio | The pinned liblsl archive | Boost Software License 1.0 |
| Loguru | The pinned liblsl archive | Public domain, with a fallback permission grant |

The [lsl package license](../packages/lsl/LICENSE) contains these license texts.
Preserve the package license in application notices when you distribute the bundled native library.
Flutter's license collection can use this dependency-level `LICENSE` file.

The retained C headers and generated declarations use liblsl's MIT license.
The original liblsl notice remains in `packages/lsl/third_party/liblsl/LICENSE`.

See [CONTRIBUTING.md](../CONTRIBUTING.md#native-changes) before a native version change.

## Offline builds

Place these archives in a local directory:

- [liblsl-1.17.7.tar.gz](https://codeload.github.com/sccn/liblsl/tar.gz/refs/tags/v1.17.7)
- [pugixml-1.15.tar.gz](https://codeload.github.com/zeux/pugixml/tar.gz/refs/tags/v1.15)

Set this configuration in the consuming application's `pubspec.yaml`:

```yaml
hooks:
  user_defines:
    lsl:
      source_archives: /path/to/verified-archives/
```

The hook verifies the same hashes and fails if an archive is absent or corrupt.
It does not fetch replacement archives in offline mode.
The SDK, compiler, and Dart dependencies must also be available locally.
This option controls native source downloads; use the SDK's offline options for Pub dependencies.
