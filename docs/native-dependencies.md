# Native dependencies

The build hook downloads the following source archives and verifies their SHA-256 hashes.
It compiles the sources locally. The repository contains no native implementation or native binaries.

| Component | Version or source | License |
| --- | --- | --- |
| liblsl | [1.17.7](https://github.com/sccn/liblsl/tree/v1.17.7) | MIT |
| pugixml | [1.15](https://github.com/zeux/pugixml/tree/v1.15) | MIT |
| Boost headers and portable archives | The pinned liblsl archive | Boost Software License 1.0 |
| Standalone Asio | The pinned liblsl archive | Boost Software License 1.0 |
| Loguru | The pinned liblsl archive | Public domain, with a fallback permission grant |

The [lsl package license](../packages/lsl/LICENSE) contains these license texts.
It includes pugixml's 2006–2025 copyright notice from version 1.15.
Preserve the package license in application notices when you distribute the bundled native library.
Flutter's license collection can use this dependency-level `LICENSE` file.

The retained C headers and generated declarations use liblsl's MIT license.
The original liblsl notice remains in `packages/lsl/third_party/liblsl/LICENSE`.

When you change a native version, update the archive hash, compiler sources, headers, and generated bindings together.
Check the new archives for changes to their dependency licenses.
Run the native tests and all platform builds before you accept that change.
