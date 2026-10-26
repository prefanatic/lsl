## 0.1.0-dev.1

Initial development release.

- Build pinned liblsl 1.17.7 source through Dart hooks with verified archive hashes.
- Expose the complete LSL C API and Dart APIs for all native channel formats.
- Support discovery, channel labels and units, timestamps, numeric chunks, and clock correction.
- Validate sample dimensions and manage native resource ownership.
- Receive samples through cancellable worker isolates.
